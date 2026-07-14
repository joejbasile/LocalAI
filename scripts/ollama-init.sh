#!/usr/bin/env bash
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

# Reset target file cleanly
rm -f "$DYNAMIC_MODELFILE"

# Inject the base GGUF layer pointer at the top
echo "FROM /models/${MODEL_FILE}" > "$DYNAMIC_MODELFILE"

# Determine which profile to append based on the model name choice substring matching
if [[ "${OLLAMA_MODEL}" == *"general"* ]]; then
    SYSTEM_PROMPT_FILE="/scripts/system_prompt_general.txt"
else
    SYSTEM_PROMPT_FILE="/scripts/system_prompt_coding.txt"
fi

# 2. Append the prompt file content directly without modification
if [ -f "$SYSTEM_PROMPT_FILE" ]; then
    echo "--> Appending runtime configurations from $SYSTEM_PROMPT_FILE..."
    cat "$SYSTEM_PROMPT_FILE" >> "$DYNAMIC_MODELFILE"
else
    echo "Error: Configuration file '$SYSTEM_PROMPT_FILE' not found."
    exit 1
fi

# 3. Append options from the base Modelfile if present, avoiding duplicate FROM commands
if [ -f "$MODELFILE_PATH" ] && [ -s "$MODELFILE_PATH" ]; then
    echo "--> Merging base configurations from ${MODELFILE_PATH}..."
    # The '|| true' prevents set -e from killing the script if grep finds 0 matching lines
    grep -v '^FROM ' "$MODELFILE_PATH" >> "$DYNAMIC_MODELFILE" || true
fi

echo "--> Compiling '${OLLAMA_MODEL}' inside Ollama..."
ollama create "${OLLAMA_MODEL}" -f "$DYNAMIC_MODELFILE"

echo "--> Compilation successful! Active models:"
ollama list