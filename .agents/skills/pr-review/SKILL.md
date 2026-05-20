---
name: pr-review
description: |
  Comprehensive multi-agent PR review. Spawns 7 parallel specialist agents
  (bugs, security, performance, UX/a11y, adversarial, code-smell/backcompat,
  DX/extensibility), then runs a verification pass on every finding before
  producing a deduplicated, severity-ranked verdict. UX agent captures
  Playwright screenshots at mobile/tablet/desktop viewports when a deploy
  preview URL is detected. Each run gets an isolated workspace so parallel
  reviews never collide. Scripts self-heal on known-recoverable failures
  (auth, rate limits, missing tools) and announce the heal action. Use when
  the user asks to review a PR, audit a diff, "review #123", "look at this
  PR", or wants a thorough pre-merge review.
user-invocable: true
disable-model-invocation: true
argument-hint: [PR number, URL, "current" (for git diff), or path to a saved diff. Optionally suffix with `--worktree /abs/path/to/local/checkout` to use an existing worktree instead of cloning.]
allowed-tools: Agent, Bash, Read, Glob, Grep
metadata:
  author: mohseenrm
  version: "0.2.0"
---

# PR Review (Multi-Agent)

You are orchestrating a comprehensive PR review. The target is: $ARGUMENTS

This skill produces a high-confidence, severity-ranked review by spawning 7
specialist agents in parallel, then independently verifying every finding
before reporting. Without the verify pass, fan-out amplifies false positives —
that pass is non-negotiable.

---

## Phase 0: Initialize workspace, load & pre-process the PR

### Step 0.1: Init per-run workspace

**Always start here.** This isolates parallel runs so they never collide.

```bash
RUN_DIR=$(bash scripts/init-run.sh "$ARGUMENTS")
echo "Workspace: $RUN_DIR"
```

The script creates:

```
/tmp/pr-review-{id}/{timestamp-pid}/
  ├── findings/             (per-agent JSON output)
  ├── findings/verify/      (per-finding verify output)
  ├── screenshots/          (Playwright captures, UX agent)
  ├── heal.log              (self-heal action log)
  └── meta.json             (run metadata)
```

`{id}` is `gh-{owner}-{repo}-{number}` for GitHub PRs, `local` for git diff, `file-{hash}` for saved diffs. `{timestamp-pid}` ensures parallel runs against the same PR never collide.

**All subsequent scripts MUST be invoked through `scripts/run-with-heal.sh` with `$RUN_DIR` as the first argument.** This wrapper:

- Logs self-heal actions to `$RUN_DIR/heal.log`
- Announces heals on stderr (e.g. `🔧 self-heal: GitHub returned 403...`)
- Aborts cleanly with diagnostic when failures aren't recoverable

### Step 0.2: Load the PR

```bash
bash scripts/run-with-heal.sh "$RUN_DIR" scripts/load-pr.sh "$ARGUMENTS" > "$RUN_DIR/bundle.json"
```

Resolves `$ARGUMENTS` to a concrete PR context:

| Form | Action |
|---|---|
| Number (e.g. `123`) | Default repo: `gh pr view 123 --json ...` |
| URL (`github.com/org/repo/pull/N`) | Extract owner/repo/number, query gh |
| `current` / `staged` / `my changes` | `git diff` + `git diff --cached` (treat as synthetic PR) |
| Path to a `.diff`/`.patch` file | `cat` the file (treat as synthetic PR) |
| Anything else | Ask user to clarify |

The bundle has: metadata (title, author, base/head, additions, deletions), per-file patches (from `gh api .../pulls/N/files`), failing CI checks (from `gh pr checks`), and existing reviews/comments.

**Read the bundle yourself** before proceeding — you need the file list to classify into buckets.

### Step 0.3: Ensure a local working copy of the PR

For GitHub PRs, agents read files much faster from a local checkout than via the gh API (`Read`, `Grep`, LSP all work directly). This step makes one available.

