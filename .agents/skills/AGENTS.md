# Skills - canonical source of truth

**All skills live in `~/dotfiles/.agents/skills/<name>/SKILL.md`. Nothing else is a source.**

Claude Code, Codex, and OpenCode all read this one tree. `~/.claude/skills/` and
`~/.agents/skills/` are directories of symlinks that resolve back here; they are
delivery, not storage. Never edit a skill through a symlink path and never copy a
skill into a per-tool directory - that is what created the duplicate and stale
listings this layout replaced.

## How each tool finds these

| Tool | Reads | How it gets here |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>/SKILL.md` | stow → `dotfiles/.claude/skills/<name>` → `../../.agents/skills/<name>` |
| Codex | `$CODEX_HOME/skills` **and** `~/.agents/skills` | stow → `dotfiles/.agents/skills/<name>` |
| OpenCode | `~/.claude/skills/` and `~/.agents/skills/` (auto-loaded) | same two trees; dedupes by resolved path |

Codex also scans `~/.codex/skills/`. Keep that directory empty except Codex's own
`.system/` - anything else there shadows this tree and shows up twice.

## Adding a skill

```sh
cd ~/dotfiles
mkdir -p .agents/skills/my-skill
$EDITOR .agents/skills/my-skill/SKILL.md          # frontmatter below
ln -s ../../.agents/skills/my-skill .claude/skills/my-skill
stow .                                            # links it into ~
```

Then verify it in both non-Claude tools:

```sh
opencode debug skill | grep my-skill              # no API key needed
codex exec --skip-git-repo-check -m gpt-5.5 \
  -c model_reasoning_effort=low "List every skill available to you."
```

The skill must appear **exactly once** in each. A duplicate means a stray copy
exists outside this tree.

## SKILL.md frontmatter

```yaml
---
name: my-skill                  # must equal the directory name
description: One line covering what it does AND when to use it; this is all
  the model sees when deciding whether to load the skill.
---
```

Portability rules, learned the hard way:

- Write `description` as a **plain scalar or `|-` block**. Both parse everywhere.
- Keep any upstream `metadata:` block (version, author, repository, tags) intact.
  Reformatting a vendored skill silently drops it.
- Add `disable-model-invocation: true` for skills only a human should trigger
  (`wayfinder`, `grill-me`, `grill-with-docs`). Codex then omits them from the
  model-visible list while OpenCode still lists them - that asymmetry is expected.
- Don't rely on Claude-Code-only tools (`Task`, `TodoWrite`, MCP servers) in the
  main path if the skill should work in Codex/OpenCode. Shell out via `gh`, `git`,
  and plain CLIs, which all three have.

## Build artifacts

`node_modules/` and `.pytest_cache/` under a skill's `scripts/` are gitignored,
but OpenCode still scans the working tree and will register any vendored
`SKILL.md` it finds (Playwright ships two). After running `pnpm install` in a
skill's `scripts/`, re-check `opencode debug skill` for junk entries and delete
`node_modules/` when you're done with it.

`qa-ui/scripts` deps are regenerable: `cd .agents/skills/qa-ui/scripts && pnpm install`.

## Work-specific skills

`deploy-web-pr-to-stage` is gitignored (see the root `.gitignore`). It lives in
this tree and is symlinked like everything else, it just doesn't get committed.
Follow that pattern for anything employer-specific.
