#!/bin/sh

cd "$(dirname "$0")" || exit 1

echo "Cleaning model files..."
MODELS_DIR="./models"

# Purge any downloaded variants safely
rm -f "$MODELS_DIR"/*.gguf
rm -rf "$MODELS_DIR"/.cache

echo "Model cleanup complete."
echo "Preserved: $MODELS_DIR/Modelfile"

echo ""
echo "Running Docker cleanup..."
docker compose down -v
docker system prune -f -a --volumes

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