# Severity Scale (CodeRabbit 5-tier)

Use these definitions verbatim. Calibration matters more than category — apply the same bar across every PR.

## 🔴 Critical — blocks merge

**Definition**: System failure, security breach, data loss, or production crash.

**Examples**:
- SQL injection, command injection, deserialization RCE
- Auth bypass, IDOR, missing authorization on sensitive endpoint
- Unencrypted credential storage, key/secret in code or logs
- Data corruption: missing transaction wrapping multi-write op, silent data loss on partial failure
- Crash on common input: null deref on documented field, unhandled exception in request handler
- Memory safety bug in unsafe code
- Race that can corrupt shared state

**Test**: Can you write a literal request, command, or sequence that triggers this in production within the next 30 days?

## 🟠 Major — blocks merge

**Definition**: Significant impact on functionality, performance, or user experience under normal usage.

**Examples**:
- Wrong behavior users hit in normal usage (not edge case)
- Performance regression measurable in production: 10x slower hot path, N+1 query introduced
- Missing input validation on a user-controlled boundary (no immediate breach, but unsafe)
- Resource leak under load: timer not cleaned up, connection not closed
- Backward-compat break in a public API or wire format without versioning
- Missing error handling on an async path that will surface as a Sentry-level error
- Major code-smell that will materially slow the next developer (e.g., a 400-line function with deep nesting)

**Test**: Will this cause a P1/P2 bug report, a customer escalation, or a major refactor within 90 days?

## 🟡 Minor — should fix, not blocking

**Definition**: Wrong behavior in edge cases, code quality issues that warrant fixing but don't block merge.

**Examples**:
- Edge-case bug: empty array, single-element collection, leap year, DST boundary
- Resource leak only under exceptional conditions
- Inconsistent error message format
- Missing test for a non-trivial branch (the branch is correct but untested)
- Code-smell with clear refactor path: duplicated logic in 2-3 places, magic number that should be a constant
- Naming that's likely to mislead future readers

## 🔵 Trivial — code quality

**Definition**: Code quality improvement with no behavioral impact.

**Examples**:
- Variable name could be clearer
- Comment is stale or misleading
- Could use a more idiomatic pattern
- Minor duplication that's tolerable
- Stylistic inconsistency with surrounding code (but not against a linter rule)

## ⚪ Info — context only

**Definition**: Context the author should know but isn't a flaw.

**Examples**:
- "Note: this changes the default behavior of X — make sure that's intentional"
- "FYI: this pattern is deprecated in the next major version of library Y"
- "Worth mentioning: this codepath is hit on every request, so the perf cost compounds"

---

## Severity calibration anti-patterns

These cause severity inflation. Demote when you catch yourself doing them:

1. **"Could", "might", "would allow"** without a concrete scenario → demote one tier
2. **Theoretical chaining**: "if A and B and C, then…" — each unverified link multiplies uncertainty → demote
3. **Hypothetical bug without repro**: if you can't write the literal triggering input, it's Minor at best, not Critical
4. **Severity from prose, not impact**: ask "what does the attacker gain?" / "what does the system lose?" — if you can't answer concretely, demote
5. **Style/preference framed as bug**: "this is hard to read" is not Major; it's Trivial at best

---

## Decision flow for ambiguous severity

```
Does the bug cause:
├── Data loss / security breach / production crash?       → Critical
├── Wrong behavior in normal usage / measurable perf hit?  → Major
├── Wrong behavior in edge case / quality issue?           → Minor
├── Code quality nit?                                       → Trivial
└── Just context?                                           → Info
```

When in doubt between two tiers, pick the lower one. Inflated severity is the #1 reason developers ignore review tools.
