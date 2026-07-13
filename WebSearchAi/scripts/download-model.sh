#!/bin/sh
set -e

MODEL_DIR="/models"

echo "=========================================="
echo " Model Downloader & Merger"
echo "=========================================="
echo "Target Repo:    ${HF_REPO}"
echo "Target Pattern: ${HF_FILE_PATTERN}"
echo "Final GGUF:     ${MODEL_FILE}"
echo "------------------------------------------"

# 1. If the fully merged or single GGUF is already present, skip everything
if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    echo "--> Target GGUF '${MODEL_FILE}' already exists on disk. Skipping download."
    exit 0
fi

echo "--> Downloading GGUF files from Hugging Face..."
hf download \
  "${HF_REPO}" \
  --include "${HF_FILE_PATTERN}" \
  --local-dir "${MODEL_DIR}"

echo "--> Inspecting downloaded files in ${MODEL_DIR}:"
ls -lh "${MODEL_DIR}"

# 2. Check specifically if THIS model downloaded as split files (*00001-of-*.gguf)
# We strip the '.gguf' extension from MODEL_FILE to use as a search prefix
PREFIX="${MODEL_FILE%.gguf}"

if ls "${MODEL_DIR}"/${PREFIX}*00001-of-*.gguf >/dev/null 2>&1; then
    FIRST_FILE=$(ls "${MODEL_DIR}"/${PREFIX}*00001-of-*.gguf | head -n 1)
    
    echo "--> Detected split GGUF chunks for ${PREFIX}."
    echo "--> Merging chunks using primary file: ${FIRST_FILE}..."
    
    llama-gguf-split \
      --merge \
      "${FIRST_FILE}" \
      "${MODEL_DIR}/${MODEL_FILE}"
      
    echo "--> Merge complete! Removing leftover split chunks to save space..."
    rm -f "${MODEL_DIR}"/${PREFIX}*-of-*.gguf
else
    echo "--> Model downloaded as a single GGUF file. No merge required."
fi

echo "--> Final model verification:"
ls -lh "${MODEL_DIR}/${MODEL_FILE}"