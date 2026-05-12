#!/usr/bin/env bash
# Swap the active Claude Code user settings between personal and work.
#
# Usage:
#   bash ~/.claude/use-profile.sh personal
#   bash ~/.claude/use-profile.sh work
#
# Both source files live in ~/dotfiles/.claude/. This script symlinks the
# requested one to ~/.claude/settings.json so Claude Code picks it up.

set -euo pipefail

PROFILE="${1:-}"
DOTFILES="${HOME}/dotfiles/.claude"
TARGET="${HOME}/.claude/settings.json"

case "$PROFILE" in
  personal|p)
    SRC="${DOTFILES}/settings.json"
    ;;
  work|w)
    SRC="${DOTFILES}/settings.work.json"
    ;;
  status|"")
    if [[ -L "$TARGET" ]]; then
      echo "Active: $(readlink "$TARGET")"
    else
      echo "Active: $TARGET (not a symlink)"
    fi
    exit 0
    ;;
  *)
    echo "Usage: $0 [personal|work|status]" >&2
    exit 1
    ;;
esac

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source not found: $SRC" >&2
  exit 1
fi

mkdir -p "${HOME}/.claude"
if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
  BACKUP="${TARGET}.bak.$(date +%s)"
  echo "Backing up existing $TARGET → $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

ln -sfn "$SRC" "$TARGET"
echo "Switched to '$PROFILE' profile: $TARGET → $SRC"
