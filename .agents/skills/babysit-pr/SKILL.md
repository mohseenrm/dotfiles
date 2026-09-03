---
name: babysit-pr
description: Babysit a GitHub pull request after creation by continuously polling review comments (bot and human), CI checks/workflow runs, and mergeability state until the PR is merged/closed or user help is required. Diagnose failures, retry likely flaky failures up to 3 times, investigate every review comment and patch when changes are warranted, self-review each fix with /adversarial-reviewer until nothing above LOW is flagged, then commit, rebase on the base branch, and push. Use when the user asks to monitor a PR, watch CI, handle review comments, or keep an eye on failures and feedback on an open PR.
---

# PR Babysitter

## Objective
Babysit a PR persistently until one of these terminal outcomes occurs:

- The PR is merged or closed.
- A situation requires user help (for example CI infrastructure issues, repeated flaky failures after retry budget is exhausted, permission problems, or ambiguity that cannot be resolved safely).
- Optional handoff milestone: the PR is currently green + mergeable + review-clean. Treat this as a progress state, not a watcher stop, so late-arriving review comments are still surfaced promptly while the PR remains open.

Do not stop merely because a single snapshot returns `idle` while checks are still pending.

## Inputs
Accept any of the following:

- No PR argument: infer the PR from the current branch (`--pr auto`)
- PR number
- PR URL

## Core Workflow

1. When the user asks to "monitor"/"watch"/"babysit" a PR, start with the watcher's continuous mode (`--watch`) unless you are intentionally doing a one-shot diagnostic snapshot.
2. Run the watcher script to snapshot PR/review/CI state (or consume each streamed snapshot from `--watch`).
3. Inspect the `actions` list in the JSON response.
4. If `diagnose_ci_failure` is present, inspect failed run logs and classify the failure.
5. If the failure is likely caused by the current branch, patch code locally, then run the same fix pipeline used for review comments (patch → verify → `/adversarial-reviewer` until nothing above LOW → commit → rebase → push). Do not patch random flaky tests, CI infrastructure, dependency outages, runner issues, or other failures that are unrelated to the branch.
6. If `process_review_comment` is present, investigate every surfaced published review item (bot or human) per "Investigate every surfaced comment" below, and decide whether changes are needed.
7. If a review item is valid and actionable, run the full fix pipeline: patch → verify → `/adversarial-reviewer` until nothing above LOW is flagged → commit → rebase on the base branch → push. Then resolve the associated review thread only when allowed by the GitHub state mutation policy below.
8. Do not post replies to human-authored review comments/threads unless the user explicitly confirms the exact response. If a human review item is non-actionable, already addressed, or not valid, surface the item and a fully formatted recommended response (see "Response Formatting") to the user instead of replying on GitHub.
9. If the failure is likely flaky/unrelated and `retry_failed_checks` is present, rerun failed jobs with `--retry-failed-now`.
10. If both actionable review feedback and `retry_failed_checks` are present, prioritize review feedback first; a new commit will retrigger CI, so avoid rerunning flaky checks on the old SHA unless you intentionally defer the review change.
11. On every loop, look for newly surfaced review feedback before acting on CI failures or mergeability state, then verify mergeability / merge-conflict status (for example via `gh pr view`) alongside CI.
12. After any push or rerun action, immediately return to step 1 and continue polling on the updated SHA/state.
13. If you had been using `--watch` before pausing to patch/commit/push, relaunch `--watch` yourself in the same turn immediately after the push (do not wait for the user to re-invoke the skill).
14. Repeat polling until `stop_pr_closed` appears or a user-help-required blocker is reached. A green + review-clean + mergeable PR is a progress milestone, not a reason to stop the watcher while the PR is still open.
15. Maintain terminal/session ownership: while babysitting is active, keep consuming watcher output in the same turn; do not leave a detached `--watch` process running and then end the turn as if monitoring were complete.

## Commands

### One-shot snapshot

```bash
python3 ~/.claude/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --once
```

### Continuous watch (JSONL)

```bash
python3 ~/.claude/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --watch
```

### Trigger flaky retry cycle (only when watcher indicates)

