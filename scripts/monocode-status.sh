#!/usr/bin/env bash
echo "=== MonoCode Service Status ==="
sudo supervisorctl status

echo ""
echo "=== Network & Ports ==="
python3 -c "import socket
s = socket.socket()
print('  MonoCode Host (Port 3774):', 'Listening' if s.connect_ex(('127.0.0.1', 3774)) == 0 else 'Down')
s.close()
s2 = socket.socket()
print('  SSH Daemon    (Port 22):  ', 'Listening' if s2.connect_ex(('127.0.0.1', 22)) == 0 else 'Down')
s2.close()" 2>/dev/null || echo "  Port check unavailable"

echo ""
echo "=== Agents & Capabilities ==="
command -v codex >/dev/null && echo "  Codex:       $(codex --version 2>/dev/null || echo 'installed')" || echo "  Codex:       not found"
command -v claude >/dev/null && echo "  Claude Code: $(claude --version 2>/dev/null || echo 'installed')" || echo "  Claude Code: not found"
command -v agy >/dev/null && echo "  Antigravity: $(agy --version 2>/dev/null || echo 'installed')" || echo "  Antigravity: not found"

SKILLS_COUNT=$(find /home/coder/.skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo 0)
echo "  Skills:      $SKILLS_COUNT installed in ~/.skills"

if [ -f "/home/coder/.mcp/mcp-servers.json" ]; then
    MCP_COUNT=$(node -e "try { const d = JSON.parse(require('fs').readFileSync('/home/coder/.mcp/mcp-servers.json', 'utf8')); console.log(Object.keys(d.mcpServers || {}).length); } catch { console.log(0); }")
    echo "  MCP Servers: $MCP_COUNT configured in ~/.mcp/mcp-servers.json"
fi
