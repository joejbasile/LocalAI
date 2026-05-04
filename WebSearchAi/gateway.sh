#!/bin/sh
set -e
echo "Starting Hermes setup..."
HERMES_DIR="/root/.hermes"
CONFIG_FILE="$HERMES_DIR/config.yaml"
MODEL_NAME=${MODEL=${MODEL_NAME}}
mkdir -p "$HERMES_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Generating lean config.yaml..."
    cat > "$CONFIG_FILE" <<EOF
model:
  provider: "custom"
  base_url: "http://ollama:11434/v1"
  model: "$MODEL_NAME"
agent:
  enabled: false # Disabled because Orchestrator handles the logic
  max_steps: 1
EOF
    echo "Config generated successfully."
fi
echo "Using model: $MODEL_NAME"
echo "Launching Hermes Gateway..."
exec hermes gateway run