```bash
python3 ~/.claude/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --retry-failed-now
```

### Explicit PR target

```bash
python3 ~/.claude/skills/babysit-pr/scripts/gh_pr_watch.py --pr <number-or-url> --once
```

### Surface every bot's review feedback

Use when the repo's review bot is not in the known-review-bot keyword list and its comments are not
being surfaced. Still filters out non-review bots (dependabot, renovate, deploy previews).

```bash
python3 ~/.claude/skills/babysit-pr/scripts/gh_pr_watch.py --pr auto --watch --all-bots
```

## CI Failure Classification
Use `gh` commands to inspect failed runs before deciding to rerun.

- `gh run view <run-id> --json jobs,name,workflowName,conclusion,status,url,headSha`
- `gh api repos/<owner>/<repo>/actions/runs/<run-id>/jobs -X GET -f per_page=100`
- `gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs > /tmp/gh-job-<job-id>-logs.zip`
- `gh run view <run-id> --log-failed` as a fallback after the overall workflow run is complete

`gh run view --log-failed` is workflow-run scoped and may not expose failed-job logs until the overall run finishes. For faster diagnosis, poll the run's jobs first and, as soon as a specific job has failed, fetch that job's logs directly from the Actions job logs endpoint. The watcher includes a `failed_jobs` list with each failed job's `job_id` and `logs_endpoint` when GitHub exposes one.

Prefer treating failures as branch-related when failed-job logs point to changed code (compile/test/lint/typecheck/snapshots/static analysis in touched areas).

Prefer treating failures as flaky/unrelated when logs show transient infra/external issues (timeouts, runner provisioning failures, registry/network outages, GitHub Actions infra errors).

Do not attempt to fix flaky/unrelated failures by changing tests, build scripts, CI configuration, dependency pins, or infrastructure-adjacent code unless the logs clearly connect the failure to the PR branch. For flaky/unrelated failures, rerun only when the watcher recommends `retry_failed_checks`; otherwise wait or stop for user help.

If classification is ambiguous, perform one manual diagnosis attempt before choosing rerun.

Read `~/.claude/skills/babysit-pr/references/heuristics.md` for a concise checklist.

## Review Comment Handling
The watcher surfaces review items from:

- PR issue comments
- Inline review comments
- Review submissions (COMMENT / APPROVED / CHANGES_REQUESTED)

Only act on published feedback. Ignore review submissions in GitHub's `PENDING` state and inline
comments attached to those pending reviews. Do not mark pending review feedback as seen; it should
be eligible to surface after the reviewer submits the review.

Watch for review feedback from **both bots and humans**. Bot review feedback is first-class input, not
noise: the watcher surfaces known review bots by login keyword (Codex, Claude, Copilot, CodeRabbit,
Cursor, Graphite, Greptile, Sonar, Codecov, DeepSource, Snyk, Sourcery, Ellipsis, Korbit, Qodo,
BugBot, and generic `*review*`/`*lint*` logins). Non-review bots (dependabot, renovate, deploy-preview
bots like Netlify/Vercel/ArgoCD, changelog/release bots) are filtered out. Pass `--all-bots` to surface
every bot except that deny list when a repo uses a review bot the keyword list does not know.
For safety, the watcher only auto-surfaces trusted human review authors (repo OWNER/MEMBER/COLLABORATOR,
plus the authenticated operator) and the review bots above.
On a fresh watcher state file, existing unaddressed published review feedback may be surfaced immediately (not only comments that arrive after monitoring starts). This is intentional so already-open review comments are not missed.

### Investigate every surfaced comment

Never dismiss a comment without reading the code it points at. For each surfaced item, run this
triage before deciding anything:

1. Read the comment in full, including any suggested diff and the surrounding thread.
2. Open the referenced file(s) at the referenced lines. Read enough context to judge the claim, not
   just the flagged line.
