#!/bin/sh
set -e

MODEL_NAME="qwen-coder-agent"

echo "Waiting for Ollama..."

until ollama list >/dev/null 2>&1
do
    sleep 5
done

echo "Ollama ready."


if ollama list | grep -q "${MODEL_NAME}"; then
    echo "${MODEL_NAME} already exists."
    exit 0
fi


echo "Creating ${MODEL_NAME}..."

ollama create \
    "${MODEL_NAME}" \
    -f /models/Modelfile


echo "Model created."

ollama list