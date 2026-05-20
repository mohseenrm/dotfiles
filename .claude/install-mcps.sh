#!/usr/bin/env bash
# Install personal Claude Code MCP servers (user scope).
# Idempotent: safe to re-run. Skips servers that are already configured.
#
# Usage:
#   bash ~/.claude/install-mcps.sh
#
# For work MCPs, see install-mcps.work.sh (gitignored).

set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH. Install Claude Code first." >&2
  exit 1
fi

# Helper: add an MCP server only if not already present at user scope.
add_user_mcp() {
  local name="$1"
  shift
  if claude mcp list 2>/dev/null | grep -qE "^${name}[[:space:]]"; then
    echo "✓ MCP '${name}' already configured, skipping"
    return 0
  fi
  echo "→ Adding MCP '${name}'..."
  claude mcp add --scope user "$name" "$@"
}

add_user_mcp_http() {
  local name="$1"
  local url="$2"
  shift 2
  if claude mcp list 2>/dev/null | grep -qE "^${name}[[:space:]]"; then
    echo "✓ MCP '${name}' already configured, skipping"
    return 0
  fi
  echo "→ Adding MCP '${name}'..."
  claude mcp add --transport http --scope user "$@" "$name" "$url"
}

# ─── Personal MCPs (mirrors opencode.jsonc) ──────────────────────────────────

# Excalidraw (remote HTTP)
add_user_mcp_http excalidraw https://mcp.excalidraw.com

# GitHub (remote HTTP, requires GITHUB_MCP_KEY env var)
if [[ -n "${GITHUB_MCP_KEY:-}" ]]; then
  add_user_mcp_http github https://api.githubcopilot.com/mcp/ \
    --header "Authorization: Bearer ${GITHUB_MCP_KEY}"
else
  echo "⚠ GITHUB_MCP_KEY not set, skipping github MCP. Export it and re-run."
fi

# Playwright (local stdio)
add_user_mcp playwright -- npx -y @playwright/mcp@latest

# Recraft (remote HTTP)
add_user_mcp_http recraft https://mcp.recraft.ai/mcp

echo ""
echo "Done. Run 'claude mcp list' to verify."
