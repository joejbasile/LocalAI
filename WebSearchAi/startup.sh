#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "   Select Coding Model to Initialize"
echo "=========================================="
echo "1) Qwen2.5-Coder 7B Q5_K_M (8 GB VRAM)"
echo "2) Qwen2.5-Coder 14B Q5_K_M (16 GB VRAM)"
echo "3) Qwen3-Coder 30B-A3B UD-Q5_K_XL (MoE) (32 GB VRAM)"
echo "4) Qwythos-9B-v2 Q5_K_M (General / Web Agent) (12+ GB VRAM)"
echo "------------------------------------------"

printf "Enter choice as number [Default is 1] (1-3 are coding agents, 4 is a general purpose agent): "
read -r choice

case $choice in
  ""|1)
    MODEL_FILE="qwen2.5-coder-7b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen-coder-agent-7b"
    HF_REPO="Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
    HF_FILE_PATTERN="qwen2.5-coder-7b-instruct-q5_k_m.gguf"
    ;;
  2)
    MODEL_FILE="qwen2.5-coder-14b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen-coder-agent-14b"
    HF_REPO="Qwen/Qwen2.5-Coder-14B-Instruct-GGUF"
    HF_FILE_PATTERN="qwen2.5-coder-14b-instruct-q5_k_m*.gguf"
    ;;
  3)
    MODEL_FILE="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    OLLAMA_MODEL="qwen3-coder-agent-30b"
    HF_REPO="unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF"
    HF_FILE_PATTERN="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL*.gguf"
    ;;
  4)
    MODEL_FILE="Qwythos-9B-v2-Q5_K_M.gguf"
    OLLAMA_MODEL="qwythos-agent-9b"
    HF_REPO="empero-ai/Qwythos-9B-v2-GGUF"
    HF_FILE_PATTERN="*Q5_K_M*.gguf"
    ;;
  *)
    echo "Error: Invalid choice '$choice'. Exiting."
    exit 1
    ;;
esac

echo ""
echo "--> Stripping potential Windows line endings from scripts..."
if command -v sed >/dev/null 2>&1; then
    sed -i 's/\r$//' scripts/*.sh 2>/dev/null || true
fi

echo ""
echo "--> Selected GGUF: $MODEL_FILE"
echo "--> Ollama model: $OLLAMA_MODEL"
echo ""

# Export everything for Docker Compose to pick up
export MODEL_FILE
export OLLAMA_MODEL
export HF_REPO
export HF_FILE_PATTERN

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