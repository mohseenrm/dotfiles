---
name: pr-self-review
description: Review and fix YOUR OWN work - a pull request or a not-yet-PR branch. With an open PR, reads everything already posted (CodeRabbit and human comments, checkbox review bodies, failing CI checks), runs its own subagent review when the PR has no feedback yet, folds in a background CodeRabbit CLI pass (never blocks on it), validates each item against the actual code with parallel subagents (real vs false positive vs already fixed), fixes only the confirmed ones, commits, and pushes. With no PR yet, reviews the branch diff against the default branch through the same pipeline and fixes confirmed issues in place, so the draft PR opens clean. Stacked PRs (base branch is another open PR) are detected automatically and hand off to /pr-self-review-stack. NEVER posts anything to GitHub. Triggers on "review my PR", "self review my PR", "check feedback on my draft PR", "address the coderabbit comments", "fix PR feedback", "review my branch", "review my changes before I open a PR", "pre-PR review".
---

# PR Self-Review (review and fix your own work)

**EXECUTE THIS COMMAND IMMEDIATELY** - Do not explain what this command does. Execute the workflow below right now.

Two modes, one pipeline:

- **Feedback mode** (an open PR exists): collect every piece of feedback already sitting on
  the PR, verify each item against the real code with parallel subagents, fix what is
  actually wrong, and push. The output on GitHub is **only new commits** - never comments.
- **Pre-PR mode** (no PR yet): generate the findings yourself by reviewing the branch diff,
  then run them through the same verification-and-fix pipeline, so the draft PR opens clean.

**⛔ HARD RULES - read before doing anything:**

1. **NEVER write to GitHub except `git push`.** No `gh pr comment`, no `gh pr review`, no
   replying to threads, no resolving threads, no reactions, no editing the PR body. The
   GraphQL query in Step 1 is the ONLY permitted `gh api graphql` call - never send a
   `mutation`. The engineer handles all GitHub communication themselves.
2. **Never fix an unverified finding.** Every feedback item goes through the validation gate
   (Step 3) first. Reviewers - human and bot - are frequently wrong or stale.
3. **Never silently ignore a human.** A human comment that fails validation becomes a
   `NEEDS_HUMAN` item in the final report with a suggested reply - it is the author's call,
   not yours.
4. **Never block on any single tool.** The CodeRabbit CLI is one source in the arsenal:
   kick it off in the background, merge its findings if and when they arrive, and proceed
   regardless. When there is no external feedback to triage, YOU review the code - the
   subagent review pipeline is the primary engine, not a fallback.

## Step 0: Resolve the PR and repo

The request may name a PR number, a full URL, or no PR at all.

- Full URL → extract `OWNER/REPO` and the bare number `PR`.
- Bare number → `PR` as given; `OWNER/REPO` from the current checkout
  (`gh repo view --json nameWithOwner`).
- Empty → PR for the current branch (`OWNER/REPO` from the current checkout):

```bash
PR=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
```

If `PR` is empty, there is no open PR for this branch (`gh pr list` only finds open PRs).
That is not an error - switch to **Pre-PR mode** (see the section after Step 6) and skip
the rest of Step 0 and Step 1. If the user gave an explicit PR number/URL that doesn't
resolve, stop and say so instead.

Shell state does not persist between commands: wherever a command below shows `$PR`,
`$OWNER`, or `$REPO`, substitute the literal values. Pass `-R "$OWNER/$REPO"` on every
`gh pr` command so a bare number can never hit a same-numbered PR in the wrong repo, and
keep `$PR` a bare integer (the GraphQL call types it as `Int!`).

If the current checkout's `origin` does not match `$OWNER/$REPO` (explicit URL for a
different repo), locate the right checkout first - same resolution as `/pr-review`
Step 2 - or stop and ask; never run the steps below against the wrong repo.

**Stack check (before the author guard - it can reroute the whole run):** a PR whose base
branch is not the repo's default branch is part of a **stack**. Fixing one member in
isolation puts the fix on the wrong layer and leaves every branch above it pointing at a
stale base.

