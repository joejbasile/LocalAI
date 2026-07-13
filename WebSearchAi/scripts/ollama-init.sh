#!/bin/sh
set -e

MODEL_NAME="qwen-coder-agent"
# Look directly inside the mounted models folder
MODELFILE_PATH="/models/Modelfile"

echo "Waiting for Ollama to respond at ${OLLAMA_HOST}..."
until ollama list >/dev/null 2>&1; do
  sleep 2
done

echo "Ollama ready."

if ollama list | grep -q "${MODEL_NAME}"; then
  echo "Model '${MODEL_NAME}' already exists. Skipping build step."
  exit 0
fi

echo "Compiling ${MODEL_NAME} from ${MODELFILE_PATH}..."
ollama create "${MODEL_NAME}" -f "$MODELFILE_PATH"

echo "Model compiled successfully!"

# List the models to verify it's active
ollama list