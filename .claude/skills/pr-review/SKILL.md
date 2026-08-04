---
name: pr-review
description: Review a TEAMMATE'S pull request (or a pasted list of PRs) and unblock them. Runs a multi-agent review where every candidate finding is adversarially verified against the real code before it survives, then posts ONE review comment per PR with checkbox findings grouped by severity (Blocking through Nits) and gives you a clear APPROVE or HOLD recommendation. Philosophy is unblock by default - only confirmed damage a follow-up PR cannot repair blocks merging. Always shows the comments and asks before posting. Batch mode triages each PR light vs heavy. Stacked PRs (base branch is another open PR) are detected automatically and hand off to /pr-review-stack. Re-invoking on a PR you already reviewed continues it - verifies which checkboxes got fixed, reviews only the new commits, updates the same comment in place. Triggers on "review this PR", "review <name>'s PR", "should I approve this PR", "review PR 12345", "review these PRs", "re-review this PR", "they pushed changes", pasted PR URL lists.
---

# PR Review (teammate's PR, checkbox comment + verdict recommendation)

**EXECUTE THIS COMMAND IMMEDIATELY** - Do not explain what this command does. Execute the workflow below right now.

Review someone else's PR to a **confirmed-findings-only** bar, post **one** review comment
in checkbox format, and recommend a verdict to the engineer running the command.

**Philosophy - unblock by default.** A PR with imperfect-but-correct code should merge.
The ONLY findings that block are confirmed defects that cause real damage once merged AND
cannot be repaired by a follow-up PR. Everything else - including confirmed defects a
follow-up can fully repair - rides along as non-blocking checkboxes the author can address
before merge or in follow-ups. Emitting zero findings is a common, good outcome - never
manufacture findings to look thorough.

**⛔ HARD RULES:**

1. **One findings comment per PR, ever.** A single review submission carries all findings
   for that PR; re-reviews UPDATE it in place (see Re-review mode) rather than posting
   again. The only additional submission is a final verdict. Never post inline comments,
   never spam.
2. **Show before posting.** Always print the full comment body and the recommendation, then
   ask the engineer how to post (Step 8). Never post without their choice.
3. **The engineer owns the verdict.** You recommend APPROVE or HOLD; they decide.
4. **Only confirmed findings.** Every candidate goes through adversarial verification
   (Step 6). "Might", "could", "worth checking" never appear in the posted comment.
5. **Never touch the PR branch's content** - no pushes, no edits, no merges, no state
   changes.

## Step 1: Parse the PR and guard

The user's request names one or more PRs (URLs and/or numbers, separated by spaces, commas,
or newlines). **More than one PR → use Batch mode (section after Step 9), which wraps the
steps below.** For each: URL → owner/repo + number. Bare number → use the `origin` of the
git repo containing the current directory; if the current directory is not inside a git
repo, ask the user which repo.

Shell state does not persist between commands here - wherever a command below shows
`$OWNER`, `$REPO`, or `$PR`, substitute the literal values (e.g. `my-org`, `my-repo`,
`1234`) into each command you run.

**Self-review guard:**

```bash
gh api user --jq .login                                      # your login
gh pr view "$PR" --repo "$OWNER/$REPO" --json author,state   # PR author; state must be OPEN
```

If the two logins match, stop: GitHub won't let you approve your own PR, and fixing
feedback on your own PR is `/pr-self-review`. If `state` is not `OPEN`
(merged/closed), stop too - there is nothing to unblock.

**Stack check (do this before anything else - it can reroute the whole run):** a PR whose
base branch is not the repo's default branch is part of a **stack**, and reviewing it in
isolation reviews it against a fiction. Read the branch pair for every PR given:

```bash
gh pr view "$PR" --repo "$OWNER/$REPO" --json number,baseRefName,headRefName
gh repo view "$OWNER/$REPO" --json defaultBranchRef --jq .defaultBranchRef.name
```

A base that is not the default branch is a *hint*, not the test - it is also what a PR
targeting a long-lived release branch looks like. And a stack's BOTTOM PR does target the
default branch, so that hint misses it entirely. Confirm by looking for an actual chain
link in both directions:

