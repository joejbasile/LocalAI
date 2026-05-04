import os
import requests
import time
import random
import logging
from flask import Flask, request, jsonify
from concurrent.futures import ThreadPoolExecutor, as_completed
from rake_nltk import Rake
from urllib.parse import urlparse
from collections import defaultdict
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sentence_transformers import CrossEncoder

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# ----------------------------
# CONFIG
# ----------------------------
SEARXNG_URL = os.getenv("SEARXNG_URL", "http://searxng:8080/search")
HERMES_URL = os.getenv("HERMES_URL", "http://hermes-gateway:8642/v1/chat/completions")
API_KEY = os.getenv("HERMES_API_KEY", "hermes_secret_123")
MODEL_NAME = os.getenv("MODEL_NAME")
RERANKER = CrossEncoder("BAAI/bge-reranker-base")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROMPT_PATH = os.path.join(BASE_DIR,"agent_prompt.md")

BASE_CATEGORIES = [
    ("journalists", "investigation report"),
    ("independent", "in-depth analysis"),
    ("news", "news article"),
    ("general", "")
]

EXPERIENCE_CATEGORIES = [
    ("youtube", "review tutorial"),
    ("reddit", "discussion opinion"),
    ("social", "twitter opinion")
]

TRUSTED_DOMAINS = {
    "reuters.com": 1.0,
    "apnews.com": 1.0,
    "bbc.com": 0.95,
    "nature.com": 1.0,
    "science.org": 1.0,
}

