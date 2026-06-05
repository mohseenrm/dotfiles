# Global Agent Instructions

Migrated from opencode (`.config/opencode/opencode.jsonc`). User-level
preferences also live in `~/.claude/CLAUDE.md`; honor both.

## Plans

When creating or updating plans, always save them as markdown files in
`~/Projects/plans/`. Use descriptive kebab-case filenames (e.g.
`2025-04-04-auth-redesign.md`). When searching for or referencing existing
plans, look in `~/Projects/plans/` first.

## Goals

A "Goal" is a persistent session objective with evidence-gated completion (see
the `/goal` prompt). Only mark a Goal complete after verifying it against
concrete evidence — test output, benchmark numbers, a built artifact, command
output, or inspected files. Never claim completion based on intent.

## Review subagents

Custom review agents are defined in `~/.codex/agents/`:
- `code_reviewer` — best-practices review, P0–P3 rubric, T-shirt-sized feedback.
- `adversarial_reviewer` — forced-reasoning adversarial review (must find issues).
- `git_pick` — splits a branch into `-generated` and `-core` review branches.

Spawn them only when explicitly asked.