```bash
gh pr list --repo "$OWNER/$REPO" --state open --head "<baseRefName>" --json number,headRefName,headRepositoryOwner   # is my base another PR's head?
gh pr list --repo "$OWNER/$REPO" --state open --base "<headRefName>" --json number,baseRefName,headRepositoryOwner   # is my head another PR's base?
```

Route to **`/pr-review-stack`** - which discovers the full chain from any single
member and adds the stack-level pass - if EITHER walk returns a PR for any PR given, or if
two of the PRs given chain together directly. **Run the upward walk even when the base IS
the default branch**; that is the only way the bottom of a stack is ever detected.

Say in one line that a stack was detected and what the chain looks like, then run the stack
command's workflow. Only count an edge when the candidate is in the SAME repository - a fork's PR
can carry the same branch name. If both walks are empty for every PR, there is no chain - continue
below (single PR) or with Batch mode (several), including for a PR targeting a release
branch.

**Prior-review check:** if you have already reviewed this PR (or the user says
"re-review" / "they pushed changes"), route to **Re-review mode** (section after Batch
mode) instead of reviewing from scratch:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate --slurp \
  | jq --arg login "$(gh api user --jq .login)" '[.[][] | select(.user.login==$login) | select(.body | contains("<!-- growth:pr-review -->"))] | last // empty | {id, commit_id, state, body}'
```

(The filter matches the hidden `<!-- growth:pr-review -->` marker every Step 7 body opens
with - including zero-finding ones - not a later one-line approval submission; `// empty`
makes no-match print nothing.) Empty output → normal fresh flow below.

## Step 2: Resolve the local checkout

Find a local checkout of `$OWNER/$REPO` by **discovery, not convention** - every machine
lays repos out differently, and no layout is "expected". A candidate is correct only if it
exists AND its `origin` matches `$OWNER/$REPO` - verify every candidate with
`git -C <path> rev-parse --show-toplevel` + `git -C <path> remote get-url origin` before
using it. Check these candidates in order and take the first that verifies:

1. The repo containing the current directory (works from the main checkout or any linked
   `git worktree` of it).
2. Conventional checkout paths - `~/<repo-name>`, `~/Projects/<repo-name>`, or a Go-style
   `~/go/src/github.com/$OWNER/<repo-name>`.
3. `$CWD/<repo-name>` - some engineers launch from a workspace folder holding several repo
   checkouts; skip instantly if the directory doesn't exist.
4. Nothing verified → ask the user where their checkout of `<repo-name>` lives. Never
   guess, never clone, and never tell the user their layout "should" look a certain way -
   candidates that don't exist are normal, not errors worth narrating.

## Step 3: Check out the PR in an isolated worktree

Never disturb the engineer's working tree - review in a detached worktree pinned to the
exact PR head. Do NOT use `gh pr checkout` here: it fails if the engineer already has the
PR branch checked out, and it silently reuses a stale local branch of the same name without
resetting it. Fetch the PR ref directly instead:

```bash
# Clean up any leftover worktree from a crashed prior run first
git -C <repo-path> worktree remove --force /tmp/pr-review-<repo>-<PR> 2>/dev/null; rm -rf /tmp/pr-review-<repo>-<PR>; git -C <repo-path> worktree prune

git -C <repo-path> fetch origin "+pull/<PR>/head:refs/pr-review/<PR>"
git -C <repo-path> worktree add /tmp/pr-review-<repo>-<PR> refs/pr-review/<PR> --detach
```

