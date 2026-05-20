#!/usr/bin/env bash
# run-with-heal.sh — Run a pr-review script, attempt one heal on known-recoverable failures.
#
# Usage: run-with-heal.sh <run-dir> <script> [args...]
#
#   <run-dir>: the workspace dir from init-run.sh; receives heal.log entries
#   <script>:  absolute path to the script to run
#   [args]:    forwarded to the script
#
# Output: forwards stdout of the script. On heal+re-run-success, the heal is
#         logged to <run-dir>/heal.log AND announced on stderr.
#
# Healable failures (one heal attempt each, never infinite-loop):
#   - jq missing → suggest brew install jq (abort if user not interactive)
#   - gh missing → suggest brew install gh, abort
#   - gh not authenticated for github.com → suggest `gh auth login`, abort
#   - gh api 403 (forbidden) → suggest `gh auth refresh -s repo`, abort
#   - gh api 404 (not found) → wrong owner/repo/number, abort with diagnostic
#   - empty/null JSON output → log to <run-dir>/raw/<script>.txt for debugging
#
# Bugs in our own scripts (jq compile errors, syntax errors) → abort with full
# diagnostic. Those are not healable, they're fix-and-retry manually.
set -euo pipefail

RUN_DIR="${1:-}"
SCRIPT="${2:-}"
shift 2 2>/dev/null || { echo "run-with-heal.sh: usage: run-with-heal.sh <run-dir> <script> [args...]" >&2; exit 2; }

[[ -d "$RUN_DIR" ]] || { echo "run-with-heal.sh: run-dir does not exist: $RUN_DIR" >&2; exit 2; }
[[ -x "$SCRIPT" ]] || { echo "run-with-heal.sh: script not executable: $SCRIPT" >&2; exit 2; }

HEAL_LOG="$RUN_DIR/heal.log"
SCRIPT_NAME=$(basename "$SCRIPT")

log_heal() {
  local msg="$1"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $SCRIPT_NAME: $msg" >> "$HEAL_LOG"
  echo "🔧 self-heal: $msg" >&2
}

# Run once, capture stdout+stderr separately
STDOUT=$(mktemp)
STDERR=$(mktemp)
trap 'rm -f "$STDOUT" "$STDERR"' EXIT

EXIT=0
"$SCRIPT" "$@" >"$STDOUT" 2>"$STDERR" || EXIT=$?

if [[ "$EXIT" -eq 0 ]]; then
  cat "$STDOUT"
  exit 0
fi

# First attempt failed — classify the error and try ONE heal
STDERR_CONTENT=$(cat "$STDERR")

classify_error() {
  case "$STDERR_CONTENT" in
    *"jq: command not found"*|*"jq not found"*)
      echo "jq-missing" ;;
    *"gh: command not found"*|*"gh CLI not found"*)
      echo "gh-missing" ;;
    *"git: command not found"*|*"git not found"*)
      echo "git-missing" ;;
    *"gh CLI not authenticated"*|*"authentication required"*)
      echo "gh-auth-missing" ;;
    *"HTTP 403"*|*"403 Forbidden"*)
      echo "gh-403" ;;
    *"HTTP 404"*|*"404 Not Found"*)
      echo "gh-404" ;;
    *"gh repo clone failed"*|*"could not read Username"*|*"Could not resolve host"*)
      echo "clone-network" ;;
    *"explicit worktree"*"uncommitted changes"*)
      echo "worktree-dirty" ;;
    *"explicit worktree"*"does not have"*"origin"*)
      echo "worktree-mismatch" ;;
    *"jq: error"*|*"jq: 2 compile errors"*)
      echo "jq-bug" ;;
    *)
      echo "unknown" ;;
  esac
}

ERROR_CLASS=$(classify_error)

case "$ERROR_CLASS" in
  jq-missing)
    log_heal "jq is required but not installed. Skill is aborting. To self-heal: run 'brew install jq' (macOS) or 'apt install jq' (Linux), then re-run the skill."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  gh-missing)
    log_heal "gh CLI required but not installed. Skill is aborting. To self-heal: run 'brew install gh' then 'gh auth login', then re-run."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  gh-auth-missing)
    log_heal "gh CLI not authenticated for github.com. Skill is aborting. To self-heal: run 'gh auth login -h github.com', then re-run."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  gh-403)
    log_heal "GitHub returned 403 — token likely missing 'repo' scope. Attempting auth refresh."
    if gh auth refresh -s repo 2>>"$HEAL_LOG"; then
      log_heal "auth scope refreshed; retrying $SCRIPT_NAME"
      EXIT=0
      "$SCRIPT" "$@" >"$STDOUT" 2>"$STDERR" || EXIT=$?
      if [[ "$EXIT" -eq 0 ]]; then
        cat "$STDOUT"
        exit 0
      fi
      log_heal "retry after auth refresh still failed (exit $EXIT). Original error follows."
    else
      log_heal "auth refresh failed — user must run 'gh auth refresh -s repo' interactively."
    fi
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  gh-404)
    log_heal "GitHub returned 404 — PR/repo not found. Check the URL or PR number. Skill is aborting."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  git-missing)
    log_heal "git not installed. Skill is aborting. To self-heal: install git (xcode-select --install on macOS), then re-run."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  clone-network)
    log_heal "git/gh clone failed — likely network issue. Skill is aborting. Check connectivity (ping github.com) and re-run; the cache will persist if the next run succeeds."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  worktree-dirty)
    log_heal "Explicit worktree path has uncommitted changes; the skill refused to touch it. Either stash/commit your changes and re-run, or omit --worktree to use a fresh /tmp clone."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  worktree-mismatch)
    log_heal "Explicit worktree path's origin doesn't match the PR's repo. Either point at the right local checkout, or omit --worktree to clone fresh."
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  jq-bug)
    log_heal "Internal jq syntax error in $SCRIPT_NAME — this is a bug in the skill, not a recoverable failure. Aborting."
    log_heal "Full stderr saved to $RUN_DIR/raw/${SCRIPT_NAME}.err"
    mkdir -p "$RUN_DIR/raw"
    cp "$STDERR" "$RUN_DIR/raw/${SCRIPT_NAME}.err"
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;

  unknown|*)
    log_heal "unrecognized failure (exit $EXIT) — no heal available. Stderr captured for debugging."
    mkdir -p "$RUN_DIR/raw"
    cp "$STDERR" "$RUN_DIR/raw/${SCRIPT_NAME}.err"
    cat "$STDERR" >&2
    exit "$EXIT"
    ;;
esac
