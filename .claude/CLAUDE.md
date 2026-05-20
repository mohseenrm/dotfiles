# Personal Claude Code Preferences

## Communication style
- No preamble, no flattery, no "Great question!", no status narration. Start work immediately.
- Match my register. Terse user → terse you.
- When I'm wrong, say so + propose alternative + ask. Don't lecture.

## Verification
- Verify before claiming done. Run the test. Execute the script. Check the output.
- If a test fails, say so with the output. Never imply it passed.
- Never delete failing tests to get a green build. Never add `as any`, `@ts-ignore`, or `@ts-expect-error` to bypass type errors.

## Scope discipline
- Smallest correct change wins. Bug fix ≠ refactor.
- Don't create new files unless necessary. Prefer editing existing.
- Don't add error handling for impossible scenarios. Validate only at system boundaries.
- Duplication > premature abstraction for one-time operations.
- Clean up temp files / scripts at task end.

## Investigation
- Never speculate about code I haven't read. If the user references a file, read it first.
- Ground every claim in actual tool output.
- Parallelize independent reads/searches in one response.

## Action gating
- Reversible actions (file edits, tests, lint) — take freely.
- Destructive / shared-impact actions (`rm -rf`, force push, deleting branches, pushing to remote, sending messages, modifying shared infra) — ask first.
- Never use destructive shortcuts to "fix" stuck states. No `--no-verify`.

## Todos
- Multi-step task (2+ steps) → create todos immediately.
- Only one todo `in_progress` at a time.
- Mark `completed` as soon as done, never batch.

## File links
When referencing files in output, use clickable links:
- `[display text](file:///absolute/path/to/file.ts)`
- Line range: `[auth logic](file:///abs/path/auth.ts#L15-L23)`

## Environment
- Working machine: macOS, zsh, Neovim primary editor
- Package manager: prefer existing project tooling (pnpm/npm/yarn/bun — detect from lockfile)
- Style: 2-space indent for Lua/TS/JS, follow existing project config

## Dotfiles repo
- Stowed via GNU stow from `~/dotfiles/`
- `stow .` to link, `stow -D .` to unlink
- Work-specific configs are gitignored (Brewfile.work, work.zsh, opencode.work.jsonc, settings.work.json)
