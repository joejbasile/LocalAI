import os
import requests
import time
import random
from flask import Flask, request, jsonify
from concurrent.futures import ThreadPoolExecutor, as_completed
from rake_nltk import Rake
from urllib.parse import urlparse
from collections import defaultdict
import re

app = Flask(__name__)

# --- CONFIG ---
SEARXNG_URL = "http://searxng:8080/search"
HERMES_URL = "http://hermes-gateway:8642/v1/chat/completions"
API_KEY = "hermes_secret_123"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROMPT_PATH = os.path.join(BASE_DIR, "/hermes-data/agent_prompt.md")

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

CATEGORY_WEIGHT = {
    "journalists": 1.0,
    "independent": 0.9,
    "news": 0.8,
    "general": 0.7,
    "youtube": 0.85,
    "reddit": 0.8,
    "social": 0.7,
}

TRUSTED_DOMAINS = {
    "reuters.com": 1.0,
    "apnews.com": 1.0,
    "bbc.com": 0.95,
    "nature.com": 1.0,
    "science.org": 1.0,
}

# --- PROMPT ---
SYSTEM_PROMPT = """
You are an evidence-based assistant.

Follow the provided context strictly.

Modes:
- FACTUAL: Use verified claims with citations.
- SENTIMENT: Summarize user opinions and experiences.

Rules:
- Do not hallucinate.
- Use only provided context.
- In sentiment mode, say "Users report..." instead of stating facts.
- Always respond in English.
"""

# --- INTENT CLASSIFIER ---

def classify_intent(query):
    q = query.lower()

    if any(x in q for x in ["how", "steps", "guide"]):
        return "INSTRUCTIONAL"
    if any(x in q for x in ["vs", "compare", "better"]):
        return "COMPARISON"
    if len(q.split()) < 6:
        return "VAGUE"
    return "FACTUAL"

# --- HELPERS ---

def extract_search_keywords(text):
    if len(text.split()) < 30:
        return text
    r = Rake()
    r.extract_keywords_from_text(text[:800])
    return " ".join(r.get_ranked_phrases()[:6])


def get_domain_score(url):
    domain = urlparse(url).netloc.lower()
    for d, score in TRUSTED_DOMAINS.items():
        if d in domain:
            return score
    return 0.6


def normalize_results(results, category):
    cleaned = []
    for r in results or []:
        url = r.get("url")
        content = (r.get("content") or "").strip()
        if not url or len(content) < 50:
            continue

        cleaned.append({
            "title": r.get("title", ""),
            "url": url,
            "content": content[:1200],
            "category": category
        })
    return cleaned


def search_category(query, category, modifier):
    time.sleep(random.uniform(0.3, 1.0))
    try:
        res = requests.get(
            SEARXNG_URL,
            params={"q": f"{query} {modifier}", "format": "json"},
            timeout=10
        )
        return normalize_results(res.json().get("results"), category)
    except:
        return []

# --- CLAIM PIPELINE (FACTUAL MODE) ---

def extract_claims(text):
    sentences = re.split(r'(?<=[.!?]) +', text)
    return [s for s in sentences if len(s.split()) > 8]


def normalize_claim(c):
    return re.sub(r'[^a-z0-9 ]', '', c.lower())[:240]


def cluster_claims(results):
    clusters = defaultdict(list)

    for r in results:
        for c in extract_claims(r["content"]):
            key = normalize_claim(c)
            clusters[key].append({
                "claim": c,
                "source": r["url"]
            })

    return clusters


def verify_claims(clusters, min_sources=2):
    verified = []

    for items in clusters.values():
        sources = list({i["source"] for i in items})

        if len(sources) >= min_sources:
            verified.append({
                "claim": items[0]["claim"],
                "sources": sources[:3]
            })

    return verified

# --- CONTEXT BUILDERS ---

def build_factual_context(query, claims):
    context = f"QUERY: {query}\n\nVERIFIED CLAIMS:\n\n"

    for i, c in enumerate(claims, 1):
        context += f"{i}. {c['claim']}\n"
        for j, s in enumerate(c["sources"], 1):
            context += f"   [{j}] {s}\n"
        context += "\n"

    return context


def build_sentiment_context(query, results):
    context = f"QUERY: {query}\n\nUSER SENTIMENT & EXPERIENCES:\n\n"
    MAX_RESULTS = 5
    for i, r in enumerate(results[:MAX_RESULTS], 1):
        context += f"{i}. {r['content']}\nSource: {r['url']}\n\n"

    return context

# --- ROUTE ---

@app.route("/v1/chat/completions", methods=["POST"])
def chat():
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])

    if not messages:
        return jsonify({"error": "No messages"}), 400

    user_query = messages[-1]["content"]
    intent = classify_intent(user_query)
    if intent == "VAGUE":
        search_q = user_query  # 🔥 no keyword extraction
    else:
        search_q = extract_search_keywords(user_query)

    # --- SELECT MODE ---
    if intent == "VAGUE":
        mode = "SENTIMENT"
        categories = BASE_CATEGORIES + EXPERIENCE_CATEGORIES
    else:
        mode = "FACTUAL"
        categories = BASE_CATEGORIES

    # --- SEARCH ---
    results = []
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = [
            executor.submit(search_category, search_q, cat, mod)
            for cat, mod in categories
        ]
        for f in as_completed(futures):
            results.extend(f.result())

    # --- MODE EXECUTION ---

    if mode == "SENTIMENT":
        context = build_sentiment_context(user_query, results)

    else:
        clusters = cluster_claims(results)
        verified_claims = verify_claims(clusters)

        if not verified_claims:
            return jsonify({
                "choices": [{
                    "message": {
                        "content": "I could not find reliable confirmation."
                    }
                }]
            })

        context = build_factual_context(user_query, verified_claims)

    # --- GENERATE ---
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

    answer = response.json()["choices"][0]["message"]["content"]

    return jsonify({
        "choices": [{
            "message": {
                "content": answer
            }
        }]
    })


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)