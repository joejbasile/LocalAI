#!/bin/sh

cd "$(dirname "$0")" || exit 1

echo "Cleaning model files..."

MODELS_DIR="./models"

# Remove downloaded GGUF files but preserve Modelfile
rm -f \
  "$MODELS_DIR/qwen2.5-coder-14b-instruct-q5_k_m-00001-of-00002.gguf" \
  "$MODELS_DIR/qwen2.5-coder-14b-instruct-q5_k_m-00002-of-00002.gguf" \
  "$MODELS_DIR/qwen2.5-coder-14b-instruct-q5_k_m.gguf"

# Remove Hugging Face cache
rm -rf "$MODELS_DIR/.cache"

echo "Model cleanup complete."
echo "Preserved: $MODELS_DIR/Modelfile"


echo ""
echo "Running Docker cleanup..."

docker compose down -v

docker system prune -f -a --volumes


# Run Windows-only compaction if PowerShell exists
if command -v powershell.exe >/dev/null 2>&1; then
  echo "Running Windows disk compaction..."

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -W)"

  powershell.exe \
    -ExecutionPolicy Bypass \
    -File "$SCRIPT_DIR/compact-docker.ps1"

else
  echo "PowerShell not found. Skipping disk compaction."
fi

echo ""
echo "Cleanup complete."