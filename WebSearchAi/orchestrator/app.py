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

app = Flask(__name__)

# ----------------------------
# LOGGING
# ----------------------------
logging.basicConfig(level=logging.INFO)

# ----------------------------
# CONFIG
# ----------------------------
SEARXNG_URL = os.getenv("SEARXNG_URL", "http://searxng:8080/search")
HERMES_URL = os.getenv("HERMES_URL", "http://hermes-gateway:8642/v1/chat/completions")
API_KEY = os.getenv("HERMES_API_KEY", "hermes_secret_123")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROMPT_PATH = os.path.join(BASE_DIR, "hermes-data/agent_prompt.md")

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

CULTURAL_CATEGORIES = [
    ("social", "knowyourmeme archive"),
    ("general", "substack analysis"),
    ("discussions", "forum community") # Many SearXNG instances have a 'discussions' category
]

TRUSTED_DOMAINS = {
    "reuters.com": 1.0,
    "apnews.com": 1.0,
    "bbc.com": 0.95,
    "nature.com": 1.0,
    "science.org": 1.0,
}

# ----------------------------
# SYSTEM PROMPT
# ----------------------------
try:
    with open(PROMPT_PATH, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
except FileNotFoundError:
    logging.warning("agent_prompt.md not found, falling back to default.")

# ----------------------------
# INTENT CLASSIFIER
# ----------------------------
def classify_intent(query: str) -> str:
    q = query.lower()

    comparison = ["vs", "versus", "compare", "difference"]
    instruction = ["how", "steps", "guide", "tutorial"]
    opinion = ["should", "worth", "good", "bad", "best", "better", "think", "recommend"]

    if any(x in q for x in comparison):
        return "COMPARISON"
    if any(x in q for x in instruction):
        return "INSTRUCTIONAL"
    if any(x in q for x in opinion):
        return "OPINION"
    if len(q.split()) < 4 and "?" not in q:
        return "VAGUE"

    return "FACTUAL"

# ----------------------------
# QUERY COMPRESSION (FIXED CORE)
# ----------------------------
def compress_search_query(text: str, max_words: int = 12) -> str:
    try:
        # take first sentence only
        sentence = re.split(r'[.!?]', text)[0].strip().lower()
        # remove common prefixes
        prefixes = [
            "what is", "why is", "how to", "how do i",
            "can you", "please", "explain", "tell me"
        ]
        for p in prefixes:
            if sentence.startswith(p):
                sentence = sentence[len(p):].strip()
        # extract keywords
        r = Rake()
        r.extract_keywords_from_text(sentence)
        phrases = r.get_ranked_phrases()
        query = " ".join(phrases[:3]).strip()
        if not query:
            query = sentence
        # enforce strict length limit
        return " ".join(query.split()[:max_words])
    except Exception:
        return " ".join(text.split()[:max_words])

# ----------------------------
# SAFETY LIMIT FOR SEARCH STRING
# ----------------------------
def safe_query(q: str, max_words: int = 14) -> str:
    return " ".join(q.split()[:max_words])

# ----------------------------
# DOMAIN SCORING
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
    time.sleep(random.uniform(0.4, 2.0))
    try:
        final_q = safe_query(f"{query} {modifier}")
        res = requests.get(
            SEARXNG_URL,
            params={"q": final_q, "format": "json"},
            timeout=10
        )
        return res.json().get("results", [])
    except Exception as e:
        logging.warning(f"Search error: {e}")
        return []

# ----------------------------
# CLEAN RESULTS
# ----------------------------
def normalize_results(results):
    seen_urls = set()
    domain_counts = defaultdict(int)  # Track how many results per site
    cleaned = []
    # Sort by score first so if we have to cap a domain, we keep their best results
    sorted_results = sorted(results, key=lambda x: get_domain_score(x.get("url", "")), reverse=True)
    for r in sorted_results:
        url = r.get("url")
        content = (r.get("content") or "").strip()
        if not url:
            continue 
        domain = urlparse(url).netloc.lower()
        # --- LOGIC GATES ---
        # 1. Skip duplicates
        if url in seen_urls:
            continue
        # 2. Skip thin content (protects against scraper/spam sites)
        if len(content) < 60:
            continue
        # 3. DOMAIN DIVERSITY CAP:
        # Limit any single domain to 2 results. This forces the orchestrator 
        # to look at independent blogs once the "Big Guys" have had their say.
        if domain_counts[domain] >= 2:
            continue
        # --- SCORE & COMMIT ---
        seen_urls.add(url)
        domain_counts[domain] += 1
        cleaned.append({
            "url": url,
            "content": content[:1200],  # Keep context chunks manageable
            "score": get_domain_score(url)
        })
    # Final sort to ensure the most "trusted" or high-score items are at the top
    # but the list is now guaranteed to be diverse.
    return cleaned[:15] # Return top 15 diverse results

# ----------------------------
# CLAIM EXTRACTION
# ----------------------------
def extract_claims(text):
    sentences = re.split(r'(?<=[.!?]) +', text)
    return [s.strip() for s in sentences if len(s.split()) > 8]

# ----------------------------
# CLUSTERING
# ----------------------------
def cluster_claims(results):
    texts = []
    mapping = []

    for r in results:
        for c in extract_claims(r["content"]):
            texts.append(c)
            mapping.append((c, r["url"], r["score"]))

    if len(texts) < 2:
        return {}

    vectorizer = TfidfVectorizer().fit_transform(texts)
    sim_matrix = cosine_similarity(vectorizer)

    clusters = defaultdict(list)
    used = set()

    for i in range(len(texts)):
        if i in used:
            continue

        cluster = []
        for j in range(len(texts)):
            if sim_matrix[i][j] > 0.75:
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
# VERIFICATION
# ----------------------------
def verify_claims(clusters):
    verified = []

    for items in clusters.values():
        sources = list({i["source"] for i in items})
        score = sum(i["score"] for i in items) / max(len(items), 1)

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

    text = f"Best available information for: {query}\n\n"
    for i, r in enumerate(top, 1):
        text += f"{i}. {r['content']}\nSource: {r['url']}\n\n"

    return text

# ----------------------------
# CONTEXT BUILDERS
# ----------------------------
def build_factual_context(query, claims):
    context = f"QUERY: {query}\n\nVERIFIED CLAIMS:\n\n"

    for i, c in enumerate(claims, 1):
        context += f"{i}. {c['claim']}\n"
        for j, s in enumerate(c["sources"], 1):
            context += f"   [{j}] {s}\n"
        context += "\n"

    return context

def build_sentiment_context(query, results):
    results = sorted(results, key=lambda x: x["score"], reverse=True)

    context = f"QUERY: {query}\n\nUSER EXPERIENCES:\n\n"

    for i, r in enumerate(results[:5], 1):
        context += f"{i}. {r['content']}\nSource: {r['url']}\n\n"

    return context

# ----------------------------
# ROUTE
# ----------------------------
@app.route("/v1/chat/completions", methods=["POST"])
def chat():
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])

    if not messages:
        return jsonify({"error": "No messages"}), 400

    user_query = messages[-1]["content"]
    intent = classify_intent(user_query)

    search_q = compress_search_query(user_query)

    mode = "SENTIMENT" if intent in ["VAGUE", "OPINION"] else "FACTUAL"

    categories = BASE_CATEGORIES + EXPERIENCE_CATEGORIES if mode == "SENTIMENT" else BASE_CATEGORIES

    # ----------------------------
    # SEARCH
    # ----------------------------
    raw_results = []

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [
            executor.submit(search_category, search_q, c, m)
            for c, m in categories
        ]
        for f in as_completed(futures):
            raw_results.extend(f.result())

    results = normalize_results(raw_results)

    if not results:
        return jsonify({
            "choices": [{
                "message": {
                    "content": "Please add more details to the prompt."
                }
            }]
    #     })

    # ----------------------------
    # MODE HANDLING
    # ----------------------------
    if mode == "SENTIMENT":
        context = build_sentiment_context(user_query, results)

    else:
        clusters = cluster_claims(results)
        verified = verify_claims(clusters)

        if not verified:
            context = build_best_effort(results, user_query)
        else:
            context = build_factual_context(user_query, verified)

    # ----------------------------
    # LLM CALL
    # ----------------------------
    try:
        response = requests.post(
            HERMES_URL,
            headers={"Authorization": f"Bearer {API_KEY}"},
            json={
                "model": "qwen3.5:9b",
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": context}
                ],
                "temperature": 0.2
            },
            timeout=120
        )

        response.raise_for_status()
        answer = response.json()["choices"][0]["message"]["content"]

    except Exception as e:
        logging.error(f"LLM error: {e}")
        return jsonify({
            "choices": [{
                "message": {
                    "content": "Model generation failed."
                }
            }]
        })

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