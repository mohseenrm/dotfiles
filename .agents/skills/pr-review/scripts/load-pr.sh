#!/usr/bin/env bash
# load-pr.sh — Resolve a PR argument to a normalized JSON bundle.
#
# Usage: load-pr.sh "<arg>"
#   <arg> is one of:
#     - PR number          (e.g. "123")
#     - PR URL             (e.g. "https://github.com/org/repo/pull/123")
#     - "current"|"staged" (uses git diff)
#     - path to .diff/.patch file
#
# Output: a single JSON object on stdout with this shape:
#   {
#     "kind": "github" | "local" | "file",
#     "owner": "...", "repo": "...", "number": 123,         # github only
#     "url": "...",                                           # github only
#     "title": "...", "body": "...", "author": "...",         # github only
#     "base_ref": "...", "head_ref": "...",
#     "base_sha": "...", "head_sha": "...",
#     "additions": 0, "deletions": 0, "changed_files": 0,
#     "files": [ {filename, status, additions, deletions, patch}, ... ],
#     "checks": [ {name, state, bucket}, ... ],               # github only
#     "existing_reviews": [ {author, state, body}, ... ]       # github only
#   }
#
# Failures: prints an error to stderr and exits non-zero.
set -euo pipefail

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "load-pr.sh: missing argument" >&2
  exit 2
fi

# Tool checks
command -v jq >/dev/null 2>&1 || { echo "load-pr.sh: jq not found" >&2; exit 2; }

# Helper: emit a minimal "local" bundle from `git diff`
emit_local_bundle() {
  local kind="$1"   # "current" or "staged"
  local diff_flag=""
  [[ "$kind" == "staged" ]] && diff_flag="--cached"

  command -v git >/dev/null 2>&1 || { echo "load-pr.sh: git not found" >&2; exit 2; }

  # Build file list with per-file patches
  local files_json
  files_json=$(git diff $diff_flag --name-status | awk '{print $2 "\t" $1}' | while IFS=$'\t' read -r f s; do
    [[ -z "$f" ]] && continue
    local patch
    patch=$(git diff $diff_flag -- "$f" || true)
    local adds dels
    adds=$(echo "$patch" | grep -c '^+' || true)
    dels=$(echo "$patch" | grep -c '^-' || true)
    jq -n --arg f "$f" --arg s "$s" --arg p "$patch" --argjson a "${adds:-0}" --argjson d "${dels:-0}" \
      '{filename:$f, status:$s, additions:$a, deletions:$d, patch:$p}'
  done | jq -s '.')

  local totals
  totals=$(git diff $diff_flag --shortstat 2>/dev/null | awk '
    /file/ {
      for (i=1;i<=NF;i++) {
        if ($i ~ /^[0-9]+$/) {
          if ($(i+1) ~ /file/) files=$i
          else if ($(i+1) ~ /insertion/) adds=$i
          else if ($(i+1) ~ /deletion/) dels=$i
        }
      }
    }
    END { printf "{\"changed_files\":%d,\"additions\":%d,\"deletions\":%d}", files+0, adds+0, dels+0
  }')
  [[ -z "$totals" ]] && totals='{"changed_files":0,"additions":0,"deletions":0}'

  jq -n \
    --arg kind "local" \
    --arg base "HEAD" \
    --arg head "$kind" \
    --argjson totals "$totals" \
    --argjson files "$files_json" \
    '{
      kind:$kind, base_ref:$base, head_ref:$head,
      base_sha:"", head_sha:"",
      title:"local changes (\($head))", body:"", author:"",
      additions:$totals.additions, deletions:$totals.deletions,
      changed_files:$totals.changed_files,
      files:$files, checks:[], existing_reviews:[]
    }'
}

# Helper: emit a "file" bundle from a saved diff/patch
emit_file_bundle() {
  local path="$1"
  [[ -r "$path" ]] || { echo "load-pr.sh: cannot read $path" >&2; exit 2; }

  # Split the patch into per-file entries by "diff --git" boundaries
  local files_json
  files_json=$(awk '
    /^diff --git/ {
      if (buf != "") print buf "\x1f"
      buf = $0 "\n"
      next
    }
    { buf = buf $0 "\n" }
    END { if (buf != "") print buf }
  ' "$path" | tr -d '\r' | while IFS= read -r -d $'\x1f' chunk; do
    [[ -z "$chunk" ]] && continue
    local fname
    fname=$(echo "$chunk" | head -1 | sed -E 's|^diff --git a/(.*) b/.*|\1|')
    local adds dels
    adds=$(echo "$chunk" | grep -c '^+[^+]' || true)
    dels=$(echo "$chunk" | grep -c '^-[^-]' || true)
    jq -n --arg f "$fname" --arg p "$chunk" --argjson a "${adds:-0}" --argjson d "${dels:-0}" \
      '{filename:$f, status:"modified", additions:$a, deletions:$d, patch:$p}'
  done | jq -s '.')

  local n_files adds dels
  n_files=$(echo "$files_json" | jq 'length')
  adds=$(echo "$files_json" | jq '[.[].additions] | add // 0')
  dels=$(echo "$files_json" | jq '[.[].deletions] | add // 0')

  jq -n \
    --arg path "$path" \
    --argjson files "$files_json" \
    --argjson n "$n_files" --argjson a "$adds" --argjson d "$dels" \
    '{
      kind:"file", base_ref:"", head_ref:"", base_sha:"", head_sha:"",
      title:"saved diff: \($path)", body:"", author:"",
      additions:$a, deletions:$d, changed_files:$n,
      files:$files, checks:[], existing_reviews:[]
    }'
}

