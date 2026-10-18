#!/usr/bin/env bash
# Helper script to inject your local SSH public key into the remote container volume.
# Usage: ./scripts/setup-keys.sh [path-to-public-key] [server-ssh-alias]

PUB_KEY_PATH="${1:-$HOME/.ssh/id_ed25519.pub}"
SERVER_HOST="${2:-your-remote-server}"

if [ ! -f "$PUB_KEY_PATH" ]; then
    echo "Error: Public key file not found at: $PUB_KEY_PATH"
    echo "Usage: ./scripts/setup-keys.sh ~/.ssh/id_ed25519.pub your-server"
    exit 1
fi

echo "Injecting public key: $PUB_KEY_PATH into container on $SERVER_HOST..."

ssh "$SERVER_HOST" "CONTAINER_ID=\$(docker ps -q --filter name=monocode-dev-box | head -n 1) && [ -n \"\$CONTAINER_ID\" ] && docker exec -i \"\$CONTAINER_ID\" sh -c 'mkdir -p /home/coder/.ssh && cat >> /home/coder/.ssh/authorized_keys && sort -u /home/coder/.ssh/authorized_keys -o /home/coder/.ssh/authorized_keys && chmod 600 /home/coder/.ssh/authorized_keys && chown -R coder:coder /home/coder/.ssh'" < "$PUB_KEY_PATH"

echo "SSH key successfully installed!"
echo "You can now connect via: ssh -p 2222 coder@<your-server-ip>"