Fetching into a per-PR ref (not `FETCH_HEAD`, which is shared repo state and races when
several PRs from the same repo are set up in parallel; not a branch, so nothing appears in
the engineer's branch list) pins each worktree to exactly its PR's head. This creates no
branches and touches nothing in the engineer's checkout. It also works when `<repo-path>`
is itself a linked worktree - all worktrees share the same repository, so the fetch and the
new worktree land in the right place either way. All file reads and line numbers come from
this worktree, so anchors match the PR head. **Always remove it at the end** (Step 9), even
on failure.

## Step 4: Gather context (read-only)

```bash
gh pr view "$PR" --repo "$OWNER/$REPO" --json title,body,author,isDraft,headRefOid,additions,deletions,changedFiles
gh pr diff "$PR" --repo "$OWNER/$REPO"        # >300 files → HTTP 406; fall back to per-file patches via the files API
gh pr checks "$PR" --repo "$OWNER/$REPO" || true   # exit 1 = failing checks, 8 = pending; any OTHER error (auth, network) prints in the output - read it, never assume green
```

Also fetch **existing unresolved feedback** so you don't duplicate it - anything CodeRabbit
or another reviewer already flagged in an unresolved thread is the author's to handle, not a
finding for your comment:

```bash
gh api graphql --paginate -f owner="$OWNER" -f repo="$REPO" -F pr="$PR" -f query='
query($owner:String!,$repo:String!,$pr:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:50,after:$endCursor){
        pageInfo{hasNextPage endCursor}
        nodes{isResolved path line comments(first:5){nodes{author{login} body}}}
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false) | {path, line, claim: .comments.nodes[0].body[0:200]}'
```

**Separate signal from noise before sizing the review:** generated code (`*.pb.go`,
`*_pb2.py`, GraphQL/OpenAPI codegen, snapshots), lockfiles, and vendored deps are noise -
note them as skipped, review only the real diff.

## Step 5: Parallel review agents (routed, not blanket)

Read the changed files plus their immediate callers/tests in the worktree to build a mental
model, then fan out review subagents (`general-purpose`, one message, parallel). Route by
what the diff actually touches - skip domains with no surface:

| Agent | Always? | Include when diff touches... |
|---|---|---|
| Correctness & edge cases | ✅ always | any code with control flow |
| Security & input handling | if in scope | user input, auth, persistence, URLs, file paths |
| Contracts & blast radius | if in scope | exported APIs, protos, schemas, shared utils, configs consumed elsewhere |
| Tests | if in scope | new logic-bearing code |
| Patterns & consistency | ✅ always | (cheap - checks the diff against neighboring idioms) |

Each agent's prompt embeds its diff slice (not the full diff, unless the PR is small) and
ends with this contract, verbatim:

```text
REVIEW STANCE: decisive. Code matching established codebase patterns is CORRECT - don't
flag it. Never say "worth verifying" / "consider" / "might". Only report defects you can
state as fact, each anchored to file:line from the checked-out worktree.

DO NOT FLAG (these erode trust and waste the author's time):
- Pre-existing issues not introduced by this PR
- Anything a linter/typechecker/formatter would catch (CI covers it)
- Input-dependent maybes ("if X were ever null...") without a real triggering input
- Style, taste, or refactor preferences a senior engineer wouldn't hold a merge for
- Code explicitly silenced (lint-ignore, eslint-disable, nolint) or generated files

OUTPUT CONTRACT:
- Max 5 findings, severity-ordered. ≤3 sentences each: location + defect + concrete impact.
- If nothing found, output exactly: "No <domain> issues found."
```

## Step 6: Adversarial verification (the false-positive gate)

For every candidate finding from Step 5, launch a **fresh-context verifier** subagent
(parallel, one per finding). The verifier gets ONLY the finding and the worktree path - not
the reviewing agent's reasoning:

```text
A code review flagged this issue. Your job is to REFUTE it. Read the actual code at
<worktree-path> - the flagged file, its callers, its tests, the contracts it depends on -
and try to prove the finding wrong (guard exists elsewhere, input can't occur, pattern is
established and intentional, test covers it). Do not run anything; verify by reading.

FINDING: <file:line> — <claim>

Output exactly one of:
- REFUTED: <the specific evidence>
- CONFIRMED: <why the defect is real> + the concrete failure scenario (input/state → wrong
  outcome), and confirm the file:line anchor is exact on disk.
If uncertain after reading, output REFUTED - an unverified finding must not reach the PR.
```

Only CONFIRMED findings survive. Also drop any survivor that duplicates an existing
unresolved thread from Step 4 (note it as "already flagged by <author>" in the local
report instead).

## Step 7: Calibrate severity and compose the comment

Bucket the surviving findings:

- **Blocking** - gates approval. Reserved for confirmed defects that pass BOTH tests:
  - **Damage test**: merging causes real harm - wrong user-facing behavior, a crash or
    unhandled error on a real input, data loss/corruption, bad writes/migrations, a race,
    a security hole, or breaking an API/contract other code consumes.
  - **Punt test**: it cannot be handled in a follow-up PR - harm accrues between merge and
    fix (bad data written, users affected, security exposed) or the damage is hard to
    reverse.

  Litmus before marking anything Blocking: "If this merges now and a follow-up PR lands
  tomorrow, does real harm land in the meantime that the follow-up cannot undo - users
  affected, bad data written, security exposed?" If no, it is not Blocking - a
  dev-tooling gate that silently no-ops, a defect with a CI or prod backstop, or a broken
  promise in the PR description all fail this litmus and belong one tier down.
- **Should Fix Before Merge** - confirmed defects that deserve fixing before merge but are
  puntable without damage: the PR doesn't fully deliver what it advertises (a gate or
  hook that silently skips most inputs, a feature that misses a documented case), dev/CI
  tooling gaps with a backstop elsewhere, or defects covered by defense-in-depth where
  the fix is cheap now and costlier later. Non-gating - the author fixes before merge or
  commits to an immediate follow-up; either is acceptable.