```bash
# Parse $ARGUMENTS for an optional `--worktree /path` suffix:
EXPLICIT_WORKTREE=""
if [[ "$ARGUMENTS" == *"--worktree "* ]]; then
  EXPLICIT_WORKTREE=$(echo "$ARGUMENTS" | sed -E 's/.*--worktree[[:space:]]+([^[:space:]]+).*/\1/')
fi

CLONE_PATH=$(bash scripts/run-with-heal.sh "$RUN_DIR" scripts/ensure-clone.sh "$RUN_DIR/bundle.json" "$EXPLICIT_WORKTREE")
echo "$CLONE_PATH" > "$RUN_DIR/clone-path.txt"
```

Behavior by input:

| Input | Result |
|---|---|
| `current` / `staged` / file diff | `CLONE_PATH=""` — agents use the user's CWD as-is |
| GitHub PR, no `--worktree` | Clones to `/tmp/pr-review-clones/{owner}-{repo}-{number}/`, checks out PR head. **Shared cache** — same dir reused across reviews of the same PR (instant re-checkout if branch already there). |
| GitHub PR + `--worktree /path` | Uses `/path`. Refuses if path doesn't exist, has wrong `origin`, or has uncommitted changes. |

**Checkout strategy** (cheapest → most expensive, all in `ensure-clone.sh`):

1. Already on `pr-{N}` branch → done
2. `pr-{N}` branch exists locally → `git checkout pr-{N}` (no network)
3. `gh pr checkout {N}` → works for open PRs
4. `git fetch origin pull/{N}/head:pr-{N}` → universal fallback (works for closed/merged PRs with deleted branches, since GitHub keeps `refs/pull/N/head` forever)

**Performance**:
- Fresh clone of a typical repo: 5–20s
- Cache reuse (already-cloned, branch checked out): **~100ms**
- Cache reuse with branch switch: 1–2s

**Tell agents to read from `$CLONE_PATH`** when it's non-empty. When it's empty (local/file diffs), agents read from `$PWD` or the diff content. Embed the path in every specialist agent's prompt as a `local_clone_path` field.

### Step 0.4: Classify changed files into buckets

```bash
bash scripts/run-with-heal.sh "$RUN_DIR" scripts/classify-files.sh "$RUN_DIR/bundle.json" > "$RUN_DIR/buckets.json"
```

Buckets: `backend`, `frontend`, `infra`, `test`, `docs`, `generated`. The classification decides which conditional specialists fire (Phase 1).

### Step 0.5: Detect deploy preview URL (for UX screenshots)

```bash
PREVIEW_URL=$(bash scripts/run-with-heal.sh "$RUN_DIR" scripts/detect-preview-url.sh "$RUN_DIR/bundle.json")
echo "$PREVIEW_URL" > "$RUN_DIR/preview-url.txt"
```

Scans the PR body, bot comments, and CI check URLs for a Vercel/Netlify/Cloudflare/Render/Heroku/Fly preview URL. Returns empty if none found. **If empty, UX agent skips screenshotting** and logs the skip to `heal.log` — not a fatal condition.

### Step 0.6: Size gate

Read totals from `$RUN_DIR/bundle.json`:

- **Small** (<300 changed lines, <10 files) — inline per-file patches into agent prompts (plus give agents `$CLONE_PATH` for following references)
- **Medium** (300–1500 lines, 10–30 files) — inline; tell agents to prioritize highest-churn files, follow references via `$CLONE_PATH`
- **Large** (1500–5000 lines, 30–80 files) — DO NOT inline patches. Give agents `$CLONE_PATH` and the list of changed files; they `Read`/`Grep` directly from the local checkout
- **Very large** (>5000 lines or >80 files) — STOP. Tell the user this PR is too large for a single review. Suggest splitting by directory or feature, or running the skill per-subdirectory.

The local clone from Step 0.3 makes the Large path much faster than v0.1.0's "checkout in agent" approach — agents have instant disk access to every file in the repo at the PR's exact head.

