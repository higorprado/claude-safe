FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    nodejs \
    vim \
    gosu \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp -L /root/.local/bin/claude /usr/local/bin/claude

RUN userdel -r ubuntu || true

RUN useradd -m -s /bin/bash -u 1000 claude

# Create directory and symlink expected by Claude Code native install
RUN mkdir -p /home/claude/.local/bin && \
    ln -s /usr/local/bin/claude /home/claude/.local/bin/claude && \
    chown -R claude:claude /home/claude/.local

WORKDIR /workspace
RUN chown claude:claude /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]