3. Reproduce the claim where cheap: run the relevant test, type-check, linter, or a focused script.
4. Classify the item:
   - **Valid + actionable** - the comment is correct and the fix belongs in this branch. Proceed to
     the pipeline below.
   - **Valid but out of scope** - correct, but the fix belongs in a separate change. Surface to the
     user with a recommendation; do not patch.
   - **Already addressed** - a later commit already fixed it. Note the commit SHA and surface it.
   - **Incorrect** - the comment is wrong. Ground the rebuttal in the code you just read (quote
     file:line), then surface it to the user. Do not reply on GitHub without confirmation.
   - **Ambiguous** - needs reviewer clarification. Surface with a proposed question.

Bot comments get the same investigation as human ones, and the same skepticism: bots produce
confident false positives. A bot claim you cannot reproduce is an **Incorrect** item, not a mandate
to change code. Do not patch code just to silence a bot.

### Fix pipeline for review comments

Apply this pipeline to every change made to address review feedback. Batch related comments into one
pass when they touch the same area; otherwise handle them one item at a time.

1. **Patch** code locally on the PR head branch, smallest correct change that addresses the comment.
2. **Verify** the fix: run the tests/lint/typecheck that cover the touched code. If a check fails,
   fix it before continuing. Never skip verification because the change "looks obvious".
3. **Self-review with `/adversarial-reviewer`** on the pending changes (see below). Loop until the
   review returns nothing above LOW severity.
4. **Commit** the change (see commit message defaults).
5. **Rebase** onto the current base branch (see the Rebase section).
6. **Push** to the PR head branch.
7. **Resolve** the associated GitHub review thread only when allowed by the GitHub state mutation
   policy below.
8. **Resume watching** on the new SHA immediately. Do not stop after reporting the push. If
   monitoring was running in `--watch` mode, restart `--watch` in the same turn without waiting for
   the user to ask again.

### Adversarial self-review gate

Before committing any review-comment fix, review it with the `adversarial-reviewer` skill and iterate
until it is clean:

1. Invoke `/adversarial-reviewer` with **no `post` argument** so findings stay in the conversation.
   Posting the self-review to the PR would spam reviewers; never pass `post` from this skill.
2. Scope the review to the pending change (the uncommitted diff plus any commits added this
   babysitting session), not the whole PR.
3. Read the findings. The gate is: **no finding at 🚨 CRITICAL, 🔴 HIGH, or 🟡 MEDIUM severity.**
   ⚪ LOW findings and "No bugs found" both pass.
4. If anything above LOW is flagged: fix it, re-run verification (step 2 of the pipeline), and review
   again. Each iteration reviews the updated diff.
5. Cap the loop at **3 iterations**. If findings above LOW persist after the third pass, stop, do not
   push, and surface to the user: the original review comment, what you changed, and the findings
   that will not clear. This is a user-help-required blocker.
6. If a finding is a false positive, say so explicitly with the file:line evidence that refutes it,
   and treat the gate as passed for that finding rather than contorting the code around it. Do not
   suppress findings by deleting tests, loosening types, or adding `@ts-ignore`/`as any`.
7. Findings in code the fix did not touch are out of scope for this gate. Note them for the user and
   do not block the push on them.

Record for the final summary how many adversarial iterations each fix needed and what was flagged.

### Rebase before push

Review-comment fixes land on a branch that other commits may have moved past, so rebase before
pushing rather than merging the base branch in.

1. Confirm the worktree is clean (the fix is committed) before rebasing.
2. Fetch and rebase onto the PR's base branch:
   ```bash
   BASE=$(gh pr view <number> --json baseRefName --jq .baseRefName)
   git fetch origin "$BASE"
   git rebase "origin/$BASE"
   ```
3. If the rebase is clean, re-run the verification commands from pipeline step 2 (a clean rebase can
   still break the build) and then push.
4. Push the rebased branch with a lease, never a bare force:
   ```bash
   git push --force-with-lease
   ```
   `--force-with-lease` is required after a rebase and is the only force push allowed here. If it is
   rejected, someone else pushed to the branch: fetch, inspect, and stop for user help rather than
   escalating to `--force`.
5. If the rebase hits conflicts you cannot resolve with high confidence from the PR's own changes,
   run `git rebase --abort`, leave the branch as it was, and surface the conflict to the user. Do not
   guess at conflict resolutions in code you did not write.
