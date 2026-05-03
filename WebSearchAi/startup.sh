#!/bin/sh
cd "$(dirname "$0")"

echo "Select model:"
echo "1) qwen3.6:35b for 32 GB VRAM"
echo "2) qwen3.6:27b for 24 GB VRAM"
echo "3) qwen3.5:9b for 16 GB VRAM"
echo "4) qwen3.5:4b for 8 GB VRAM"
read -p "Enter choice as number [1-4]: " choice

case $choice in
  1)
    MODEL_NAME="qwen3.6:35b"
    ;;
  2)
    MODEL_NAME="qwen3.6:27b"
    ;;
  3)
    MODEL_NAME="qwen3.5:9b"
    ;;
  4)
    MODEL_NAME="qwen3.5:4b"
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo "Using model: $MODEL_NAME"

MODEL_NAME=$MODEL_NAME docker compose -f docker-compose.yaml up -d --build