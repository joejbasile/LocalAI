#!/bin/sh
set -e
echo "Starting Hermes setup..."
PROMPT_FILE="/root/.hermes/agent_prompt.md"
CONFIG_FILE="/root/.hermes/config.yaml"
MODEL_NAME=${MODEL_NAME}
if [ ! -f "$PROMPT_FILE" ]; then
    echo "ERROR: agent_prompt.md not found in /root/.hermes/"
    exit 1
fi
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Generating initial config.yaml..."
    # Indent the prompt content by 2 spaces for YAML compatibility
    PROMPT_CONTENT=$(sed 's/^/  /' "$PROMPT_FILE")
    cat > "$CONFIG_FILE" <<EOF
model:
  provider: "custom"
  base_url: "http://ollama:11434/v1"
  model: "$MODEL_NAME"
agent:
  enabled: true
  max_steps: 12
system_prompt: |
$PROMPT_CONTENT
EOF
fi
echo "Using model: $MODEL_NAME"
echo "Launching Hermes Gateway..."
exec hermes gateway run