6. If the branch is already up to date with the base, skip the rebase and push normally.
7. If the repo or user prefers merge commits over rebasing the PR branch, follow that preference and
   note it; ask the user first if the branch is shared with other authors.

Do not post replies to human-authored GitHub review comments/threads automatically. If you disagree with a human comment, believe it is non-actionable/already addressed, or need to answer a question, report the item to the user with a suggested response and wait for explicit confirmation before posting anything on GitHub. If the user approves a response, prefix it with `[claude]` so it is clear the response is automated and not from the human user.
If the watcher later surfaces your own approved reply because the authenticated operator is treated as a trusted review author, treat that self-authored item as already handled and do not reply again.
If a code review comment/thread is already marked as resolved in GitHub, treat it as non-actionable and safely ignore it unless new unresolved follow-up feedback appears.

## Response Formatting

Every response to a review comment - whether posted to GitHub after approval, or surfaced to the user
as a proposed reply - must be styled, formatted, and syntax-highlighted GitHub-flavored Markdown. A
wall of unformatted prose is not an acceptable reply.

### Required structure

Lead with a status line, then the explanation, then evidence. Keep it tight: a reply is a few lines
plus a code block, not an essay.

````markdown
**✅ Fixed** in `a1b2c3d`

`src/parser.ts:42` was slicing before the bounds check, so a single-element input read past the end.

```ts
- const rest = items.slice(1, items.length - 1);
+ const rest = items.length > 1 ? items.slice(1, items.length - 1) : [];
```

Covered by `parser.test.ts:118` (`handles single-element input`).
````

### Status badges

Open every reply with one of these, bolded:

| Badge | Use when |
|-------|----------|
| **✅ Fixed** | Patched in a commit. Always cite the short SHA. |
| **🔀 Refactored** | Addressed differently than suggested. Say why. |
| **✅ Already handled** | A prior commit covers it. Cite that SHA. |
| **💬 Disagree** | The comment is incorrect. Cite the code that refutes it. |
| **❓ Clarification needed** | Ambiguous request. Ask one specific question. |
| **📋 Follow-up** | Valid but out of scope. Link the issue if one exists. |
| **⏭️ Won't fix** | Deliberate. State the reason. |

### Formatting rules

- **Syntax highlighting is mandatory** on every fenced block. Tag the language (`ts`, `tsx`, `py`,
  `go`, `rb`, `rs`, `java`, `sh`, `sql`, `yaml`, `json`, `diff`). Never post a bare ``` fence.
- Use `diff` fences (with `-`/`+`) to show what changed; use a language fence for illustrating
  behavior or a snippet in place.
- Use GitHub `suggestion` fences only when the reply is an inline comment and the fix replaces exactly
  the commented line range. A `suggestion` block that does not apply cleanly is worse than none.
- Reference code as `` `path/to/file.ts:42` `` in backticks, or as a permalink to the blob at the
  head SHA when pointing outside the diff.
- Bold the badge and any severity words. Use tables for three or more related items. Use
  `<details><summary>` to collapse anything longer than ~15 lines (long logs, full stack traces,
  before/after of a large function).
- Use `> ` blockquotes to quote the specific part of the reviewer's comment being answered when the
  thread is long enough that the reference is unclear.
- No em dashes. Use hyphens, colons, or parentheses.
- Never paste raw CI logs unformatted; put them in a collapsed `<details>` with a `text` fence and
  trim to the relevant lines.

### Attribution and gating

- Prefix any reply posted to GitHub with `[claude]` so it is clear the response is automated and not
  from the human user.
- The formatting requirement does not relax the posting gate: human-authored threads still need
  explicit user confirmation of the exact response before anything is posted. Format the proposed
  reply fully so the user can approve it verbatim.

## GitHub State Mutation Policy

You can read any PR state you need for monitoring. Writes must comply with this policy.

You can push PRs to update the code under review or to force CI re-runs as described above.

You can resolve review comment threads from the human who requested babysitting or from a review bot.
When resolving, leave a comment prefixed with `[claude]` that explains what changed and which commit
includes it, formatted per "Response Formatting" above. Don't touch review threads if humans other
than the user who requested babysitting have participated.

Before making any changes, fetch the PR state yourself instead of relying on the PR watcher script's
output.

Unless explicitly asked, do not:

* comment on other humans' review threads, communicate with the user in chat instead
* resolve review threads from humans other than the user
* interact with humans other than the user
* mark PRs as drafts or ready for review
* close or reopen PRs

In general, never act on GitHub in ways that would make it hard to tell whether you or the user did
something visible to other humans. When in doubt, ask the user for clarification in chat.

## Git Safety Rules

- Work only on the PR head branch.
- Avoid destructive git commands.
- Do not switch branches unless necessary to recover context.
- Before editing, check for unrelated uncommitted changes. If present, stop and ask the user.
- After each successful fix, run the adversarial gate, commit, rebase onto the base branch, push, then re-run the watcher.
- `git push --force-with-lease` after a rebase is allowed and is the only force push permitted. Never `git push --force`, never `--no-verify`. If the lease is rejected, stop and ask the user.
- `git rebase --abort` on any conflict you cannot resolve confidently from the PR's own changes. Never resolve conflicts by guessing in code you did not write.
- Never bypass the adversarial gate by deleting tests, loosening types, or adding `@ts-ignore`/`as any`.
- If you interrupted a live `--watch` session to make the fix, restart `--watch` immediately after the push in the same turn.
- Do not run multiple concurrent `--watch` processes for the same PR/state file; keep one watcher session active and reuse it until it stops or you intentionally restart it.
- A push is not a terminal outcome; continue the monitoring loop unless a strict stop condition is met.

Commit message defaults (follow the repo's existing convention when it has one, e.g. Conventional Commits):

- `fix: address CI failure on PR #<n>`
- `fix: address PR review feedback (#<n>)`