```bash
gh pr view "$PR" -R "$OWNER/$REPO" --json number,baseRefName,headRefName
gh repo view "$OWNER/$REPO" --json defaultBranchRef --jq .defaultBranchRef.name
```

A base that is not the default branch is a *hint*, not the test - a PR targeting a
long-lived release branch looks identical. More importantly, a stack's BOTTOM PR *does*
target the default branch, and that is the dangerous case here: fixing and pushing to it
leaves every branch above it on a stale base. So always check for a real chain link in both
directions:

```bash
gh pr list -R "$OWNER/$REPO" --state open --head "<baseRefName>" --json number,headRefName,headRepositoryOwner   # is my base another PR's head?
gh pr list -R "$OWNER/$REPO" --state open --base "<headRefName>" --json number,baseRefName,headRepositoryOwner   # is my head another PR's base?
```

If EITHER walk returns a PR, route to **`/pr-self-review-stack`** - it discovers the
full chain from this one PR, assigns each finding to the PR that owns it, and restacks the
branches above any branch it fixes. Say in one line that a stack was detected, then run that
command's workflow. Only count an edge when the candidate is in the SAME repository - a fork's PR can carry the
same branch name. Both walks empty means no chain - continue below, including for a PR
targeting a release branch.

**Author guard:** confirm this is your PR.

```bash
gh api user --jq .login                                              # your login
gh pr view "$PR" -R "$OWNER/$REPO" --json author,headRefName,state   # PR author, branch, state
```

If the two logins differ, stop: this command fixes your own PR. Reviewing someone else's PR
is `/pr-review`. If `state` is not `OPEN`, stop too - never push fixes to a merged
or closed PR.

**Locate the PR branch (worktree-aware):** the engineer may keep branches in linked git
worktrees. Check where the PR's `headRefName` is already checked out:

```bash
git worktree list --porcelain | grep -B2 "branch refs/heads/<headRefName>"
```

- Checked out in the **current** checkout → work here.
- Checked out in a **different** worktree → work in that worktree's path for everything
  that follows (edits, tests, commit, push). Do NOT `gh pr checkout` here - git refuses to
  check out a branch that another worktree holds.
- Checked out **nowhere** → `gh pr checkout $PR` in the current checkout.

**Before touching the branch:** check `git status --porcelain` in the chosen worktree. If
it is dirty, stop and ask - checking out or committing over uncommitted edits risks
publishing work the engineer never approved. Then make sure the branch is up to date
(`git pull --ff-only` if behind - a non-fast-forward here means a force-push or divergence,
so stop and ask rather than merging). All fixes land on this branch.

## Step 1: Gather ALL feedback (read-only)

Run these and collect results:

**PR metadata:**

```bash
gh pr view "$PR" -R "$OWNER/$REPO" --json title,body,author,headRefName,headRefOid,isDraft,url
```

**Failing CI checks** (filter on the `bucket` field - never grep the human-readable output,
where a check *named* "passthrough" would match "pass"):

```bash
gh pr checks "$PR" -R "$OWNER/$REPO" --json name,bucket,link,description \
  --jq '.[] | select(.bucket=="fail" or .bucket=="cancel")'
```

(Non-zero exit means failing/pending checks exist, not a broken command.) For each failing
GitHub Actions check, extract the run id from its `link` (the number after `/runs/`) and
pull the real error with `gh run view <run-id> --log-failed`. Checks with no Actions link
(CodeRabbit, Vercel, external statuses) have no fetchable logs - classify those
NEEDS_HUMAN in Step 3 with the link as evidence.

**Unresolved inline review threads** (the main CodeRabbit + human feedback channel).
Resolved threads are done - skip them. `isOutdated` threads are candidates for
`ALREADY_FIXED`:

```bash
gh api graphql --paginate -f owner="$OWNER" -f repo="$REPO" -F pr="$PR" -f query='
query($owner:String!,$repo:String!,$pr:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:50,after:$endCursor){
        pageInfo{hasNextPage endCursor}
        nodes{
          isResolved isOutdated path line
          comments(first:30){nodes{author{login} createdAt body}}
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
```

