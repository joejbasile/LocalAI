#!/usr/bin/sh
set -e

MODEL_DIR="/models"

echo "=========================================="
echo " Model Downloader & Merger"
echo "=========================================="
echo "Target Repo:    ${HF_REPO}"
echo "Target Pattern: ${HF_FILE_PATTERN}"
echo "Final GGUF:     ${MODEL_FILE}"
echo "------------------------------------------"

# 1. Skip download if the final GGUF file already exists
if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    echo "--> Target GGUF '${MODEL_FILE}' already exists on disk. Skipping download."
    exit 0
fi

echo "--> Downloading GGUF files from Hugging Face..."
# Fallback to huggingface-cli if 'hf' alias is missing
DOWNLOAD_CMD=$(command -v hf || command -v huggingface-cli)
if [ -z "$DOWNLOAD_CMD" ]; then
    echo "Error: Neither 'hf' nor 'huggingface-cli' is installed in this container."
    exit 1
fi

$DOWNLOAD_CMD download \
  "${HF_REPO}" \
  --include "${HF_FILE_PATTERN}" \
  --local-dir "${MODEL_DIR}"

echo "--> Inspecting downloaded files in ${MODEL_DIR}:"
ls -lh "${MODEL_DIR}"

# 2. Check for split files
PREFIX="${MODEL_FILE%.gguf}"

if ls "${MODEL_DIR}"/${PREFIX}*00001-of-*.gguf >/dev/null 2>&1; then
    FIRST_FILE=$(ls "${MODEL_DIR}"/${PREFIX}*00001-of-*.gguf | head -n 1)
    
    echo "--> Detected split GGUF chunks for ${PREFIX}."
    echo "--> Merging chunks using primary file: ${FIRST_FILE}..."
    
    if command -v llama-gguf-split >/dev/null 2>&1; then
        llama-gguf-split --merge "${FIRST_FILE}" "${MODEL_DIR}/${MODEL_FILE}"
        echo "--> Merge complete! Removing leftover split chunks..."
        rm -f "${MODEL_DIR}"/${PREFIX}*-of-*.gguf
    else
        echo "Error: llama-gguf-split binary not found in container path. Cannot merge."
        exit 1
    fi
else
    echo "--> Model downloaded as a single GGUF file. No merge required."
fi

echo "--> Final model verification:"
ls -lh "${MODEL_DIR}/${MODEL_FILE}"