logging.info(f"Looking for prompt at: {PROMPT_PATH}")
try:
    with open(PROMPT_PATH, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
except FileNotFoundError:
    logging.error("agent_prompt.md not found")

# ----------------------------
# RERANKING
# ----------------------------
def rerank_results(query, results, top_k=8):
    if not results:
        return results
    pairs = [(query, r["content"]) for r in results]
    try:
        scores = RERANKER.predict(pairs)
    except Exception as e:
        logging.warning(f"Reranker failed: {e}")
        return results
    ranked = list(zip(results, scores))
    ranked.sort(key=lambda x: x[1], reverse=True)
    reranked = []
    for r, score in ranked[:top_k]:
        r["rerank_score"] = float(score)
        reranked.append(r)
    return reranked

# ----------------------------
# INTENT + ROUTING
# ----------------------------
def classify_intent(query: str) -> str:
    q = query.lower()

    if any(x in q for x in ["what is", "who is", "define"]):
        return "FACTUAL"

    if any(x in q for x in ["vs", "compare", "difference"]):
        return "COMPARISON"
    if any(x in q for x in ["how", "steps", "guide"]):
        return "INSTRUCTIONAL"
    if any(x in q for x in ["should", "worth", "best", "recommend"]):
        return "OPINION"

    return "FACTUAL"

def is_simple_query(query: str) -> bool:
    return len(query.split()) <= 6

# ----------------------------
# QUERY PROCESSING
# ----------------------------
def compress_search_query(text: str, max_words: int = 12) -> str:
    try:
        sentence = re.split(r'[.!?]', text)[0].strip().lower()
        prefixes = ["what is", "why is", "how to", "explain"]
        for p in prefixes:
            if sentence.startswith(p):
                sentence = sentence[len(p):].strip()
        r = Rake()
        r.extract_keywords_from_text(sentence)
        phrases = r.get_ranked_phrases()
        query = " ".join(phrases[:3]).strip()
        return " ".join(query.split()[:max_words]) or sentence

    except:
        return text

def safe_query(q: str, max_words: int = 14) -> str:
    return " ".join(q.split()[:max_words])

# ----------------------------
# SCORING
# ----------------------------
def get_domain_score(url: str) -> float:
    domain = urlparse(url).netloc.lower()
    for d, score in TRUSTED_DOMAINS.items():
        if d in domain:
            return score * 1.5
    return 0.6

# ----------------------------
# SEARCH
# ----------------------------
def search_category(query, category, modifier):
    time.sleep(random.uniform(0.3, 1.2))
    try:
        final_q = safe_query(f"{query} {modifier}")
        res = requests.get(
            SEARXNG_URL,
            params={"q": final_q, "format": "json"},
            timeout=10
        )
        return res.json().get("results", [])
    except:
        return []

# ----------------------------
# CLEAN RESULTS
# ----------------------------
def normalize_results(results):
    seen = set()
    domain_counts = defaultdict(int)
    cleaned = []
    results = sorted(results, key=lambda x: get_domain_score(x.get("url", "")), reverse=True)
    for r in results:
        url = r.get("url")
        content = (r.get("content") or "").strip()
        if not url or url in seen:
            continue
        if len(content) < 40:  # lowered threshold
            continue
        domain = urlparse(url).netloc.lower()
        if domain_counts[domain] >= 3:  # relaxed cap
            continue
        seen.add(url)
        domain_counts[domain] += 1

        cleaned.append({
            "url": url,
            "content": content[:1000],
            "score": get_domain_score(url)
        })
    return cleaned[:8]

# ----------------------------
# CLAIMS
# ----------------------------
def extract_claims(text):
    sentences = re.split(r'(?<=[.!?]) +', text)
    return [s.strip() for s in sentences if len(s.split()) > 5]

# ----------------------------
# CLUSTERING
# ----------------------------
def cluster_claims(results):
    texts, mapping = [], []

    for r in results:
        for c in extract_claims(r["content"]):
            texts.append(c)
            mapping.append((c, r["url"], r["score"]))

    if len(texts) < 2:
        return {}

    vec = TfidfVectorizer().fit_transform(texts)
    sim = cosine_similarity(vec)

    clusters = defaultdict(list)
    used = set()

    for i in range(len(texts)):
        if i in used:
            continue

        cluster = []
        for j in range(len(texts)):
            if sim[i][j] > 0.65:  # lowered threshold
                cluster.append(j)
                used.add(j)

        key = texts[i][:80].lower()

        for idx in cluster:
            c, url, score = mapping[idx]
            clusters[key].append({
                "claim": c,
                "source": url,
                "score": score
            })

    return clusters

# ----------------------------
# VERIFY
# ----------------------------
def verify_claims(clusters):
    verified = []

    for items in clusters.values():
        sources = list({i["source"] for i in items})
        score = sum(
            (0.4 * i["score"]) + (0.6 * i.get("rerank_score", 0))
            for i in items
        ) / len(items)

        if len(sources) >= 2 or score > 0.9:
            verified.append({
                "claim": items[0]["claim"],
                "sources": sources[:3]
            })

    return verified

# ----------------------------
# FALLBACK
# ----------------------------
def build_best_effort(results, query):
    top = sorted(results, key=lambda x: x["score"], reverse=True)[:5]

    text = f"{query}\n\n"
    for i, r in enumerate(top, 1):
        text += f"{i}. {r['content']}\nSource: {r['url']}\n\n"

    return text

# ----------------------------
# ROUTE
# ----------------------------
@app.route("/v1/chat/completions", methods=["POST"])
def chat():
    data = request.get_json(force=True) or {}
    messages = data.get("messages", [])

    if not messages:
        return jsonify({"error": "No messages"}), 400

    user_query = messages[-1]["content"]
    intent = classify_intent(user_query)

    # 🧠 ROUTING LOGIC
    if is_simple_query(user_query):
        search_q = user_query
    else:
        search_q = compress_search_query(user_query)

    # Boost definitions
    if intent == "FACTUAL":
        search_q += " definition overview"

    categories = BASE_CATEGORIES

    raw_results = []
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [
            executor.submit(search_category, search_q, c, m)
            for c, m in categories
        ]
        for f in as_completed(futures):
            raw_results.extend(f.result())

    results = normalize_results(raw_results)
    results = rerank_results(user_query, results)

    # 🚀 SIMPLE MODE (bypass clustering)
    if is_simple_query(user_query) and results:
        context = build_best_effort(results, user_query)
    else:
        clusters = cluster_claims(results)
        verified = verify_claims(clusters)

        if not verified:
            context = build_best_effort(results, user_query)
        else:
            context = f"QUERY: {user_query}\n\nVERIFIED CLAIMS:\n\n"
            for i, c in enumerate(verified, 1):
                context += f"{i}. {c['claim']}\n"
                for j, s in enumerate(c["sources"], 1):
                    context += f"   [{j}] {s}\n"
                context += "\n"

    # ----------------------------
    # LLM CALL
    # ----------------------------
    try:
        response = requests.post(
            HERMES_URL,
            headers={"Authorization": f"Bearer {API_KEY}"},
            json={
                "model": MODEL_NAME,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": context}
                ],
                "temperature": 0.2
            },
            timeout=120
        )

        answer = response.json()["choices"][0]["message"]["content"]

    except Exception as e:
        logging.error(e)
        answer = "Model failed."

    return jsonify({
        "choices": [{
            "message": {
                "content": answer
            }
        }]
    })

# ----------------------------
# HEALTH
# ----------------------------
@app.route("/health")
def health():
    return {"status": "ok"}

# ----------------------------
# MODELS
# ----------------------------
@app.route("/v1/models", methods=["GET"])
def get_models():
    return jsonify({
        "object": "list",
        "data": [
            {
                "id": "hermes-agent",
                "object": "model",
                "created": int(time.time()),
                "owned_by": "orchestrator"
            }
        ]
    })

# ----------------------------
# MAIN
# ----------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)