- **Medium Priority** - confirmed real, limited impact: an edge case that degrades rather
  than breaks, undercounted metrics, error handling that surfaces poorly.
- **Test Gaps** - new logic with no covering test, or tests that miss the paths that matter.
- **Nits** - small and unambiguously correct fixes. Use sparingly.

When torn between Blocking and Should Fix Before Merge, choose Should Fix Before Merge -
severity inflation erodes the tool's credibility faster than a rare under-call, and the
comment still tells the author exactly what to fix.

Drop everything else: style/taste, questions, refactor preferences, praise, restating the
diff.

**Comment body format** (matches the team convention - checkbox per finding, sections
omitted when empty; use head-branch line numbers verified on disk). Every body - including
a zero-finding one - opens with the hidden marker line `<!-- growth:pr-review -->` (renders
invisibly; it is how the Step 1 prior-review check recognizes the comment later), then the
attribution line as the first visible sentence, verbatim:
`Reviewed with /pr-review`

```markdown
<!-- growth:pr-review -->
Reviewed with `/pr-review`

Blocking

- [ ] path/to/file.ts:123 — <what is wrong + concrete impact + direction to fix, 1-3 lines>

Should Fix Before Merge

- [ ] path/to/hook.yml:75 — <confirmed defect + why it's safe to punt if needed, 1-3 lines>

Medium Priority

- [ ] path/to/other.go:45 — <...>

Test Gaps

- [ ] path/to/file.test.ts:1 — <untested scenario that matters>

Nits

- [ ] path/to/file.ts:200 — <small unambiguous fix>
```

If nothing survived verification, do NOT summarize the PR or recite what you checked - a
verbose litany on a clean approval is noise. The body is exactly the marker, the
attribution, and a plain lgtm:

```markdown
<!-- growth:pr-review -->
Reviewed with `/pr-review`

lgtm
```

## Step 8: Recommend, confirm, post

Derive the recommendation:

- **APPROVE** - zero Blocking findings. Should Fix Before Merge / Medium / Test Gaps /
  Nits do not hold up a merge; the checkboxes give the author a fix-or-follow-up list.
  When Should Fix Before Merge items exist, say in the rationale (and in any approval
  body) that they should land before merge or in an immediate follow-up.
- **HOLD** - one or more Blocking findings. Do not approve until they're addressed.

Print the full comment body, the recommendation, and a one-line rationale. Then ask via
AskUserQuestion:

- Recommendation APPROVE → options: **"Approve with this comment (Recommended)"** /
  "Comment only (no verdict)" / "Don't post - I'll handle it".
- Recommendation HOLD → options: **"Comment only (Recommended)"** / "Request changes with
  this comment" / "Don't post - I'll handle it".

Post as a **single review submission** (body + verdict in one call - no separate
approve-then-comment dance). Write the body to a temp file for sane quoting:

```bash
gh pr review "$PR" --repo "$OWNER/$REPO" $FLAG --body-file /tmp/pr-review-<repo>-<PR>-body.md
```

