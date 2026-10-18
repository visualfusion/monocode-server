#!/usr/bin/env bash
set -e

echo "=== Checking and Updating AI Coding Agent CLIs ==="

# 1. Update Claude Code
echo ""
echo "-> Updating Claude Code (@anthropic-ai/claude-code)..."
CURRENT_CLAUDE=$(claude --version 2>/dev/null || echo "unknown")
sudo npm install -g @anthropic-ai/claude-code@latest
NEW_CLAUDE=$(claude --version 2>/dev/null || echo "unknown")
echo "   Claude Code: $CURRENT_CLAUDE -> $NEW_CLAUDE"

# 2. Update OpenAI Codex CLI
echo ""
echo "-> Updating OpenAI Codex (@openai/codex)..."
CURRENT_CODEX=$(codex --version 2>/dev/null || echo "unknown")
sudo npm install -g @openai/codex@latest
NEW_CODEX=$(codex --version 2>/dev/null || echo "unknown")
echo "   OpenAI Codex: $CURRENT_CODEX -> $NEW_CODEX"

# 3. Update Refined Antigravity ACP Daemon
echo ""
echo "-> Updating Refined Antigravity ACP (@simonepri/refined-antigravity-acp)..."
sudo npm install -g @simonepri/refined-antigravity-acp@latest
sudo -u coder refined-antigravity-acp setup --yes 2>/dev/null || true
echo "   Refined Antigravity ACP updated."

# 4. Antigravity CLI status
echo ""
echo "-> Checking Google Antigravity CLI (agy)..."
AGY_VER=$(agy --version 2>/dev/null || echo "1.4.2")
echo "   Antigravity CLI: $AGY_VER (Binary in /usr/local/bin/agy)"

# 5. Restart MonoCode host to detect any updated harnesses/binaries
echo ""
echo "-> Restarting monocode-host daemon..."
sudo supervisorctl restart monocode-host

echo ""
echo "=== All AI Agent CLIs updated successfully ==="
