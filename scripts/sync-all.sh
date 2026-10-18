#!/usr/bin/env bash
set -e

echo "=== Synchronizing MonoCode Remote Environment ==="

if [ -x "/usr/local/bin/sync-skills" ]; then
    echo "-> Synchronizing Skills..."
    /usr/local/bin/sync-skills
fi

if [ -x "/usr/local/bin/sync-mcp" ]; then
    echo "-> Synchronizing MCP Servers..."
    /usr/local/bin/sync-mcp
fi

if [ -x "/usr/local/bin/sync-antigravity-auth" ]; then
    echo "-> Synchronizing Antigravity Auth..."
    /usr/local/bin/sync-antigravity-auth
fi

echo "=== All synchronizations complete ==="