`$FLAG` is `--approve`, `--comment`, or `--request-changes` per the engineer's choice.

**Eligibility re-check first:** right before posting, confirm the PR is still open and
re-read `headRefOid`. If the head moved since Step 4, refresh the worktree to the new head
first - re-run the Step 3 fetch, then
`git -C /tmp/pr-review-<repo>-<PR> checkout --detach refs/pr-review/<PR>` (the detached
worktree stays on the old commit until you do) - then re-verify every anchor against the
refreshed worktree. If that changes the body or the recommendation in ANY way, print the
revised body and ask again before posting. The engineer must never see one body and have a
different one posted.

## Step 9: Clean up and report

```bash
git -C <repo-path> worktree remove /tmp/pr-review-<repo>-<PR> --force
git -C <repo-path> update-ref -d refs/pr-review/<PR>
```

Always - even if the review was aborted.

Final local output: the verdict recommendation restated, what was posted (or "nothing
posted"), findings count by bucket, and anything noted-but-not-posted (noise skipped,
duplicates of existing threads).

## Batch mode (multiple PRs)

When the request names several PRs, review them all in one run. One bad item never
kills the batch.

**Batch is for INDEPENDENT PRs.** Run Step 1's stack check across the whole list first -
including the upward walk on every PR, since the bottom of a stack targets the default
branch like any independent PR. If any PR chains to another open PR, the whole run belongs
to `/pr-review-stack`. Batch mode reviews each PR against the default
branch and has no cumulative-end-state pass, so running it on a chain both misses the
cross-PR findings and duplicates the lower PRs' findings onto the upper ones.

1. **Parse and guard each PR** (Step 1 per PR, including its `--json author,state` check).
   Your own PR → mark it "skipped - own PR (use /pr-self-review)" in the final table
   and continue. `state` not `OPEN`, or unresolvable → same: mark and continue.

2. **Triage scan (cheap, before any deep review).** For each PR, run only the Step 4
   metadata/diff-stat/CI commands and classify on the REAL diff (net of generated noise):
   - **light** - mechanical and low-risk: dep bumps, config, docs, renames, codemods, or a
     small real change buried in generated noise, with green CI.
   - **heavy** - real logic, sensitive surfaces (auth, payments, PII, migrations,
     public/shared APIs), thin tests, red required checks, a large real diff - or you are
     simply not confident from the scan. Uncertainty routes heavy: a wasted deep review
     costs less than a bad approval.

3. **Review each PR at its depth.** For each non-skipped PR, run Steps 2-4 in full (the
   unresolved-threads query included - the Step 6 dedup depends on it), then:
   - **light** → one combined reviewer subagent (correctness + patterns, same stance and
     contract as Step 5), the Step 6 verifier on anything it flags, then Step 7 composition
     and the Step 8 recommendation. If the light pass reveals hidden depth, promote the PR
     to heavy - never approve on a scan you outgrew.
   - **heavy** → the full Step 5-8 pipeline through the recommendation.
   In both paths, stop before Step 8's ask-and-post - step 4 below consolidates that.
   Worktree paths and fetch refs are namespaced per repo + PR (Step 3), so per-PR setup and
   review can run in parallel; keep each PR's findings strictly separate.

4. **One consolidated confirmation.** Print every PR's comment body and recommendation,
   HOLDs first, then ask ONCE via AskUserQuestion:
   - "Post all as recommended" - APPROVE-recommended PRs get `--approve` with their body,
     HOLD-recommended PRs get `--comment` with theirs.
   - "Decide per PR" - re-ask with the Step 8 options, one question per PR (up to 4 PRs
     per AskUserQuestion call).
   - "Post none - I'll handle it".

5. **Post, clean up, report.** Post each confirmed submission with the Step 8 mechanics
   (including the per-PR eligibility re-check), remove every worktree (Step 9), and close
   with one table: PR | title | class (light/heavy) | blocking/should-fix/medium/gaps/nits |
   recommendation | posted as.

