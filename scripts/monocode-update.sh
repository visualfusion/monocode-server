#!/usr/bin/env bash
set -e

# Ensure running with sudo if not root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

echo "=== Updating MonoCode Host Daemon ==="

cd /opt/monocode

echo "-> Fetching latest updates from upstream (hardbeat920/monocode)..."
git config --global --add safe.directory /opt/monocode 2>/dev/null || true
git fetch origin main

CURRENT_HASH=$(git rev-parse --short HEAD)
LATEST_HASH=$(git rev-parse --short origin/main)

echo "   Current version:  $CURRENT_HASH"
echo "   Upstream version: $LATEST_HASH"

if [ "$CURRENT_HASH" = "$LATEST_HASH" ] && [ "$1" != "--force" ]; then
    echo "MonoCode Host is already up to date ($CURRENT_HASH)."
    echo "Tip: Run 'monocode-update --force' or 'mc-selfupdate --force' to re-fetch and rebuild anyway."
    exit 0
fi

echo "-> Pulling upstream changes..."
git reset --hard origin/main

echo "-> Applying Antigravity ACP compatibility patch..."
sed -i 's/: provider === "codex" || provider === "claude"/: true/' /opt/monocode/host/server.ts

echo "-> Installing dependencies..."
npm install

echo "-> Building monocode-host..."
npm run host:build
chmod +x /opt/monocode/build/host/monocode-host.mjs

echo "-> Restarting monocode-host service..."
supervisorctl restart monocode-host

echo ""
echo "=== MonoCode Host updated successfully ($CURRENT_HASH -> $LATEST_HASH) ==="
