#!/usr/bin/env bash
# Symlink the canonical Claude preferences file to the AGENTS.md location that
# other agent tools (Codex, OpenCode, ...) look for, so they all reference the
# same single source of truth.
#
# Usage:
#   bash ~/.claude/link-agents-md.sh           # create the symlinks
#   bash ~/.claude/link-agents-md.sh status    # show current link state
#
# Source of truth: ~/dotfiles/.claude/CLAUDE.md
# Any existing real file at a target is backed up to <target>.bak before linking.

set -euo pipefail

SRC="${HOME}/dotfiles/.claude/CLAUDE.md"

# Targets that the various tools read their global agent instructions from.
TARGETS=(
  "${HOME}/.codex/AGENTS.md"
  "${HOME}/.config/opencode/AGENTS.md"
)

if [[ ! -f "$SRC" ]]; then
  echo "error: source not found: $SRC" >&2
  exit 1
fi

if [[ "${1:-}" == "status" ]]; then
  echo "source: $SRC"
  for target in "${TARGETS[@]}"; do
    if [[ -L "$target" ]]; then
      echo "  [linked]  $target -> $(readlink "$target")"
    elif [[ -e "$target" ]]; then
      echo "  [file]    $target (real file, not linked)"
    else
      echo "  [missing] $target"
    fi
  done
  exit 0
fi

for target in "${TARGETS[@]}"; do
  dir="$(dirname "$target")"
  mkdir -p "$dir"

  # Already pointing at the source? Nothing to do.
  if [[ -L "$target" && "$(readlink "$target")" == "$SRC" ]]; then
    echo "ok: $target already linked"
    continue
  fi

  # Back up an existing real file or wrong symlink so no content is lost.
  if [[ -e "$target" || -L "$target" ]]; then
    backup="${target}.bak"
    mv "$target" "$backup"
    echo "backed up: $target -> $backup"
  fi

  ln -s "$SRC" "$target"
  echo "linked: $target -> $SRC"
done
