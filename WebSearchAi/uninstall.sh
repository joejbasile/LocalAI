#!/bin/sh
cd "$(dirname "$0")"
docker compose -f docker-compose.yaml down -v
docker system prune -f -a --volumes
rm -rf hermes-data/*
rm -rf orchestrator/agent_prompt.md
cp agent_prompt.md orchestrator/