### Step 0.7: Exclude files from review

CodeRabbit-standard defaults — skip findings on these (still pass to agents as context):

- Lockfiles: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Gemfile.lock`, `go.sum`, `Cargo.lock`, `poetry.lock`, `composer.lock`
- Generated: `**/*.generated.{ts,js}`, `**/dist/**`, `**/build/**`, `**/node_modules/**`, `**/vendor/**`
- Snapshots: `**/__snapshots__/**`, `**/*.snap`
- Binary/media: `**/*.{png,jpg,jpeg,gif,svg,pdf,woff,woff2,ico}`

The classifier script already tags these as `generated` — agents skip them.

---

## Phase 1: Specialist Fan-out (parallel)

Launch agents IN PARALLEL using the Agent tool. Each gets:

1. PR metadata (title, body, author, base/head) from `$RUN_DIR/bundle.json`
2. The patches for files in its scope (or file paths for large PRs)
3. Its persona prompt from `references/agent-prompts.md`
4. The path to write its findings: `$RUN_DIR/findings/{agent-name}.json`
5. The **Verification Gate** (see below)
6. A rigid OUTPUT FORMAT (structured JSON, one finding per object)

### Verification Gate (required in every agent prompt)

Every **Critical** or **Major** finding must include at least one:

1. **Concrete repro** — input that triggers the bug (curl, function call, sequence)
2. **Code-path trace** — entry → fault site, with `file:line` for each step
3. **Upstream-source citation** — for library/version/API claims, quote the changelog/docs/source

Findings that can't satisfy the gate → demoted to Minor or moved to **Unverified Suspicions**.

### Specialist roster

Fire these as parallel `Agent` calls in a single response:

| # | Agent | When | Output path | Persona file |
|---|---|---|---|---|
| 1 | **Bugs/Correctness** | always | `$RUN_DIR/findings/bugs.json` | `references/agent-prompts.md#bugs` |
| 2 | **Security (OWASP+CWE)** | always | `$RUN_DIR/findings/security.json` | `references/agent-prompts.md#security` |
| 3 | **Performance** | if backend bucket non-empty | `$RUN_DIR/findings/performance.json` | `references/agent-prompts.md#performance` |
| 4 | **UX/Accessibility** | if frontend bucket non-empty | `$RUN_DIR/findings/ux.json` | `references/agent-prompts.md#ux` |
| 5 | **Adversarial/Edge-cases** | always | `$RUN_DIR/findings/adversarial.json` | `references/agent-prompts.md#adversarial` |
| 6 | **Code Smell + Backward Compat** | always | `$RUN_DIR/findings/codesmell.json` | `references/agent-prompts.md#codesmell` |
| 7 | **DX / Extensibility** | always | `$RUN_DIR/findings/dx.json` | `references/agent-prompts.md#dx` |

Read `references/agent-prompts.md` once, then for each spawned agent inline the relevant persona section into its prompt. Each agent runs in its own context — they see only what you put in the prompt.

### UX agent: Playwright screenshot capture (special)

After the UX agent returns its findings JSON (which includes an `affected_routes` field listing the page paths it identified from the diff), capture screenshots at 3 viewports. This happens BEFORE Phase 2 verify so verify agents can `Read` the screenshots.

**Trigger**: `PREVIEW_URL` from Step 0.4 is non-empty AND `ux.json` exists AND `ux.json` has `affected_routes` entries.

**Action**: Use the `playwright` skill (load it via the `skill` tool) to drive a real browser. For each combination of route × viewport:

```
Route paths from UX agent: ["/checkout", "/dashboard"]
Viewports: mobile=375x667, tablet=768x1024, desktop=1440x900

For each (route, viewport):
  1. Resize browser: browser_resize(width, height)
  2. Navigate: browser_navigate("${PREVIEW_URL}${route}")
  3. Wait for load: browser_wait_for(text="some stable element") OR time-based
  4. Screenshot: browser_take_screenshot(filename="$RUN_DIR/screenshots/{route-slug}-{viewport}.png", fullPage=true)
  5. Capture console: browser_console_messages(level="error")
```

Where `{route-slug}` is the route with `/` → `-` (e.g. `/checkout/cart` → `checkout-cart`).

Save the screenshot inventory to `$RUN_DIR/screenshots/manifest.json`:

```json
{
  "preview_url": "https://...",
  "captures": [
    {"route": "/checkout", "viewport": "mobile", "path": "...", "console_errors": []}
  ]
}
```

If Playwright fails for a route (404, navigation error, timeout): log to `$RUN_DIR/heal.log` and continue with remaining routes. **Don't abort the whole review for one bad route.**

**If `PREVIEW_URL` is empty**: Skip this step entirely. Log to `heal.log`:

```
[timestamp] ux-screenshots: no preview URL detected; skipping Playwright capture. UX findings will not have visual evidence attached.
```

### Output contract per agent

Every agent returns a JSON array of finding objects (and only that — no prose preamble) written to its assigned output path. UX agent's output additionally includes an `affected_routes` field at the top level:

```json
{
  "affected_routes": ["/checkout", "/dashboard"],
  "findings": [
    {
      "severity": "Critical | Major | Minor | Trivial | Info",
      "type": "potential_issue | refactor | nitpick",
      "category": "bug | security | performance | ux | adversarial | codesmell | backcompat | dx",
      "cwe": "CWE-89",
      "file": "src/auth.ts",
      "line_start": 42,
      "line_end": 48,
      "title": "SQL injection in login query",
      "description": "Concrete one-paragraph description.",
      "impact": "What an attacker / failing system gains.",
      "recommendation": "Minimal fix — don't rewrite the function.",
      "evidence_type": "repro | code-trace | upstream-source | reasoning",
      "receipts": "Literal command/quote/file:line trace",
      "code_snippet": "Optional: the offending lines",
      "screenshot_paths": ["$RUN_DIR/screenshots/checkout-mobile.png"]
    }
  ]
}
```

Non-UX agents return just `[finding, ...]` (no `affected_routes` wrapper). The orchestrator normalizes shapes when merging.

`cwe` is required for `category: security` Critical/Major findings, omitted otherwise.
`screenshot_paths` is only set on UX findings, after Playwright capture.

### Handle agent failures (self-healing for agent output)

If an agent fails, times out, or returns malformed JSON:

1. Save raw output to `$RUN_DIR/findings/{agent-name}.raw.txt`
2. Re-prompt that agent ONCE with stricter format instructions
3. If still bad on retry: drop, log to `$RUN_DIR/heal.log`, note in verdict ("agent X failed twice — reduced confidence")
4. Continue with remaining agents

Single-attempt retry only — no infinite loops.

---

## Phase 2: Verify (parallel)

For every Phase 1 finding, spawn a **fresh verify-agent** in parallel. The verify-agent's context is clean (no fan-out contamination). Each one gets exactly one finding and the local code, and answers a single question: **does this finding reproduce against the actual code?**

For **UX findings with `screenshot_paths`**, the verify agent is also given the screenshot files to `Read` — visual evidence trumps prose claims.

### Verify-agent prompt template

> You are a verification agent. You receive ONE candidate finding from a PR review. Your job is to confirm or reject it against the actual code (and screenshots, for UX findings). You are SPECIFIC — you only confirm what's actually broken. Default to rejection unless evidence is clear.
>
> **CANDIDATE FINDING:**
> [the single JSON finding object]
>
> **SCREENSHOTS** (if any from `screenshot_paths`):
> Use the Read tool to inspect each path. Visual problems visible in screenshots are strong evidence.
>
> **YOUR TASK:**
> 1. Read the file at `file:line_start-line_end` and 30 lines of context above/below.
> 2. For code-path claims: trace via `grep`/`Read` from the entry point to the fault site. Cite every function in the chain.
> 3. For library/version claims: read the actual source (e.g., `node_modules/<lib>/...`, `~/go/pkg/mod/...`) or quote the changelog.
> 4. For security/bug claims: construct a literal repro input if possible.
> 5. For UX claims with screenshots: confirm the visual issue is actually present in the captures.
> 6. Look for upstream validation/guards that may already prevent the bug.
>
> **OUTPUT (JSON only, written to `$RUN_DIR/findings/verify/{finding-id}.json`):**
> ```json
> {
>   "finding_id": "...",
>   "verdict": "confirmed | partial | rejected",
>   "confidence": 0.0-1.0,
>   "reasoning": "One paragraph. Cite file:line for every claim.",
>   "adjusted_severity": "Critical | Major | Minor | Trivial | Info | null"
> }
> ```

### Verify outcomes

| verdict | confidence | action |
|---|---|---|
| confirmed | ≥0.8 | keep finding at original (or adjusted) severity, tag `verified:true` |
| partial | 0.5–0.8 | demote one tier (Critical→Major, Major→Minor, …), tag `verified:partial` |
| rejected | <0.5 | remove from main findings, append to `unverified_suspicions` with the verify-agent's reasoning |

**Never silently drop rejected findings.** A smart suspicion the author can investigate is still useful signal.

---

## Phase 3: Dedupe & Reference Follow-through

This is YOUR work (orchestrator), not an agent's.

### Dedupe

1. Read all `$RUN_DIR/findings/*.json` and merge into one array.
2. Group findings by `(file, line_start..line_end)` with ±3 line tolerance for overlap.
3. When 2+ findings overlap, merge: keep highest severity, merge titles, concat `category` fields, preserve all `receipts`, union `screenshot_paths`.
4. Note merge in finding metadata: `merged_from: [agent_names]`.

### Reference follow-through

For each surviving **Critical** or **Major** finding, briefly trace usage to confirm impact scope:

```bash
grep -rn "functionName" src/ --include="*.ts" | head -20
```

Update each finding with a `usage_count` field. If `usage_count == 0` for an internal helper, demote severity by one tier (low blast radius).

---

## Phase 4: Severity Ranking & Categorization

Adopt the **CodeRabbit 5-tier scale** (full definitions in `references/severity-scale.md`).

| Severity | Emoji | Definition | Blocks merge? |
|---|---|---|---|
| Critical | 🔴 | System failure, security breach, data loss | Yes |
| Major | 🟠 | Significant functionality/perf impact | Yes |
| Minor | 🟡 | Should fix, not blocking | No |
| Trivial | 🔵 | Code quality improvement | No |
| Info | ⚪ | Context/awareness | No |

Sort the final list: severity (Critical first) → category (security/bug first) → file path.

---

## Phase 5: Synthesize & Output

Determine verdict:

| Verdict | Criterion |
|---|---|
| 🚫 **NEEDS_CHANGES** | any verified Critical, or ≥3 verified Major |
| 💬 **DISCUSS** | 1–2 verified Major, or Critical with low confidence |
| ✅ **LGTM** | only Minor/Trivial/Info, or no findings |

Build the final JSON at `$RUN_DIR/findings.json` matching the schema in `references/output-template.md`. Then render:

```bash
bash scripts/run-with-heal.sh "$RUN_DIR" scripts/format-output.sh "$RUN_DIR/findings.json" > "$RUN_DIR/output.md"
cat "$RUN_DIR/output.md"
```

### Include the heal log in the output

After printing the main report, check `$RUN_DIR/heal.log`. If non-empty, append:

```markdown
---

## 🔧 Self-Heal Log

During this review, the skill recovered from these conditions:

- [timestamp] load-pr.sh: GitHub returned 403 — token scope refreshed
- [timestamp] ux-screenshots: no preview URL detected; skipping Playwright capture
- ...

(Workspace preserved at `/tmp/pr-review-{id}/{timestamp}/` for inspection.)
```

This tells the user **explicitly** what was healed so they can verify the recovery was correct.

### Final user-facing summary line

After printing everything, always tell the user:

```
Workspace: $RUN_DIR
Clean up when done: rm -rf $RUN_DIR
```

### Posting back to GitHub (opt-in, default OFF)

By default the skill is **read-only** — it prints to terminal only. If the user explicitly asks "post the review" / "comment on the PR" / "leave review comments", confirm first, then:

```bash
gh pr review <N> --comment --body "$(cat "$RUN_DIR/output.md")"
```

For UX findings with screenshots: GitHub's API doesn't accept multipart uploads on PR comments directly. Recommend uploading screenshots to a gist and embedding the URLs, OR attaching via the web UI. The skill skips inline screenshot embedding unless the user explicitly asks.

NEVER post without explicit user confirmation.

---

## Self-Healing Contract

Every script invocation goes through `scripts/run-with-heal.sh`, which catches known failure classes:

| Failure | Heal action | Outcome |
|---|---|---|
| `jq` not installed | Log message instructing `brew install jq` | Abort with clear message |
| `gh` not installed | Log message instructing `brew install gh` | Abort with clear message |
| `git` not installed | Log message instructing `xcode-select --install` (macOS) | Abort with clear message |
| `gh` not authenticated for github.com | Log message instructing `gh auth login` | Abort with clear message |
| `gh api` returns 403 | Run `gh auth refresh -s repo`, retry once | Continue if scope refresh worked; else abort |
| `gh api` returns 404 | Log "PR/repo not found" | Abort with clear message |
| clone fails (network) | Log to `heal.log` with diagnostic | Abort — user re-runs after fixing network |
| `--worktree` path has uncommitted changes | Refuse to touch it | Abort with clear message |
| `--worktree` path's origin doesn't match PR | Refuse | Abort with clear message |
| `gh pr checkout` fails (deleted branch) | Auto-fallback to `git fetch origin pull/N/head` | Continues — works for ALL PRs incl. closed |
| jq compile error in our script | Save full stderr to `$RUN_DIR/raw/` | Abort — this is a bug to fix manually |
| Agent returns malformed JSON | Save raw output, re-prompt ONCE with stricter format | Drop agent if retry fails; continue with rest |
| Playwright fails to capture a route | Log to `heal.log`, continue with remaining routes | Don't abort entire review for one route |
| No preview URL detected | Log skip to `heal.log`, UX runs without screenshots | Continue normally |

**Self-heal limit: ONE attempt per failure class per script invocation.** Infinite loops are worse than abort. The orchestrator can choose to retry a different way, but the wrapper never retries beyond one heal.

**Every heal action is logged to `$RUN_DIR/heal.log` AND announced on stderr** so:

1. The user knows what was healed in the final report.
2. Future debugging can read the log for forensics.

---

## Agent rules

1. **Init the workspace first.** Always call `init-run.sh` before any other script. All subsequent paths derive from `$RUN_DIR`.
2. **All scripts go through `run-with-heal.sh`.** Never invoke `load-pr.sh` / `classify-files.sh` / etc. directly; always wrap them.
3. **Read the bundle yourself.** You need the file list and metadata to fan out intelligently. Don't delegate Phase 0.
4. **Ensure the local clone before fan-out.** For GitHub PRs, call `ensure-clone.sh` so agents can `Read`/`Grep` locally. Embed `$CLONE_PATH` in every specialist's prompt as `local_clone_path`.
5. **Honor `--worktree` if user provided one.** Don't clone to `/tmp` if they already have a checkout.
6. **Fire Phase 1 in parallel.** All applicable specialists in ONE response. Sequential = wasted turn.
7. **UX agent runs first to identify routes**, then Playwright captures, then verify pass. Don't try to capture before the UX agent reports `affected_routes`.
8. **Phase 2 verify is non-negotiable.** Without it, fan-out is noise.
9. **Never relaunch failed agents more than once.** Note the gap, lower confidence, move on.
10. **Phase 3 and onward are YOUR work.** No more agents after verify.
11. **Verdict counts verified findings only.** Unverified Suspicions never escalate the verdict.
12. **Read-only by default.** Posting to GitHub requires explicit user confirmation in the current message.
13. **Skip generated/lockfile findings.** The classifier tags them; agents ignore them.
14. **For "current changes":** treat as a synthetic PR. Skip CI checks, existing-reviews, preview-URL detection, clone, and posting features. Agents read from `$PWD`.
15. **Cite `file:line` everywhere.** When working from a local clone, output paths can be relative to the clone (clickable on the agent's machine) — but in the final review keep them PR-relative for the user.
16. **Always print the heal log section** if `$RUN_DIR/heal.log` is non-empty. The user must know what was self-healed.

---

## Anti-patterns (will produce false positives — refuse to ship)

Same 8 anti-patterns from `adversarial-review`, applied to PR review. Embed them in EVERY specialist agent's prompt (the persona file does this already).

1. **Version-claim without source-check**
2. **Code-path claim without full trace**
3. **Severity from prose, not impact**
4. **Theoretical bug without repro**
5. **"Best practice" without referent**
6. **One-sided framing**
7. **Test-coverage claims without running**
8. **Hypothetical chaining**

See `references/agent-prompts.md` for the full text. They MUST appear in every specialist agent's prompt.

---

## Quick reference

| Task | Command |
|---|---|
| Init workspace | `RUN_DIR=$(bash scripts/init-run.sh "<arg>")` |
| Load PR (with heal) | `bash scripts/run-with-heal.sh "$RUN_DIR" scripts/load-pr.sh "<arg>" > "$RUN_DIR/bundle.json"` |
| Ensure local clone | `CLONE_PATH=$(bash scripts/run-with-heal.sh "$RUN_DIR" scripts/ensure-clone.sh "$RUN_DIR/bundle.json" "<optional-worktree>")` |
| Classify files | `bash scripts/run-with-heal.sh "$RUN_DIR" scripts/classify-files.sh "$RUN_DIR/bundle.json" > "$RUN_DIR/buckets.json"` |
| Detect preview URL | `bash scripts/run-with-heal.sh "$RUN_DIR" scripts/detect-preview-url.sh "$RUN_DIR/bundle.json"` |
| Get PR diff | `gh pr diff <N>` |
| Get per-file patches | `gh api repos/{o}/{r}/pulls/{N}/files --paginate` |
| Manual checkout | `gh pr checkout <N>` (only if `ensure-clone.sh` skipped or you want CWD) |
| Render final output | `bash scripts/run-with-heal.sh "$RUN_DIR" scripts/format-output.sh "$RUN_DIR/findings.json"` |
| Post review (opt-in) | `gh pr review <N> --comment --body "$(cat "$RUN_DIR/output.md")"` |
| Heal log | `cat "$RUN_DIR/heal.log"` |
| List active clones | `ls /tmp/pr-review-clones/` |
| Clean up clone cache | `rm -rf /tmp/pr-review-clones/{owner}-{repo}-{number}` |

## Error handling

Most error handling is now in `run-with-heal.sh`. This table covers what the orchestrator should do for failures that propagate past the heal layer.

| Error | Cause | Orchestrator action |
|---|---|---|
| `init-run.sh` failed | `/tmp` not writable, jq missing | Tell user, abort |
| `load-pr.sh` aborted (404) | Wrong PR identifier | Ask user to verify |
| `load-pr.sh` aborted (auth) | gh not logged in | Tell user to run `gh auth login` |
| Empty patches array | PR has no diff (merge commit only) | Tell user; nothing to review |
| Specialist agent timed out | Slow API or bad prompt | Skip that specialist, note in verdict |
| Verify agent failed for all findings | Likely context mismatch | Spot-check 2-3 manually, demote confidence |
| Playwright skill unavailable | playwright skill / MCP not installed | Log to heal.log, UX runs without screenshots |
| All routes failed to load | Bad preview URL, auth required | Log per-route, continue with text-only UX findings |
