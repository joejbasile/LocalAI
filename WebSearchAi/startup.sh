#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "   Select Coding Model to Initialize"
echo "=========================================="
echo "1) Qwen2.5-Coder 14B Q5_K_M"
echo "2) Qwen2.5-Coder 7B Q5_K_M"
echo "------------------------------------------"

printf "Enter choice as number [Default is 1]: "
read -r choice

case $choice in
  ""|1)
    MODEL_FILE="qwen2.5-coder-14b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen-coder-agent"
    ;;
  2)
    MODEL_FILE="qwen2.5-coder-7b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen-coder-agent-7b"
    ;;
  *)
    echo "Error: Invalid choice '$choice'. Exiting."
    exit 1
    ;;
esac


echo ""
echo "--> Selected GGUF: $MODEL_FILE"
echo "--> Ollama model: $OLLAMA_MODEL"
echo ""


export MODEL_FILE
export OLLAMA_MODEL


echo "--> Starting Ollama..."
docker compose up -d ollama


echo "--> Waiting for Ollama health..."
until docker exec ollama ollama list >/dev/null 2>&1
do
    sleep 5
done


echo "--> Building model..."
docker compose --profile builder run --rm ollama-builder


echo "--> Starting UI services..."
docker compose up -d searxng open-webui


echo ""
echo "=========================================="
echo " Stack Ready"
echo "=========================================="
echo " Open WebUI:"
echo " http://localhost:3000"
echo ""
echo " Model:"
echo " $OLLAMA_MODEL"