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

  # Already pointing at the source? Nothing to do. Compare resolved paths so a
  # relative link (written for stow-folded targets below) still counts.
  if [[ -L "$target" ]] && [[ "$(readlink -f "$target" 2>/dev/null)" == "$(readlink -f "$SRC")" ]]; then
    echo "ok: $target already linked"
    continue
  fi

  # Leave stow-managed targets alone. ~/.codex/AGENTS.md is symlinked to
  # dotfiles/.codex/AGENTS.md, which holds Codex-specific instructions (skills
  # layout, review subagents). Replacing it with CLAUDE.md would drop them.
  if [[ -L "$target" ]]; then
    link="$(readlink "$target")"
    if [[ "$link" == *"/dotfiles/"* || "$link" == ../dotfiles/* ]]; then
      echo "skip: $target is stow-managed -> $link"
      continue
    fi
  fi

  # Back up an existing real file or wrong symlink so no content is lost.
  if [[ -e "$target" || -L "$target" ]]; then
    backup="${target}.bak"
    mv "$target" "$backup"
    echo "backed up: $target -> $backup"
  fi

  # Some targets (~/.config/opencode) are stow-folded back into the repo, so an
  # absolute link would be written into dotfiles itself. Use a relative link
  # there to keep the repo portable.
  real_dir="$(cd "$dir" && pwd -P)"
  case "$real_dir" in
    "${HOME}/dotfiles"|"${HOME}/dotfiles"/*)
      link_target="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$SRC" "$real_dir")"
      ;;
    *) link_target="$SRC" ;;
  esac

  ln -s "$link_target" "$target"
  echo "linked: $target -> $link_target"
done