**Review bodies** (summary reviews, including checkbox reviews posted by teammates via
`/pr-review` - parse their `- [ ] file:line — description` items as individual
findings; skip already-checked `- [x]` items):

```bash
gh pr view "$PR" -R "$OWNER/$REPO" --json reviews --jq '.reviews[] | {author: .author.login, state, body}'
```

**Issue comments** (top-level PR comments):

```bash
gh pr view "$PR" -R "$OWNER/$REPO" --json comments --jq '.comments[] | {author: .author.login, body}'
```

**CodeRabbit CLI pass (supplementary - never a dependency).** Kick this off in the
background BEFORE gathering the channels above, then don't think about it again until the
end - never sit idle waiting for it (hard rule 4). The CodeRabbit GitHub app skips draft
PRs ("Review skipped - Draft detected"), so on a draft this is the only CodeRabbit signal;
on a ready PR it also covers commits pushed after the app's last review.

```bash
cr review --agent --type committed --base <default-branch>
```

Output is JSONL; each `{"type":"finding",...}` line carries `severity`, `fileName`, and
`codegenInstructions` (the claim, phrased as "In @file around lines X - Y, ..."). Parse
each finding line as a feedback item and merge it into the pipeline at whatever stage the
run has reached - late arrivals get their own validation wave. If `cr` is missing, not
authenticated, or still running once everything else is done, wait no more than ~2 minutes,
then finish without it and say so in the report.

**If every GitHub channel came back empty** (the norm on a fresh draft): do NOT stop and
do NOT wait for the CLI - you are the reviewer. Run Pre-PR mode step 2's routed review
agents against the PR branch's diff (`git diff <base>...HEAD`), treat their findings as
Source = `self-review`, and continue the pipeline with those. CLI findings join if and
when they arrive.

### Author filter

- **Include:** human reviewers, `coderabbitai` / `coderabbitai[bot]`.
- **Exclude:** `linear-code[bot]`, `macroscope[bot]`, and any other `[bot]` account except
  CodeRabbit.
- CodeRabbit's summary comment ("Walkthrough", "Actionable comments posted: N") is context,
  not a finding - the findings are its inline threads. Its collapsed "nitpick" sections DO
  count as findings.

## Step 2: Normalize into a findings list

Build one flat list. Each finding gets:

| Field | Content |
|---|---|
| ID | F1, F2, ... |
| Source | author + kind (inline thread / review body / comment / CI check / coderabbit-cli) |
| Anchor | `file:line` if present |
| Claim | one-sentence restatement of what the feedback says is wrong / wants changed |

If two sources flag the same issue at the same location, merge them (note both sources -
convergent feedback is a strong validity signal).

If the combined list is empty after ALL sources (GitHub channels, your own review agents
when the channels were empty, the CLI), report it and stop - that's a valid outcome.
Feedback mode: "no unresolved feedback and no findings on PR #N". Pre-PR mode: "no
candidate findings on this branch".

## Step 3: Validate every finding with parallel subagents

**This is the point of the command.** Launch one verification subagent per finding
(`general-purpose`, all in a single message so they run in parallel; batch multiple trivial
findings in the same file into one subagent). Each verifier gets the finding, the file(s) it
touches, and this stance:

```text
You are verifying a piece of code-review feedback on a branch that is checked out at
<repo-path>. Be a skeptic: your default is that the feedback is wrong, stale, or a
false positive. Read the actual code - the file, its callers, its tests, any contract it
depends on - and decide. Do NOT run tests or builds; verify by reading.

FEEDBACK (from <source>):
<claim, verbatim + normalized>
ANCHOR: <file:line>

Classify as exactly one of:
- VALID: the feedback identifies a real defect or a clearly better change. State the exact
  fix in 1-2 sentences (minimal diff, match surrounding style).
- FALSE_POSITIVE: the feedback is wrong. State the specific evidence (e.g. "the guard it
  claims is missing is at line 42", "callers already null-check this").
- ALREADY_FIXED: the code currently on disk already addresses it (common for outdated
  threads).
- NEEDS_HUMAN: a design opinion, a question, a taste call, or a request that conflicts with
  other feedback - not verifiable as right/wrong from the code.

If the source is a HUMAN and your verdict would be FALSE_POSITIVE, return NEEDS_HUMAN with
the same evidence instead - a human is never silently overruled.

Output: verdict + ≤3 sentences of evidence + (if VALID) the exact fix. No hedging - pick one.
```

