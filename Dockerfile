FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 20 LTS and essential dev tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    build-essential \
    python3 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /workspace

# Install Claude Code globally
# WORKDIR /tmp prevents the installer from scanning the entire filesystem
WORKDIR /tmp
RUN npm install -g @anthropic-ai/claude-code

USER dev
WORKDIR /workspace

ENTRYPOINT ["claude"]
