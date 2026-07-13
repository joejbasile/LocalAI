#!/bin/sh
set -e

MODEL_DIR="/models"

echo "Checking GGUF files..."

if ls ${MODEL_DIR}/qwen2.5-coder-14b-instruct-q5_k_m.gguf >/dev/null 2>&1; then
    echo "Merged GGUF already exists."
    exit 0
fi


echo "Downloading Qwen split GGUF files..."

hf download \
  Qwen/Qwen2.5-Coder-14B-Instruct-GGUF \
  --include "qwen2.5-coder-14b-instruct-q5_k_m*.gguf" \
  --local-dir /models


echo "Checking split files..."

ls -lh ${MODEL_DIR}


if ls ${MODEL_DIR}/*00001-of-00002.gguf >/dev/null 2>&1; then

    FIRST_FILE=$(ls ${MODEL_DIR}/*00001-of-00002.gguf)

    echo "Merging split GGUF..."

    llama-gguf-split \
      --merge \
      "${FIRST_FILE}" \
      "${MODEL_DIR}/qwen2.5-coder-14b-instruct-q5_k_m.gguf"

fi


echo "Download and merge complete."

ls -lh ${MODEL_DIR}