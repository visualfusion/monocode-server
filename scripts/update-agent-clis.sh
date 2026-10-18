#!/usr/bin/env bash
# Update AI Agent CLIs inside the container
set -e

echo "Updating Anthropic Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "Updating OpenAI Codex CLI..."
npm install -g @openai/codex

echo "Updating Refined Antigravity ACP..."
npm install -g @simonepri/refined-antigravity-acp
refined-antigravity-acp setup --yes || true
mkdir -p /home/coder/.local/share/agy-acp
ln -sf /home/coder/.local/share/antigravity-acp/agy_acp_server.par /home/coder/.local/share/agy-acp/agy_acp_server.par

echo "All Agent CLIs successfully updated!"
