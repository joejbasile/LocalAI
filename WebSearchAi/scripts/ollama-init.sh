#!/bin/sh
set -e

MODELFILE_PATH="/models/Modelfile"
DYNAMIC_MODELFILE="/tmp/Modelfile.dynamic"

echo "=========================================="
echo " Ollama Model Compiler"
echo "=========================================="
echo "Target Ollama Name: ${OLLAMA_MODEL}"
echo "Source GGUF:        /models/${MODEL_FILE}"
echo "------------------------------------------"

echo "--> Waiting for Ollama engine at ${OLLAMA_HOST}..."
until ollama list >/dev/null 2>&1; do
  sleep 2
done
echo "--> Ollama engine is online."

# 1. Check if the model is already compiled in Ollama
if ollama list | grep -q "${OLLAMA_MODEL}"; then
  echo "--> Model '${OLLAMA_MODEL}' is already registered in Ollama. Skipping build."
  exit 0
fi

echo "--> Generating dynamic runtime Modelfile..."

# 2. Inject our dynamic FROM line at the very top
echo "FROM /models/${MODEL_FILE}" > "$DYNAMIC_MODELFILE"

# 3. Append the rest of your Modelfile, but STRIP OUT any existing FROM lines to prevent collisions
if [ -f "$MODELFILE_PATH" ]; then
    grep -v '^FROM ' "$MODELFILE_PATH" >> "$DYNAMIC_MODELFILE"
else
    echo "Error: Base Modelfile not found at ${MODELFILE_PATH}"
    exit 1
fi

echo "--> Compiling '${OLLAMA_MODEL}' inside Ollama..."
ollama create "${OLLAMA_MODEL}" -f "$DYNAMIC_MODELFILE"

echo "--> Compilation successful! Active models:"
ollama list