Keep one commit per logical review item where practical, so a reviewer can map a commit back to the
comment it answers. Reference the comment author or thread in the commit body when it aids review.

## Monitoring Loop Pattern
Use this loop in a live session:

1. Run `--once`.
2. Read `actions`.
3. First check whether the PR is now merged or otherwise closed; if so, report that terminal state and stop polling immediately.
4. Check CI summary, new review items, and mergeability/conflict status.
5. Diagnose CI failures and classify branch-related vs flaky/unrelated. If the overall run is still pending but `failed_jobs` already includes a failed job, fetch that job's logs and diagnose immediately instead of waiting for the whole workflow run to finish. Patch only when the failure is branch-related.
6. For each surfaced review item from another author (bot or human), investigate it against the actual code first. If it is valid and actionable, run the fix pipeline (patch → verify → `/adversarial-reviewer` until nothing above LOW → commit → rebase → push), then resolve it only when allowed by the GitHub state mutation policy above. If it is non-actionable, already addressed, incorrect, or requires a written answer, surface it to the user with a formatted suggested response instead of posting automatically. If a later snapshot surfaces your own approved reply, treat it as informational and continue without responding again.
7. Process actionable review comments before flaky reruns when both are present; if a review fix requires a commit, push it and skip rerunning failed checks on the old SHA.
8. Retry failed checks only when `retry_failed_checks` is present and you are not about to replace the current SHA with a review/CI fix commit. Do not make code changes for unrelated flakes or infrastructure failures just to get CI green.
9. If you pushed a commit, resolved an eligible review thread, or triggered a rerun, report the action briefly and continue polling (do not stop). If a human review comment needs a written GitHub response, stop and ask for confirmation before posting.
10. After a review-fix push, proactively restart continuous monitoring (`--watch`) in the same turn unless a strict stop condition has already been reached.
11. If everything is passing, mergeable, not blocked on required review approval, and there are no unaddressed review items, report that the PR is currently ready to merge but keep the watcher running so new review comments are surfaced quickly while the PR remains open.
12. If blocked on a user-help-required issue (infra outage, exhausted flaky retries, unclear reviewer request, permissions), report the blocker and stop.
13. Otherwise sleep according to the polling cadence below and repeat.

