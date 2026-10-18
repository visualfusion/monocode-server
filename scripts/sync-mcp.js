#!/usr/bin/env node
/**
 * Synchronize MCP servers from central configuration (/home/coder/.mcp/mcp-servers.json)
 * to Claude Code, OpenAI Codex, and Antigravity.
 */

const fs = require('fs');
const path = require('path');

const CODER_HOME = process.env.CODER_HOME || '/home/coder';
const CENTRAL_DIR = path.join(CODER_HOME, '.mcp');
const CENTRAL_CONFIG = path.join(CENTRAL_DIR, 'mcp-servers.json');

if (!fs.existsSync(CENTRAL_DIR)) {
  fs.mkdirSync(CENTRAL_DIR, { recursive: true });
}

if (!fs.existsSync(CENTRAL_CONFIG)) {
  const initial = {
    mcpServers: {}
  };
  fs.writeFileSync(CENTRAL_CONFIG, JSON.stringify(initial, null, 2), 'utf8');
  console.log(`[sync-mcp] Created template central MCP config at ${CENTRAL_CONFIG}`);
}

let centralData = { mcpServers: {} };
try {
  centralData = JSON.parse(fs.readFileSync(CENTRAL_CONFIG, 'utf8'));
} catch (err) {
  console.error(`[sync-mcp] Error reading ${CENTRAL_CONFIG}:`, err.message);
  process.exit(1);
}

const servers = centralData.mcpServers || {};

// 1. Sync to Claude Code (~/.claude/.claude.json)
const claudeConfigFile = path.join(CODER_HOME, '.claude', '.claude.json');
try {
  let claudeJson = {};
  if (fs.existsSync(claudeConfigFile)) {
    try {
      claudeJson = JSON.parse(fs.readFileSync(claudeConfigFile, 'utf8'));
    } catch (_) {}
  }
  claudeJson.mcpServers = claudeJson.mcpServers || {};

  // Merge central servers into Claude config
  for (const [name, cfg] of Object.entries(servers)) {
    claudeJson.mcpServers[name] = { ...cfg };
  }

  const claudeDir = path.dirname(claudeConfigFile);
  if (!fs.existsSync(claudeDir)) fs.mkdirSync(claudeDir, { recursive: true });
  fs.writeFileSync(claudeConfigFile, JSON.stringify(claudeJson, null, 2), 'utf8');
  console.log(`[sync-mcp] Updated Claude Code MCP servers in ${claudeConfigFile}`);
} catch (err) {
  console.error('[sync-mcp] Error updating Claude MCP config:', err.message);
}

// 2. Sync to OpenAI Codex (~/.codex/config.toml)
const codexConfigFile = path.join(CODER_HOME, '.codex', 'config.toml');
try {
  const codexDir = path.dirname(codexConfigFile);
  if (!fs.existsSync(codexDir)) fs.mkdirSync(codexDir, { recursive: true });

  let existingToml = '';
  if (fs.existsSync(codexConfigFile)) {
    existingToml = fs.readFileSync(codexConfigFile, 'utf8');
  }

  // Strip previously synced [mcp_servers.*] blocks
  const tomlLines = existingToml.split('\n');
  const filteredLines = [];
  let inMcpBlock = false;

  for (const line of tomlLines) {
    if (/^\s*\[mcp_servers\..*\]/.test(line)) {
      inMcpBlock = true;
      continue;
    }
    if (inMcpBlock && /^\s*\[/.test(line) && !/^\s*\[mcp_servers\..*\]/.test(line)) {
      inMcpBlock = false;
    }
    if (!inMcpBlock) {
      filteredLines.push(line);
    }
  }

  let cleanToml = filteredLines.join('\n').trim();

  // Append central MCP servers
  const mcpTomlBlocks = [];
  for (const [name, cfg] of Object.entries(servers)) {
    if (cfg.disabled) continue;

    mcpTomlBlocks.push(`\n[mcp_servers.${name}]`);
    if (cfg.url) {
      mcpTomlBlocks.push(`url = ${JSON.stringify(cfg.url)}`);
      if (cfg.headers || cfg.http_headers) {
        mcpTomlBlocks.push(`\n[mcp_servers.${name}.http_headers]`);
        const headers = cfg.headers || cfg.http_headers;
        for (const [k, v] of Object.entries(headers)) {
          mcpTomlBlocks.push(`${k} = ${JSON.stringify(v)}`);
        }
      }
    } else if (cfg.command) {
      mcpTomlBlocks.push(`command = ${JSON.stringify(cfg.command)}`);
      mcpTomlBlocks.push(`args = ${JSON.stringify(cfg.args || [])}`);
      mcpTomlBlocks.push(`startup_timeout_sec = ${cfg.startup_timeout_sec || 60}`);
      if (cfg.env && Object.keys(cfg.env).length > 0) {
        mcpTomlBlocks.push(`\n[mcp_servers.${name}.env]`);
        for (const [k, v] of Object.entries(cfg.env)) {
          mcpTomlBlocks.push(`${k} = ${JSON.stringify(v)}`);
        }
      }
    }
  }

  const finalToml = cleanToml + (mcpTomlBlocks.length > 0 ? '\n' + mcpTomlBlocks.join('\n') + '\n' : '\n');
  fs.writeFileSync(codexConfigFile, finalToml, 'utf8');
  console.log(`[sync-mcp] Updated OpenAI Codex MCP servers in ${codexConfigFile}`);
} catch (err) {
  console.error('[sync-mcp] Error updating Codex MCP config:', err.message);
}

// 3. Sync to Antigravity (~/.gemini/config/mcp_config.json & symlinks)
try {
  const geminiConfigDir = path.join(CODER_HOME, '.gemini', 'config');
  const geminiCliDir = path.join(CODER_HOME, '.gemini', 'antigravity-cli');
  const geminiAcpDir = path.join(CODER_HOME, '.gemini', 'antigravity-acp');

  for (const dir of [geminiConfigDir, geminiCliDir, geminiAcpDir]) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const targetFile = path.join(dir, 'mcp_config.json');
    fs.writeFileSync(targetFile, JSON.stringify(centralData, null, 2), 'utf8');
  }

  console.log(`[sync-mcp] Updated Antigravity MCP configs in ~/.gemini/`);
} catch (err) {
  console.error('[sync-mcp] Error updating Antigravity MCP config:', err.message);
}

console.log('[sync-mcp] All MCP servers synchronized successfully.');
