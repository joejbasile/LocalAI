#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo "   Select Model to Initialize"
echo "=========================================="
echo "1) Qwen2.5-Coder 7B Q5_K_M (8+ GB VRAM)"
echo "2) Qwen2.5-Coder 14B Q5_K_M (16+ GB VRAM)"
echo "3) Qwen3-Coder 30B-A3B UD-Q5_K_XL (MoE) (32+ GB VRAM)"
echo "4) Qwythos-9B-v2 Q5_K_M (General / Web Agent) (10+ GB VRAM)"
echo "5) Qwen3.6 35B-A3B UD-Q5_K_XL (General / Web Agent) (32+ GB VRAM)"
echo "------------------------------------------"

printf "Enter choice as number [Default is 1] (1-3 are coding agents, 4-5 are general purpose web search agents): "
read -r choice

case $choice in
  ""|1)
    MODEL_FILE="qwen2.5-coder-7b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen2-5-coder-agent-7b"
    HF_REPO="Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
    HF_FILE_PATTERN="qwen2.5-coder-7b-instruct-q5_k_m.gguf"
    ;;
  2)
    MODEL_FILE="qwen2.5-coder-14b-instruct-q5_k_m.gguf"
    OLLAMA_MODEL="qwen2-5-coder-agent-14b"
    HF_REPO="Qwen/Qwen2.5-Coder-14B-Instruct-GGUF"
    HF_FILE_PATTERN="qwen2.5-coder-14b-instruct-q5_k_m-0000*-of-*.gguf"
    ;;
  3)
    MODEL_FILE="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    OLLAMA_MODEL="qwen3-coder-agent-30b"
    HF_REPO="unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF"
    # Exact match: Unsloth provides this as a single file, not split chunks
    HF_FILE_PATTERN="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    ;;
  4)
    MODEL_FILE="Qwythos-9B-v2-Q5_K_M.gguf"
    OLLAMA_MODEL="qwythos-general-agent-9b"
    HF_REPO="empero-ai/Qwythos-9B-v2-GGUF"
    HF_FILE_PATTERN="Qwythos-9B-v2-Q5_K_M.gguf"
    ;;
  5)
    MODEL_FILE="Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf"
    OLLAMA_MODEL="qwen3.6-general-agent-35b"
    HF_REPO="unsloth/Qwen3.6-35B-A3B-GGUF"
    # Exact match: Unsloth provides this as a single file, not split chunks
    HF_FILE_PATTERN="Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf"
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

# Export variables for Docker Compose
export MODEL_FILE
export OLLAMA_MODEL
export HF_REPO
export HF_FILE_PATTERN

echo "--> Launching cluster (Orchestrating model build dynamically)..."
docker compose up -d

echo ""
echo "=========================================="
echo " Stack Initialization Initiated"
echo "=========================================="
echo " Monitor build status with: docker logs -f ollama-builder"
echo " Open WebUI will be ready at: http://localhost:3000"
echo ""
