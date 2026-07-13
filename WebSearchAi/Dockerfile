FROM ollama/ollama:latest

RUN apt-get update \
    && apt-get install -y python3 python3-pip curl \
    && pip3 install --break-system-packages huggingface_hub \
    && rm -rf /var/lib/apt/lists/*

COPY scripts /scripts

RUN chmod +x /scripts/*.sh