When the user explicitly asks to monitor/watch/babysit a PR, prefer `--watch` so polling continues autonomously in one command. Use repeated `--once` snapshots only for debugging, local testing, or when the user explicitly asks for a one-shot check.
Do not stop to ask the user whether to continue polling; continue autonomously until a strict stop condition is met or the user explicitly interrupts.
Do not hand control back to the user after a review-fix push just because a new SHA was created; restarting the watcher and re-entering the poll loop is part of the same babysitting task.
If a `--watch` process is still running and no strict stop condition has been reached, the babysitting task is still in progress; keep streaming/consuming watcher output instead of ending the turn.

## Polling Cadence
Keep review polling aggressive and continue monitoring even after CI turns green:

- While CI is not green (pending/running/queued or failing): poll every 1 minute.
- After CI turns green: keep polling at the base cadence while the PR remains open so newly posted review comments are surfaced promptly instead of waiting on a long green-state backoff.
- Reset the cadence immediately whenever anything changes (new commit/SHA, check status changes, new review comments, mergeability changes, review decision changes).
- If CI stops being green again (new commit, rerun, or regression): stay on the base polling cadence.
- If any poll shows the PR is merged or otherwise closed: stop polling immediately and report the terminal state.

## Stop Conditions (Strict)
Stop only when one of the following is true:

- PR merged or closed (stop as soon as a poll/snapshot confirms this).
- User intervention is required and you cannot safely proceed alone. This includes: the adversarial
  gate still flags findings above LOW after 3 iterations, a rebase conflict you cannot resolve
  confidently, or a `--force-with-lease` rejection.

Keep polling when:

- `actions` contains only `idle` but checks are still pending.
- CI is still running/queued.
- Review state is quiet but CI is not terminal.
- CI is green but mergeability is unknown/pending.
- CI is green and mergeable, but the PR is still open and you are waiting for possible new review comments or merge-conflict changes.
- The PR is green but blocked on review approval (`REVIEW_REQUIRED` / similar); continue polling at the base cadence and surface any new review comments without asking for confirmation to keep watching.

## Output Expectations
Provide concise progress updates while monitoring and a final summary that includes:

- During long unchanged monitoring periods, avoid emitting a full update on every poll; summarize only status changes plus occasional heartbeat updates.
- Treat push confirmations, intermediate CI snapshots, ready-to-merge snapshots, and review-action updates as progress updates only; do not emit the final summary or end the babysitting session unless a strict stop condition is met.
- A user request to "monitor" is not satisfied by a couple of sample polls; remain in the loop until a strict stop condition or an explicit user interruption.
- A review-fix commit + push is not a completion event; immediately resume live monitoring (`--watch`) in the same turn and continue reporting progress updates.
- Report the adversarial gate result for each fix as a progress update: iterations used and what was flagged. Example: `Fix for CodeRabbit comment on parser.ts: 2 adversarial passes (1 HIGH off-by-one caught and fixed), clean on pass 2, rebased on main, pushed 4f2a91c.`
- Never claim a fix is clean without having actually run `/adversarial-reviewer` on it. If the gate was skipped, say so.
- When CI first transitions to all green for the current SHA, emit a one-time celebratory progress update (do not repeat it on every green poll). Preferred style: `🚀 CI is all green! 33/33 passed. Still on watch for review approval.`
- Do not send the final summary while a watcher terminal is still running unless the watcher has emitted/confirmed a strict stop condition; otherwise continue with progress updates.

- Final PR SHA
- CI status summary
- Mergeability / conflict status
- Fixes pushed, each mapped to the review comment (and author) it addresses
- Adversarial gate results per fix: iterations used, findings caught and fixed, any accepted LOW findings
- Rebases performed, and any conflicts resolved
- Flaky retry cycles used
- Review comments investigated but not patched, with the classification (already handled / incorrect / out of scope / needs clarification) and the formatted reply awaiting user approval
- Remaining unresolved failures or review comments

## References

- Heuristics and decision tree: `~/.claude/skills/babysit-pr/references/heuristics.md`
- GitHub CLI/API details used by the watcher: `~/.claude/skills/babysit-pr/references/github-api-notes.md`