PRs you have reviewed before take the Re-review mode flow below as their step-3 depth work
- a mixed batch of first-reviews and re-reviews is fine. In batch steps 4-5, a re-review
PR is posted via Re-review step 4's in-place PUT (plus the one-line approval when
recommended and confirmed) - never a fresh `--comment` with its body, which would
double-post the findings.

## Re-review mode (the author pushed changes)

You reviewed this PR before; continue that review instead of starting over. Your prior
checkbox comment is the state, and its `commit_id` (from the Step 1 prior-review check) is
the exact head it was submitted against.

1. **Diff since your review.**

   ```bash
   gh api "repos/$OWNER/$REPO/compare/<commit_id>...<current-headRefOid>" \
     --jq '{ahead: .ahead_by, behind: .behind_by, files: [.files[].filename]}'
   ```

   If the compare fails, history was rewritten under you (`behind_by > 0`), or `files`
   comes back with exactly 300 entries (the compare API's documented cap - it truncates
   silently), fall back to a full fresh review (Steps 2-7) - but still do step 4 below so
   the old comment reflects reality.

2. **Verify your prior findings** against the current worktree (run Steps 2-4 as usual -
   the worktree, `headRefOid`, current diff, and unresolved-threads query are all still
   needed here). For each still-unchecked `- [ ]` item in your prior body, a verifier subagent
   (Step 6 stance) returns FIXED or STILL_OPEN. Items the author ticked (`- [x]`): accept
   the tick for Should Fix Before Merge / Medium Priority / Test Gaps / Nits, but re-verify
   ticked **Blocking** items anyway - trust, but verify what gates the merge.

3. **Review only the delta.** Run the Step 5-7 pipeline scoped to the compare file list
   (intersected with the current PR diff). New commits can introduce new defects; the
   untouched rest of the PR is already covered by round 1.

4. **Update the existing comment in place - never post a second findings comment.** Build
   the updated body: tick `- [x]` every FIXED item, leave STILL_OPEN unchecked, append new
   findings under a `Re-review (<short-sha>)` line inside the same severity sections. Show
   it first (hard rule 2 applies to updates too), then:

   ```bash
   gh api --method PUT "repos/$OWNER/$REPO/pulls/$PR/reviews/<review-id>" \
     -F body=@/tmp/pr-review-<repo>-<PR>-body.md
   ```

5. **Verdict.** Every Blocking item FIXED and no new Blocking → recommend APPROVE; on
   confirmation post the approval (Step 8 mechanics) with a one-line body ("Blocking items
   addressed - approving; remaining checkboxes are non-blocking." - or, if Should Fix
   Before Merge items remain open, note per Step 8 that they should land before merge or
   in an immediate follow-up). Any Blocking item
   STILL_OPEN or new → HOLD; the in-place update from step 4 is the only post. If you had
   already approved and new commits introduce a Blocking finding, recommend HOLD, say so in
   the updated body, and note that dismissing your own stale approval is a manual GitHub
   action.

## Common gotchas

- `gh pr diff` returns HTTP 406 for PRs >300 files - fall back to
  `gh api repos/O/R/pulls/N/files --paginate` and review per-file patches.
- Draft PRs accept reviews and approvals normally - draft status doesn't change the flow.
- A green `gh pr checks` line reading "CodeRabbit  pass" is often CodeRabbit *declining* to
  review - "Review skipped: reviews are disabled for this base branch" (the PR is stacked)
  or "bot user not eligible for review" (bot-authored PR). Read the description column, not
  just the state; both mean your review is the only signal on that PR.
- The Reviews API rejects `APPROVE` from the PR author (guarded in Step 1).
- Review-body checkboxes are plain markdown - the author can tick them; no inline `line`
  anchoring is used, so there is no 422 risk from lines outside diff hunks.
- CI red on a required check is a stop sign worth naming in the comment; an obviously flaky
  red is a judgment call, not an auto-HOLD.
- Review bodies cap at 65,536 characters - if findings somehow exceed that, keep the top
  items per bucket and end with "plus N more (ask me for the full list)".
- When listing existing comments via REST instead of GraphQL, remember `--paginate` (30
  items/page default), and that `--slurp` merges pages into one array but cannot be
  combined with `--jq` - pipe `--paginate --slurp` output to standalone `jq` instead.
