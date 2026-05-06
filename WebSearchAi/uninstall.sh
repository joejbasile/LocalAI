#!/bin/sh
cd "$(dirname "$0")"
echo "Running Docker cleanup..."
docker compose down -v
docker system prune -f -a --volumes
rm -f orchestrator/agent_prompt.md
cp agent_prompt.md orchestrator/
# Run Windows-only compaction if PowerShell exists
if command -v powershell.exe >/dev/null 2>&1; then
  echo "Running Windows disk compaction..."
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -W)"
  powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/compact-docker.ps1"
else
  echo "PowerShell not found. Skipping disk compaction."
fi