# Helper: emit a "github" bundle by querying gh
emit_github_bundle() {
  local owner="$1" repo="$2" num="$3"
  command -v gh >/dev/null 2>&1 || { echo "load-pr.sh: gh CLI not found" >&2; exit 2; }

  # Verify auth — `gh auth status` exits 1 if ANY account is broken even when an active account works.
  # Probe with a real API call instead.
  if ! gh api user >/dev/null 2>&1; then
    echo "load-pr.sh: gh CLI not authenticated for github.com. Run 'gh auth login'." >&2
    exit 2
  fi

  local meta
  meta=$(gh api "repos/${owner}/${repo}/pulls/${num}" 2>&1) || {
    echo "load-pr.sh: failed to fetch PR ${owner}/${repo}#${num}: $meta" >&2
    exit 2
  }

  local files
  files=$(gh api "repos/${owner}/${repo}/pulls/${num}/files" --paginate 2>&1) || {
    echo "load-pr.sh: failed to fetch files: $files" >&2
    exit 2
  }
  # `gh api --paginate` returns concatenated arrays; merge them
  files=$(echo "$files" | jq -s 'add // []')

  local checks
  checks=$(gh api "repos/${owner}/${repo}/commits/$(echo "$meta" | jq -r '.head.sha')/check-runs" 2>/dev/null | \
    jq '[.check_runs[]? | {name:.name, state:.status, conclusion:.conclusion, bucket:(if .conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out" then "fail" else "pass" end)}]' 2>/dev/null) || checks='[]'

  local reviews
  reviews=$(gh api "repos/${owner}/${repo}/pulls/${num}/reviews" 2>/dev/null | \
    jq '[.[] | {author:.user.login, state:.state, body:.body}]' 2>/dev/null) || reviews='[]'

  jq -n \
    --argjson meta "$meta" \
    --argjson files "$files" \
    --argjson checks "$checks" \
    --argjson reviews "$reviews" \
    --arg owner "$owner" --arg repo "$repo" \
    '{
      kind:"github",
      owner:$owner, repo:$repo,
      number:$meta.number,
      url:$meta.html_url,
      title:$meta.title, body:($meta.body // ""),
      author:$meta.user.login,
      base_ref:$meta.base.ref, head_ref:$meta.head.ref,
      base_sha:$meta.base.sha, head_sha:$meta.head.sha,
      additions:$meta.additions, deletions:$meta.deletions,
      changed_files:$meta.changed_files,
      files:[$files[] | {filename, status, additions, deletions, patch:(.patch // "")}],
      checks:$checks, existing_reviews:$reviews
    }'
}

# ---- Dispatch ----

case "$ARG" in
  current|staged|"my changes"|"unstaged")
    emit_local_bundle "${ARG/my changes/current}"
    ;;
  http*://github.com/*/*/pull/*)
    # https://github.com/org/repo/pull/123
    owner=$(echo "$ARG" | sed -E 's|.*github.com/([^/]+)/([^/]+)/pull/[0-9]+.*|\1|')
    repo=$(echo "$ARG"  | sed -E 's|.*github.com/([^/]+)/([^/]+)/pull/[0-9]+.*|\2|')
    num=$(echo "$ARG"   | sed -E 's|.*/pull/([0-9]+).*|\1|')
    emit_github_bundle "$owner" "$repo" "$num"
    ;;
  ''|*[!0-9]*)
    # Not all digits — must be a path
    if [[ -f "$ARG" ]]; then
      emit_file_bundle "$ARG"
    else
      echo "load-pr.sh: unrecognized argument '$ARG' (not a PR number, URL, keyword, or readable file)" >&2
      exit 2
    fi
    ;;
  *)
    # Pure number — use default repo from cwd
    command -v gh >/dev/null 2>&1 || { echo "load-pr.sh: gh CLI not found" >&2; exit 2; }
    repo_info=$(gh repo view --json owner,name 2>&1) || {
      echo "load-pr.sh: not in a gh-managed repo and PR number given without owner/repo. Use a full URL instead." >&2
      exit 2
    }
    owner=$(echo "$repo_info" | jq -r '.owner.login')
    repo=$(echo "$repo_info" | jq -r '.name')
    emit_github_bundle "$owner" "$repo" "$ARG"
    ;;
esac
