#!/usr/bin/env bash
set -e

# Ensure permissions on home directory and ssh
if [ -d "/home/coder" ]; then
    mkdir -p /home/coder/.ssh /home/coder/.local/bin /home/coder/.local/share /home/coder/workspace /home/coder/.skills /home/coder/.monocode-host
    
    if [ -f "/home/coder/.ssh/authorized_keys" ]; then
        chmod 600 /home/coder/.ssh/authorized_keys
    fi
    chmod 700 /home/coder/.ssh

    # Ensure ownership belongs to coder
    chown -R coder:coder /home/coder
fi

# Ensure host keys are persistent across rebuilds
HOST_KEYS_DIR="/etc/ssh/host_keys"
if [ -d "$HOST_KEYS_DIR" ]; then
    # If host keys exist in persistent volume, restore them
    if [ -f "$HOST_KEYS_DIR/ssh_host_ed25519_key" ]; then
        cp -a "$HOST_KEYS_DIR"/ssh_host_* /etc/ssh/ 2>/dev/null || true
    fi
fi

if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -A
    # Save newly generated keys to persistent volume if mounted
    if [ -d "$HOST_KEYS_DIR" ]; then
        cp -a /etc/ssh/ssh_host_* "$HOST_KEYS_DIR"/ 2>/dev/null || true
    fi
fi

chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true

# Export container environment variables to /etc/environment and coder shell profiles
# so SSH login sessions automatically inherit all Coolify env variables
export -p | grep -E 'ANTHROPIC_|OPENAI_|GITHUB_|CODEX_|CLAUDE_|PUID|PGID|TZ' > /etc/environment || true
if [ -f "/home/coder/.bashrc" ]; then
    # Prevent duplicate sourcing
    if ! grep -q "/etc/environment" /home/coder/.bashrc; then
        echo '[ -f /etc/environment ] && set -a && . /etc/environment && set +a' >> /home/coder/.bashrc
    fi
    # Ensure custom prompt with monocode hostname
    if ! grep -q "coder@monocode" /home/coder/.bashrc; then
        echo 'export PS1="\[\033[01;32m\]\u@monocode\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/coder/.bashrc
    fi
fi

# Ensure Linux group 'nobody' exists (required by Google agy_acp_server.par)
groupadd -g 65534 nobody 2>/dev/null || groupadd nobody 2>/dev/null || true

# Symlink localharness if present for Antigravity ACP integration
if [ -f "/home/coder/.local/share/antigravity-acp/localharness_external" ]; then
    ln -sf /home/coder/.local/share/antigravity-acp/localharness_external /usr/local/bin/localharness
    ln -sf /home/coder/.local/share/antigravity-acp/localharness_external /usr/local/bin/localharness_external
fi

# Ensure MonoCode host allows all detected providers (like antigravity) when supportedProviders is omitted
if [ -f "/opt/monocode/build/host/monocode-host.mjs" ]; then
    sed -i 's/: provider === "codex" || provider === "claude"/: true/g' /opt/monocode/build/host/monocode-host.mjs 2>/dev/null || true
fi

# Auto-sync Antigravity CLI OAuth credentials to Antigravity ACP if available
if [ -x "/usr/local/bin/sync-antigravity-auth" ] && [ -f "/home/coder/.gemini/antigravity-cli/antigravity-oauth-token" ]; then
    /usr/local/bin/sync-antigravity-auth 2>/dev/null || true
fi

echo "=== MonoCode Remote Dev Box ready ==="
echo "SSH daemon listening on port 22 (forwarded to host port)"
echo "MonoCode Host binding to 127.0.0.1:3774"

exec "$@"
