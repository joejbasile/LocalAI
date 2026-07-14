FROM ollama/ollama:latest

# 1. Install Python, pip, build tools, and dos2unix for line-ending sanitization
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       python3-pip \
       curl \
       git \
       build-essential \
       cmake \
       dos2unix \
    && pip3 install --break-system-packages huggingface_hub \
    # 2. Clone llama.cpp and compile ONLY the llama-gguf-split utility statically
    && git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
    && cmake -B /tmp/llama.cpp/build -S /tmp/llama.cpp \
       -DGGML_CUDA=OFF \
       -DGGML_NATIVE=OFF \
       -DBUILD_SHARED_LIBS=OFF \
    && cmake --build /tmp/llama.cpp/build --target llama-gguf-split -j$(nproc) \
    # 3. Move the compiled binary AND any fallback shared libraries to system paths
    && cp /tmp/llama.cpp/build/bin/llama-gguf-split /usr/local/bin/ \
    && (find /tmp/llama.cpp/build -name "*.so*" -exec cp {} /usr/local/lib/ \; || true) \
    && ldconfig \
    # 4. Clean up build artifacts
    && rm -rf /tmp/llama.cpp /var/lib/apt/lists/*

# Ensure binaries and libraries are accessible in the environment
ENV PATH="/root/.local/bin:/usr/local/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"

# 5. Copy scripts and automatically convert line endings from Windows CRLF to Linux LF
COPY scripts /scripts
RUN dos2unix /scripts/*.sh 2>/dev/null || true \
    && chmod +x /scripts/*.sh