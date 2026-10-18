#!/usr/bin/env bash
# Synchronize skills from the central /home/coder/.skills directory to all agents:
# - Claude Code: ~/.claude/skills/
# - OpenAI Codex: ~/.codex/skills/
# - Antigravity: ~/.gemini/skills, ~/.gemini/config/skills, ~/.gemini/antigravity-cli/skills

set -e

CODER_HOME="/home/coder"
CENTRAL_SKILLS="$CODER_HOME/.skills"

mkdir -p "$CENTRAL_SKILLS"

# 1. Antigravity: Symlink full skills directories directly
mkdir -p "$CODER_HOME/.gemini/config" "$CODER_HOME/.gemini/antigravity-cli"
rm -rf "$CODER_HOME/.gemini/skills" "$CODER_HOME/.gemini/config/skills" "$CODER_HOME/.gemini/antigravity-cli/skills"
ln -s "$CENTRAL_SKILLS" "$CODER_HOME/.gemini/skills"
ln -s "$CENTRAL_SKILLS" "$CODER_HOME/.gemini/config/skills"
ln -s "$CENTRAL_SKILLS" "$CODER_HOME/.gemini/antigravity-cli/skills"

# 2. Claude Code: Ensure ~/.claude/skills has symlinks for all skills in ~/.skills
mkdir -p "$CODER_HOME/.claude/skills"
# Remove dead symlinks in ~/.claude/skills
find "$CODER_HOME/.claude/skills" -maxdepth 1 -xtype l -delete 2>/dev/null || true
for skill_dir in "$CENTRAL_SKILLS"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    ln -sfn "$skill_dir" "$CODER_HOME/.claude/skills/$skill_name"
done

# 3. OpenAI Codex: Ensure ~/.codex/skills has symlinks for all skills in ~/.skills
mkdir -p "$CODER_HOME/.codex/skills"
# Remove dead symlinks in ~/.codex/skills
find "$CODER_HOME/.codex/skills" -maxdepth 1 -xtype l -delete 2>/dev/null || true
for skill_dir in "$CENTRAL_SKILLS"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    ln -sfn "$skill_dir" "$CODER_HOME/.codex/skills/$skill_name"
done

# Ensure correct permissions
chown -hR coder:coder "$CENTRAL_SKILLS" "$CODER_HOME/.gemini" "$CODER_HOME/.claude" "$CODER_HOME/.codex" 2>/dev/null || true

echo "[sync-skills] All skills synchronized from $CENTRAL_SKILLS"
