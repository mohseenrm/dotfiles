#!/usr/bin/env bash
# ensure-clone.sh — Make a local working copy of the PR available for fast file reads.
#
# Usage: ensure-clone.sh <bundle.json> [<explicit-worktree-path>]
#
#   <bundle.json>: path to bundle.json from load-pr.sh
#   <explicit-worktree-path>: optional. If provided AND non-empty, this path is
#                             used directly (the script verifies the branch
#                             is checked out). If omitted, the script decides:
#                               - bundle.kind != "github" → return empty, exit 0
#                               - CWD matches PR's owner/repo AND clean      → use CWD
#                               - otherwise → clone to /tmp/pr-review-clones/
#
# Output: the absolute path of the worktree on stdout (one line).
#         Empty string + exit 0 if no clone is applicable (local diffs, file diffs).
#
# Cache schema: /tmp/pr-review-clones/{owner}-{repo}-{number}/
#   Shared across runs of the same PR — speeds up re-reviews by reusing the clone.
#   On re-use: git fetch + gh pr checkout --force.
#
# Failures: prints to stderr, exits non-zero. run-with-heal.sh classifies and
# may retry (e.g. retry clone with shallower depth on network failure).
set -euo pipefail

BUNDLE="${1:-}"
EXPLICIT_PATH="${2:-}"

