#!/usr/bin/env bash
# ==============================================================================
# MonoCode Antigravity Auth Synchronizer
# Dynamically bridges OAuth credentials from Antigravity CLI to Antigravity ACP
# ==============================================================================

set -e

CLI_TOKEN="/home/coder/.gemini/antigravity-cli/antigravity-oauth-token"
ACP_DIR="/home/coder/.gemini/antigravity-acp"

if [ ! -f "$CLI_TOKEN" ]; then
    echo "[-] No Antigravity CLI token found at $CLI_TOKEN."
    echo "    Please run 'agy' or login first."
    exit 1
fi

mkdir -p "$ACP_DIR"

python3 - <<'EOF'
import json
import os
import re
import sys
import zipfile

cli_token_path = "/home/coder/.gemini/antigravity-cli/antigravity-oauth-token"
acp_dir = "/home/coder/.gemini/antigravity-acp"
acp_token_path = os.path.join(acp_dir, "acp_token.json")
settings_path = os.path.join(acp_dir, "settings.json")
par_path = "/home/coder/.local/share/agy-acp/agy_acp_server.par"

try:
    with open(cli_token_path, "r", encoding="utf-8") as f:
        d = json.load(f)

    token_info = d.get("token", {})
    if not token_info:
        print("[-] Error: No token object found in cli token file.", file=sys.stderr)
        sys.exit(1)

    # Extract OAuth client credentials dynamically from the ACP binary
    client_id = None
    client_secret = None
    if os.path.exists(par_path):
        try:
            with zipfile.ZipFile(par_path) as z:
                for name in z.namelist():
                    if "oauth_manager.py" in name:
                        code = z.read(name).decode("utf-8", errors="ignore")
                        cid_m = re.search(r'_DEFAULT_CLIENT_ID\s*=\s*\(?\s*[\'"]([^\'"]+)[\'"]', code)
                        sec_m = re.search(r'_DEFAULT_CLIENT_SECRET\s*=\s*[\'"]([^\'"]+)[\'"]', code)
                        if cid_m:
                            client_id = cid_m.group(1)
                        if sec_m:
                            client_secret = sec_m.group(1)
                        break
        except Exception as ze:
            print(f"[-] Warning: Failed to inspect PAR file for client config: {ze}", file=sys.stderr)

    if not client_id or not client_secret:
        print("[-] Error: Could not dynamically resolve ACP OAuth client credentials from binary.", file=sys.stderr)
        sys.exit(1)

    acp_token = {
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": token_info.get("refresh_token"),
        "token": token_info.get("access_token"),
        "type": "authorized_user"
    }

    with open(acp_token_path, "w", encoding="utf-8") as f:
        json.dump(acp_token, f, indent=2)
    os.chmod(acp_token_path, 0o600)

    settings = {"auth": {"type": "oauth-personal"}}
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as sf:
                settings = json.load(sf)
        except Exception:
            pass
    settings.setdefault("auth", {})["type"] = "oauth-personal"
    with open(settings_path, "w", encoding="utf-8") as sf:
        json.dump(settings, sf, indent=2)
    os.chmod(settings_path, 0o600)

    print("[+] Successfully synced Antigravity CLI token to ACP server.")
except Exception as e:
    print(f"[-] Error syncing Antigravity token: {e}", file=sys.stderr)
    sys.exit(1)
EOF

chown -R coder:coder "$ACP_DIR" 2>/dev/null || true
