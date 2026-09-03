---
name: dreyer-english
description: Edit, review, or look up prose against the clarity-and-style rules from Benjamin Dreyer's *Dreyer's English*. Use when asked to tighten or polish writing, cut wan intensifiers (very, really, actually) and redundancies (ATM machine, close proximity), fix confusables (affect/effect, its/it's), apply punctuation/number/grammar rules, check a spelling, or answer a usage question. Args: `edit` (default), `review`, `lookup`.
---

# Dreyer's English

Apply the copy-chief rules from *Dreyer's English* to make prose clearer and tighter. Three modes, chosen by the first argument.

## Arguments

- `edit <text|path>` (default) — rewrite the text applying the rules, then show a compact changelog. This is the default when the first word isn't `review` or `lookup`; bare text or a file path is treated as `edit`.
- `review <text|path>` — flag issues with rule + suggestion, but do **not** rewrite. Leaves the edit to the user.
- `lookup <question>` — answer a usage/spelling/grammar question from the references. E.g. `lookup affect vs effect`, `lookup is "ATM machine" redundant`.

If no text or path is given, ask what to edit/review, or answer the lookup question directly.

## References (load on demand, don't preload all)

Bundled in `references/`. Read only what the task needs; for `edit`/`review` prefer **grepping** the tables for terms that actually appear in the text rather than reading them whole.

- `references/usage.md` — wan intensifiers, the trim principle, numbers, grammar heuristics, top peeves. Small; read fully in any mode.
- `references/confusables.md` — ~154 confusable word pairs (affect/effect, adverse/averse). Grep by word.
- `references/trimmables.md` — ~89 redundancies (**bold** = keep, rest = cut). Grep by phrase.
- `references/misspellings.md` — ~116 correct spellings + notes. Grep by word.
- `references/punctuation.md` — 66 numbered punctuation rules, grouped by mark.

## Core rules (inline, always available)

The cheap high-value wins, so the skill works even before opening a reference:

- **Wan intensifiers / throat-clearers** — delete: *very, rather, really, quite, in fact, just* (merely), *so* (extremely), *pretty, of course, surely, that said, actually*. If the sentence weakens without one, find a stronger word.
- **Two words where one will do** — cut redundancies: *ATM machine, added bonus, close proximity, advance planning, end result, consensus of opinion*. (Full list: `trimmables.md`.)
- **Top confusables** — *affect* (usually verb) / *effect* (usually noun); *its* (possessive) / *it's* (it is); *fewer* (countable) / *less* (mass); *your/you're, their/there/they're, lie/lay, farther* (distance) / *further* (degree), *principal/principle, complement/compliment*.
- **Punctuation quick hits** — one space after a period, not two; use the serial (Oxford) comma; a semicolon joins two full clauses; drop periods in initialisms (FBI, not F.B.I.).
- **Numbers** — spell out one through one hundred; numerals beyond, kept consistent within a comparison; avoid numerals in dialogue.

## Mode: edit

1. Read the text. Read `references/usage.md`. Grep `confusables.md` / `trimmables.md` / `misspellings.md` for words/phrases that appear in the text.
2. Rewrite applying the rules. **Preserve the author's voice and meaning** - tighten, don't rewrite from scratch. Don't over-edit: leave intentional style alone.
3. Output the rewritten text first, then a compact changelog table:

   | Rule | Before | After |
   |------|--------|-------|
   | wan intensifier | "very unique" | "unique" |
   | redundancy | "ATM machine" | "ATM" |

Only list changes you actually made. If nothing needs changing, say so.

## Mode: review

Same detection as `edit`, but **do not rewrite**. Output a findings list: location (quote the span), the rule it violates, and a suggested fix. Group by severity if helpful (clear error vs. style suggestion). The user decides what to apply.

## Mode: lookup

1. Identify which reference holds the answer (confusable pair - `confusables.md`; redundancy - `trimmables.md`; spelling - `misspellings.md`; punctuation - `punctuation.md`; intensifier/number/grammar - `usage.md`).
2. Grep it for the term, read the entry, and give the specific distinction concisely. Cite the rule, don't dump the file.

## Guardrails

- **These are defaults, not commandments.** Dreyer's own "Rules and Nonrules" spirit: flag, don't dogmatically enforce. Respect dialect, register, and deliberate voice. Split infinitives and sentence-final prepositions are fine; don't "correct" them.
- **Don't strip the user's em dashes.** Claude's own output avoids em dashes (per user preference), but this skill edits the *user's* text - leave their em dashes and other stylistic punctuation intact unless genuinely misused.
- **When a "rule" is contested** (singular *they*, *alright*, sentence-starting *and*), note both the traditional line and that it's a judgment call; don't force it.
- Preserve meaning above all. If a tightening changes the sense, don't make it.