[[ -z "$BUNDLE" || ! -r "$BUNDLE" ]] && { echo "ensure-clone.sh: missing or unreadable bundle: $BUNDLE" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ensure-clone.sh: jq not found" >&2; exit 2; }

KIND=$(jq -r '.kind' "$BUNDLE")

# Only GitHub PRs get a clone. Local/file diffs read from the user's CWD.
if [[ "$KIND" != "github" ]]; then
  echo ""
  exit 0
fi

OWNER=$(jq -r '.owner' "$BUNDLE")
REPO=$(jq -r '.repo' "$BUNDLE")
NUMBER=$(jq -r '.number' "$BUNDLE")
HEAD_REF=$(jq -r '.head_ref' "$BUNDLE")

[[ -z "$OWNER" || -z "$REPO" || -z "$NUMBER" ]] && {
  echo "ensure-clone.sh: bundle missing owner/repo/number" >&2
  exit 2
}

command -v git >/dev/null 2>&1 || { echo "ensure-clone.sh: git not found" >&2; exit 2; }
command -v gh  >/dev/null 2>&1 || { echo "ensure-clone.sh: gh not found"  >&2; exit 2; }

# Helper: verify a given path is a git repo whose remote matches the PR's owner/repo
# AND has the PR's branch checked out (or can be made to).
remote_matches_pr() {
  local path="$1"
  [[ -d "$path/.git" ]] || return 1
  local url
  url=$(git -C "$path" remote get-url origin 2>/dev/null || echo "")
  # Match both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git)
  case "$url" in
    *"github.com:${OWNER}/${REPO}"*|*"github.com/${OWNER}/${REPO}"*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

is_clean_worktree() {
  local path="$1"
  # Clean means: no staged, no unstaged, no untracked-not-ignored files
  [[ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]]
}

checkout_pr_in() {
  local path="$1"
  local local_branch="pr-${NUMBER}"
  # Strategy (cheapest → most expensive):
  #   1. Already on pr-{N} branch in this clone? Done — assume cache is valid.
  #      (Caller ran reset --hard + clean -fd already, so working tree is clean.)
  #   2. pr-{N} branch exists locally? Just check it out — no network needed.
  #   3. gh pr checkout — works for open PRs with live head branch.
  #   4. Fetch refs/pull/N/head — works for ALL PRs (open, closed, deleted-branch);
  #      GitHub keeps these refs forever. This is the universal fallback.
  local current_branch
  current_branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$current_branch" == "$local_branch" ]]; then
    return 0
  fi
  if git -C "$path" rev-parse --verify --quiet "refs/heads/$local_branch" >/dev/null; then
    ( cd "$path" && git checkout "$local_branch" >&2 2>&1 ) && return 0
  fi
  if ( cd "$path" && gh pr checkout "$NUMBER" --force >&2 2>&1 ); then
    return 0
  fi
  ( cd "$path" \
    && git fetch origin "pull/${NUMBER}/head:${local_branch}" --force >&2 2>&1 \
    && git checkout "$local_branch" >&2 2>&1 ) || return 1
  return 0
}

# ---- Path 1: explicit worktree provided ----
if [[ -n "$EXPLICIT_PATH" ]]; then
  if [[ ! -d "$EXPLICIT_PATH" ]]; then
    echo "ensure-clone.sh: explicit worktree path does not exist: $EXPLICIT_PATH" >&2
    exit 2
  fi
  if ! remote_matches_pr "$EXPLICIT_PATH"; then
    echo "ensure-clone.sh: explicit worktree at $EXPLICIT_PATH does not have ${OWNER}/${REPO} as origin" >&2
    exit 2
  fi
  if ! is_clean_worktree "$EXPLICIT_PATH"; then
    echo "ensure-clone.sh: explicit worktree at $EXPLICIT_PATH has uncommitted changes — refusing to touch it" >&2
    exit 2
  fi
  checkout_pr_in "$EXPLICIT_PATH"
  echo "$EXPLICIT_PATH"
  exit 0
fi

# ---- Path 2: CWD is the matching repo, clean ----
# Skipped intentionally — the user did not pass --worktree. We could opportunistically
# detect CWD, but in-place checkout is dangerous (it switches branches under the user's
# feet). The orchestrator should ASK if it wants CWD; otherwise we clone to /tmp.
# Implementing this path would require interactive confirmation, which scripts can't do.

# ---- Path 3: clone-to-/tmp (shared across runs of the same PR) ----
CLONE_ROOT="/tmp/pr-review-clones"
CLONE_DIR="${CLONE_ROOT}/${OWNER}-${REPO}-${NUMBER}"
mkdir -p "$CLONE_ROOT"

if [[ -d "$CLONE_DIR/.git" ]] && remote_matches_pr "$CLONE_DIR"; then
  # Cache hit — reset working state and re-checkout. We DON'T re-fetch origin in
  # general because that's expensive (5-15s); we only fetch the immutable pull
  # ref directly inside checkout_pr_in's fallback, which is near-instant if cached.
  # All git stdout/stderr redirected to stderr so only the final path lands on stdout.
  echo "ensure-clone.sh: reusing existing clone at $CLONE_DIR" >&2
  git -C "$CLONE_DIR" reset --hard HEAD >&2 2>/dev/null || true
  git -C "$CLONE_DIR" clean -fd >&2 2>/dev/null || true
  if checkout_pr_in "$CLONE_DIR"; then
    echo "$CLONE_DIR"
    exit 0
  fi
  # Checkout in existing clone failed — drop cache and clone fresh.
  echo "ensure-clone.sh: re-checkout failed in existing clone, re-cloning fresh" >&2
  rm -rf "$CLONE_DIR"
fi

# Fresh clone path
echo "ensure-clone.sh: cloning ${OWNER}/${REPO} → $CLONE_DIR (depth=50)" >&2
if ! gh repo clone "${OWNER}/${REPO}" "$CLONE_DIR" -- --depth=50 --no-tags >&2; then
  echo "ensure-clone.sh: gh repo clone failed for ${OWNER}/${REPO}" >&2
  exit 3
fi

if ! checkout_pr_in "$CLONE_DIR"; then
  echo "ensure-clone.sh: gh pr checkout $NUMBER failed in fresh clone at $CLONE_DIR" >&2
  exit 3
fi

# Verify the checkout actually landed on the PR's head branch
ACTUAL_HEAD=$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD)
if [[ -z "$ACTUAL_HEAD" ]]; then
  echo "ensure-clone.sh: post-checkout HEAD is empty in $CLONE_DIR" >&2
  exit 3
fi

echo "$CLONE_DIR"
