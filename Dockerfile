# Multi-stage Dockerfile for MonoCode Remote Box
# Base: Ubuntu 24.04 LTS (x86_64)

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 1. Install base utilities and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    zsh \
    openssh-server \
    supervisor \
    sudo \
    curl \
    wget \
    git \
    git-lfs \
    gh \
    ripgrep \
    fd-find \
    fzf \
    tree \
    sqlite3 \
    poppler-utils \
    jq \
    tmux \
    htop \
    ca-certificates \
    build-essential \
    pkg-config \
    libssl-dev \
    unzip \
    tar \
    gzip \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Fix fd binary naming, install lazygit and starship prompt
RUN ln -sf $(which fdfind) /usr/local/bin/fd \
    && LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -o '"tag_name": "v[^"]*"' | head -n 1 | cut -d '"' -f 4 | sed 's/^v//') \
    && curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit \
    && install /tmp/lazygit /usr/local/bin \
    && rm -f /tmp/lazygit* \
    && curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir /usr/local/bin

# 2. Install Node.js 22 LTS, npm, pnpm & Bun
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pnpm bun \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Python uv (fast package and MCP runner)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# 4. Create or configure non-privileged user 'coder' (UID 1000)
# Ubuntu 24.04 base image comes with a default 'ubuntu' user at UID/GID 1000.
RUN if id "ubuntu" >/dev/null 2>&1; then \
        userdel -r ubuntu 2>/dev/null || true; \
    fi \
    && groupadd -g 1000 coder \
    && useradd -u 1000 -g coder -m -s /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder

# 5. Configure SSH Server
RUN mkdir -p /var/run/sshd /home/coder/.ssh \
    && chmod 700 /home/coder/.ssh \
    && chown -R coder:coder /home/coder/.ssh

COPY config/sshd_config /etc/ssh/sshd_config.d/monocode.conf

# 6. Install KI Coding Agent CLIs
# - Claude Code
RUN npm install -g @anthropic-ai/claude-code

# - OpenAI Codex CLI
RUN npm install -g @openai/codex

# - Antigravity CLI (agy)
RUN curl -fsSL "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.4.2-4835981233356800/linux-x64/cli_linux_x64.tar.gz" -o /tmp/agy.tar.gz \
    && tar -xzf /tmp/agy.tar.gz -C /tmp \
    && mv /tmp/antigravity /usr/local/bin/agy \
    && chmod +x /usr/local/bin/agy \
    && rm -f /tmp/agy.tar.gz

# - Refined Antigravity ACP & agy_acp_server.par for MonoCode integration
RUN groupadd -g 65534 nobody 2>/dev/null || groupadd nobody 2>/dev/null || true \
    && npm install -g @simonepri/refined-antigravity-acp \
    && su - coder -c "refined-antigravity-acp setup --yes" || true \
    && mkdir -p /home/coder/.local/share/agy-acp \
    && ln -sf /home/coder/.local/share/antigravity-acp/agy_acp_server.par /home/coder/.local/share/agy-acp/agy_acp_server.par \
    && ln -sf /home/coder/.local/share/antigravity-acp/localharness_external /usr/local/bin/localharness \
    && ln -sf /home/coder/.local/share/antigravity-acp/localharness_external /usr/local/bin/localharness_external \
    && chown -R coder:coder /home/coder/.local

# 7. Setup MonoCode Host Daemon
WORKDIR /opt/monocode
RUN git clone --depth 1 https://github.com/hardbeat920/monocode.git /opt/monocode \
    && sed -i 's/: provider === "codex" || provider === "claude"/: true/' /opt/monocode/host/server.ts \
    && npm install \
    && npm run host:build \
    && ln -s /opt/monocode/build/host/monocode-host.mjs /usr/local/bin/monocode-host \
    && chmod +x /opt/monocode/build/host/monocode-host.mjs || true

# 8. Setup Application & Supervisor Structure
WORKDIR /home/coder/workspace
RUN mkdir -p /var/log/supervisor /home/coder/.skills /home/coder/.config /home/coder/.monocode-host /opt/monocode/config /etc/skel/.config \
    && chown -R coder:coder /home/coder

COPY config/starship.toml /opt/monocode/config/starship.toml
COPY config/starship.toml /etc/skel/.config/starship.toml

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/sync-antigravity-auth.sh /usr/local/bin/sync-antigravity-auth
COPY scripts/sync-skills.sh /usr/local/bin/sync-skills
COPY scripts/sync-mcp.js /usr/local/bin/sync-mcp
COPY scripts/sync-all.sh /usr/local/bin/sync-all
COPY scripts/update-agents.sh /usr/local/bin/update-agents
COPY scripts/monocode-update.sh /usr/local/bin/monocode-update
COPY scripts/monocode-status.sh /usr/local/bin/monocode-status
COPY scripts/monocode-restart.sh /usr/local/bin/monocode-restart
COPY scripts/monocode-logs.sh /usr/local/bin/monocode-logs
COPY config/01-custom-header /etc/update-motd.d/01-custom-header
RUN chmod +x /usr/local/bin/entrypoint.sh \
             /usr/local/bin/sync-antigravity-auth \
             /usr/local/bin/sync-skills \
             /usr/local/bin/sync-mcp \
             /usr/local/bin/sync-all \
             /usr/local/bin/update-agents \
             /usr/local/bin/monocode-update \
             /usr/local/bin/monocode-status \
             /usr/local/bin/monocode-restart \
             /usr/local/bin/monocode-logs \
             /etc/update-motd.d/01-custom-header \
    && ln -sf /usr/local/bin/monocode-status /usr/local/bin/mc-status \
    && ln -sf /usr/local/bin/monocode-restart /usr/local/bin/mc-restart \
    && ln -sf /usr/local/bin/monocode-logs /usr/local/bin/mc-logs \
    && ln -sf /usr/local/bin/update-agents /usr/local/bin/mc-update \
    && ln -sf /usr/local/bin/monocode-update /usr/local/bin/mc-selfupdate \
    && chmod -x /etc/update-motd.d/00-header /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news /etc/update-motd.d/60-unminimize 2>/dev/null || true \
    && echo "alias mc-status='monocode-status'" >> /etc/bash.bashrc \
    && echo "alias mc-restart='monocode-restart'" >> /etc/bash.bashrc \
    && echo "alias mc-logs='monocode-logs'" >> /etc/bash.bashrc \
    && echo "alias mc-update='update-agents'" >> /etc/bash.bashrc \
    && echo "alias mc-selfupdate='monocode-update'" >> /etc/bash.bashrc \
    && echo "alias sync-auth='sync-antigravity-auth'" >> /etc/bash.bashrc

# Environment variables for user coder
ENV PATH="/home/coder/.local/bin:/home/coder/.local/share/agy-acp:/usr/local/bin:$PATH"
ENV ANTIGRAVITY_HARNESS_PATH="/usr/local/bin/localharness"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