**Verdict rules:**

- **CI failures are findings too** - the verifier reads the failure log and either produces
  a fix (VALID) or classifies it as flaky/infra (NEEDS_HUMAN, with evidence).
- A **human's explicit, specific change request** ("rename X to Y", "add a null check here")
  defaults to VALID unless the verifier finds concrete evidence it's wrong - in which case
  it becomes NEEDS_HUMAN (with the evidence), never a silent skip.
- Vague human comments ("hmm, is this right?") are NEEDS_HUMAN by definition.
- Distrust CodeRabbit's own severity labels (🟠 Major / 🟡 Minor) - re-derive validity from
  the code, not the label.
- A CodeRabbit ```suggestion``` block is a proposal, not truth - verify it compiles
  conceptually against the surrounding code before adopting it.

## Step 4: Fix the VALID findings

Fix in this order: correctness/CI-breaking items first, then simple mechanical fixes, then
anything complex - so a failure partway through still leaves the branch better than it
started. For each VALID finding, apply the minimal fix from the verifier (adjust as needed -
the orchestrator owns final code quality). Match the file's existing style and idioms.

Then verify the fixes hold: run the **targeted** tests/typecheck for the touched packages
(e.g. the package's `yarn test` / `go test ./...` for the changed dirs) - not the whole
monorepo. If a fix breaks a test, fix forward or drop that change and reclassify the finding
as NEEDS_HUMAN with what you learned.

## Step 5: Commit and push

```bash
git add <changed-files>   # explicit paths, not -A
git commit -m "Address PR feedback"
git push
```

Keep the message short and single-line. If nothing was VALID, skip this step - do not
create an empty commit.

## Step 6: Report locally (the deliverable)

Print one table covering **every** finding - nothing gets dropped silently:

```markdown
## PR #<N> feedback triage - <X> fixed, <Y> false positives, <Z> need you

| # | Source | Anchor | Verdict | Action / Evidence |
|---|--------|--------|---------|-------------------|
| F1 | coderabbitai (inline) | lib/track.ts:104 | VALID | Fixed: rethrow after logging |
| F2 | coderabbitai (inline) | lib/pre-hydration.ts:29 | FALSE_POSITIVE | `as Record` is safe here: input validated at line 12 |
| F3 | jane-doe (review) | api/handler.go:88 | NEEDS_HUMAN | Design question about retry semantics |
| F4 | CI: web-typecheck | - | VALID | Fixed: missing import after rebase |
```

Then, for each FALSE_POSITIVE and NEEDS_HUMAN item, print a **paste-ready reply** the
engineer can post themselves - factual, peer-level, leading with the verdict and evidence,
no apologies. You never post these; the engineer does.

Close with: commit SHA pushed (if any), and a reminder that unresolved threads on GitHub are
theirs to reply to / resolve.

## Pre-PR mode (no PR yet)

Review your own work-in-progress the way `/pr-review` would review the finished PR -
then fix what's confirmed instead of reporting it to someone else. No GitHub interaction at
all in this mode.

1. **Scope the diff.** Base = the repo's default branch
   (`git rev-parse --abbrev-ref origin/HEAD`). The review scope is
   `git diff <base>...HEAD` **plus** staged/unstaged changes (`git diff HEAD`) **plus**
   untracked files (`git ls-files --others --exclude-standard` - read their full contents;
   brand-new files are exactly what a pre-PR review must not miss). A dirty tree is
   expected here - it's work in progress; do not apply Step 0's dirty-tree stop. Skip
   generated code, lockfiles, and vendored deps.

2. **Fan out finding sources in parallel.** Kick off the CodeRabbit CLI in the background
   (`cr review --agent --type all` - `all` includes uncommitted work; skip gracefully if
   `cr` is missing, and never block on it: the subagent review below is the primary
   engine, CLI findings fold in if they arrive - hard rule 4). Simultaneously fan out
   routed review agents (parallel `general-purpose` subagents): Correctness & edge cases
   and Patterns & consistency always; Security & input handling, Contracts & blast radius,
   and Tests only when the diff touches those surfaces. Each agent gets its diff slice and
   this contract, verbatim:

   ```text
   REVIEW STANCE: decisive. Code matching established codebase patterns is CORRECT - don't
   flag it. Never say "worth verifying" / "consider" / "might". Only report defects you can
   state as fact, each anchored to file:line on disk.

   DO NOT FLAG: pre-existing issues not introduced by this branch; anything a
   linter/typechecker would catch; input-dependent maybes without a real triggering input;
   style or refactor preferences; generated files.

   OUTPUT CONTRACT: max 5 findings, severity-ordered, ≤3 sentences each. If nothing found,
   output exactly: "No <domain> issues found."
   ```

3. **Join the pipeline at Step 2.** Each candidate finding - from the review agents
   (Source = `self-review`) and from the CLI (Source = `coderabbit-cli`) - becomes a
   feedback item, then flows through Step 3 validation (fresh-context verifier, refute by
   default - neither source is HUMAN, so FALSE_POSITIVE verdicts apply normally), Step 4
   fixes, and the Step 6 report. If nothing survives verification, report that the branch
   is clean - a valid outcome.

4. **Do not commit or push.** Skip Step 5: fixes stay in the working tree so you can review
   them with `git diff`, then commit and open the draft PR through your normal flow - the
   fixes ship inside the PR, not as a follow-up commit.

5. **Report shape.** In this mode, title the Step 6 report "Branch self-review triage",
   omit the paste-ready replies (there are no GitHub threads to answer), and close with
   "fixes left uncommitted - review with `git diff`" instead of a commit SHA and the
   unresolved-threads reminder.

## Common gotchas

- `gh pr view --json reviews` returns review **bodies** only; inline comments require the
  GraphQL `reviewThreads` query above (or `gh api repos/O/R/pulls/N/comments --paginate`,
  which lacks resolved-state - prefer GraphQL).
- GraphQL `--paginate` needs the `pageInfo{hasNextPage endCursor}` block and `$endCursor`
  variable exactly as written above. REST `--paginate` + `--slurp` merges pages into one
  array, but `--slurp` cannot be combined with `--jq` - pipe the output to standalone `jq`
  instead. `--paginate` cannot paginate the nested `comments` connection - `first:30`
  covers all but monster threads, and the root comment (the finding itself) is always
  captured.
- Within a thread, the root comment is the finding; replies are context (and may already
  contain the author's rebuttal - factor it into the verdict). When CodeRabbit has reviewed
  multiple times, prefer the latest review's findings; older ones are usually stale.
- A force-push mid-run invalidates anchors: re-check `headRefOid` before committing if the
  gather step happened a while ago.
- The CodeRabbit app also skips any PR whose base is not the default branch ("Review
  skipped - reviews are disabled for this base branch") and any bot-authored PR ("bot user
  not eligible for review"). Both look like clean PRs and are not - they mean zero app
  coverage, so your own review is the only signal. The first case means you are in a stack;
  see the stack check in Step 0.
- Draft PRs run CI normally, but the CodeRabbit GitHub app SKIPS them ("Review skipped -
  Draft detected") - that's why Step 1 always runs the CodeRabbit CLI locally. Findings
  from the CLI and the app's threads often overlap on ready PRs; merge them in Step 2
  (convergence is a validity signal, not a duplicate to double-fix).
- `cr` CLI (v0.6.x): structured output is `--agent` (there is no `--json` flag), scope is
  `--type committed|uncommitted|all`, and it exits 0 even when findings exist - read the
  JSONL, not the exit code.
