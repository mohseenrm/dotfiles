#!/usr/bin/env bash
# init-run.sh — Create the per-run workspace and emit its path.
#
# Usage: init-run.sh "<arg>"
#   <arg> is the same PR argument passed to load-pr.sh
#         (number, URL, "current", or path to a diff file).
#
# Output: the absolute path of the run dir on stdout, one line.
#         Directory structure created:
#           $RUN_DIR/
#             ├── findings/         (per-agent JSON output)
#             ├── findings/verify/  (per-finding verify output)
#             ├── screenshots/      (Playwright captures, UX only)
#             ├── heal.log          (self-heal actions, appended)
#             └── meta.json         (run metadata)
#
# Path schema: /tmp/pr-review-{id}/{YYYYMMDD-HHMMSS-{pid}}/
#   {id} = gh-{owner}-{repo}-{number} | local | file-{sha1-first8}
#
# Failures: prints error to stderr, exits non-zero.
set -euo pipefail

ARG="${1:-}"
[[ -z "$ARG" ]] && { echo "init-run.sh: missing argument" >&2; exit 2; }

# Compute stable id from the argument so parallel runs against the same PR
# share a parent dir (easier to find), while each run gets its own timestamped child.
compute_id() {
  local a="$1"
  case "$a" in
    current|staged|"my changes"|unstaged)
      echo "local"
      ;;
    http*://github.com/*/*/pull/*)
      local owner repo num
      owner=$(echo "$a" | sed -E 's|.*github.com/([^/]+)/([^/]+)/pull/[0-9]+.*|\1|')
      repo=$(echo "$a"  | sed -E 's|.*github.com/([^/]+)/([^/]+)/pull/[0-9]+.*|\2|')
      num=$(echo "$a"   | sed -E 's|.*/pull/([0-9]+).*|\1|')
      echo "gh-${owner}-${repo}-${num}"
      ;;
    ''|*[!0-9]*)
      if [[ -f "$a" ]]; then
        local hash
        hash=$(printf '%s' "$a" | shasum | cut -c1-8)
        echo "file-${hash}"
      else
        echo "unknown"
      fi
      ;;
    *)
      # Pure number — try to read owner/repo from gh, fall back to just number
      if command -v gh >/dev/null 2>&1 && gh api user >/dev/null 2>&1; then
        local info owner repo
        info=$(gh repo view --json owner,name 2>/dev/null || echo "")
        if [[ -n "$info" ]]; then
          owner=$(echo "$info" | jq -r '.owner.login')
          repo=$(echo "$info" | jq -r '.name')
          echo "gh-${owner}-${repo}-${a}"
          return
        fi
      fi
      echo "pr-${a}"
      ;;
  esac
}

ID=$(compute_id "$ARG")
TIMESTAMP="$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR="/tmp/pr-review-${ID}/${TIMESTAMP}"

mkdir -p "$RUN_DIR/findings/verify" "$RUN_DIR/screenshots"
touch "$RUN_DIR/heal.log"

# Write run metadata for later debugging
command -v jq >/dev/null 2>&1 || { echo "init-run.sh: jq not found" >&2; exit 2; }
jq -n \
  --arg id "$ID" \
  --arg ts "$TIMESTAMP" \
  --arg arg "$ARG" \
  --arg run_dir "$RUN_DIR" \
  --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{id:$id, timestamp:$ts, argument:$arg, run_dir:$run_dir, started_at:$started_at}' \
  > "$RUN_DIR/meta.json"

echo "$RUN_DIR"
