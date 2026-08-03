---
name: pr-self-review-stack
argument-hint: "[pr-number-or-url anywhere in the stack]"
description: Review and fix YOUR OWN stack of PRs - a chain where each PR's base branch is the previous PR's head branch. Discovers the full chain from any single member, gathers feedback per PR, verifies every finding against the real code, then fixes each one at the LOWEST PR that owns it rather than patching the symptom at the top. Handles the part that makes stacks painful - after a fix lands in a lower branch it rebases every branch above it and force-pushes with lease, bottom-up, then re-verifies that every link is zero-behind its base. Also runs the stack-level pass on the composed end state. Never posts anything to GitHub and always asks before the first force-push. Triggers on "review my stack", "fix feedback on my stacked PRs", "self review my PR stack", "my PRs are stacked", "rebase my stack after fixes", "address feedback across my stack".
---

# PR Stack Self-Review (review, fix at the right layer, restack)

**EXECUTE THIS COMMAND IMMEDIATELY** - Do not explain what this command does. Execute the workflow below right now.

A **stack** is a chain of your PRs where each PR's `baseRefName` is the previous PR's
`headRefName` rather than the default branch. Self-reviewing a stack differs from
self-reviewing one PR in exactly two ways, and both are the hard part:

- **A finding must be fixed at the PR that OWNS it**, not wherever you noticed it. Patching
  a lower PR's defect in an upper PR leaves the lower PR shipping the bug and makes the
  upper diff incoherent.
- **Fixing a lower PR rewrites the base of everything above it.** Every upper branch must be
  rebased and force-pushed, bottom-up, or the stack silently becomes a state nobody
  reviewed and CI never ran.

Everything in `/pr-self-review` applies - the validation gate, the verdict
classes (VALID / FALSE_POSITIVE / ALREADY_FIXED / NEEDS_HUMAN), the never-overrule-a-human
rule, the report shape. This command adds the stack layer and reuses that machinery by
reference.

**⛔ HARD RULES - read before doing anything:**

1. **NEVER write to GitHub except `git push`.** No comments, no reviews, no thread
   resolution, no PR-body edits, no GraphQL mutations. Ever.
2. **Never fix an unverified finding.** Every item goes through the validation gate first.
3. **Never silently ignore a human.** Failed validation on a human comment becomes
   `NEEDS_HUMAN` with a suggested reply - the engineer's call.
4. **Fix at the lowest PR that owns the defect.** Never patch downward-owned code in an
   upper branch.
5. **ASK before the first force-push.** Restacking rewrites published branch history.
   Show the plan and get a yes. Prefer `gh stack sync`, which pushes atomically with
   `--force-with-lease`. A hand-rolled push must pin the lease to the Step 0 `headRefOid` -
   a bare `--force-with-lease` after a `git fetch` is not a lease at all. Plain `--force`
   never.
6. **Restack bottom-up.** `gh stack sync` does this atomically. The manual fallback goes
   one branch at a time, verifying each link before moving up - and a half-restacked stack
   is worse than an unfixed one, so report exactly which links completed if it stops.

## Step 0: Discover the chain and guard

`$ARGUMENTS` may be a PR number, a URL, or empty (use the current branch's PR, same
resolution as `/pr-self-review` Step 0). **Any single member discovers the rest.**

**Ordering is a safety property here, not a style choice.** Everything read-only happens
first; nothing touches the checkout until the dirty-tree gate has passed. Run 0a through 0f
in order.

### 0a. Readiness and remote

```bash
command -v gh git >/dev/null || { echo "gh and git are required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login --hostname github.com --web"; exit 1; }
REMOTE=$(git -C <repo-path> remote | grep -qx origin && echo origin || git -C <repo-path> remote | head -1)
```

**Do not hard-code `origin`.** Resolve `REMOTE` once here and substitute it into every
`fetch`, `rev-list`, `rebase`, and `push` below - a force-push aimed at the wrong remote is
not a recoverable mistake. `gh stack` takes `--remote` for the same reason.

### 0b. Discover the chain (read-only)

Walk it by hand, in both directions. This is always safe and never touches the working
tree, so it runs regardless of whether `gh stack` is present. Only accept an edge when the
candidate is in the **same repository** - a fork's PR can carry the same branch name:

```bash
gh pr view "$PR" -R "$OWNER/$REPO" --json number,title,author,state,isDraft,baseRefName,headRefName,headRefOid,headRepositoryOwner
gh pr list -R "$OWNER/$REPO" --state open --head "<baseRefName>" --json number,baseRefName,headRefName,headRepositoryOwner,title   # downward
gh pr list -R "$OWNER/$REPO" --state open --base "<headRefName>" --json number,baseRefName,headRefName,headRepositoryOwner,title   # upward
```

More than one match for a single link means the chain is ambiguous - stop and show the
engineer the candidates rather than guessing.

Order the chain bottom (base == default branch) to top. **If nothing chains, this is not a
stack** - hand off to `/pr-self-review` and say so in one line.

### 0c. Author guard

`gh api user --jq .login` must equal each PR's author. A chain member authored by someone
else means this is a shared stack - stop and ask; you must not rewrite a teammate's branch.
Every member must be `OPEN`.

### 0d. Worktree map and dirty-tree gate - BEFORE any mutation

```bash
git -C <repo-path> worktree list --porcelain
git -C "<each branch's worktree path>" status --porcelain
```

Build an explicit branch → working-path map for the whole chain. **Any dirty tree anywhere
in the chain is a full stop** - a rebase over uncommitted work can destroy it, and so can
`gh stack checkout` in 0e. Ask; do not stash on the engineer's behalf. A chain branch with
no worktree at all is also a stop - create it or ask, do not guess.

### 0e. Adopt `gh stack` if available (first mutating step)

GitHub's official stacked-PR extension (`github/gh-stack`, <https://gh.io/stacks>) does
cascading rebase correctly, which is the part that is easy to get catastrophically wrong by
hand. Probe for real capability, not just installation:

```bash
ORIGINAL_BRANCH=$(git -C <repo-path> branch --show-current)    # record BEFORE mutating
gh extension list | grep -q gh-stack || echo "gh-stack absent - Path B"
gh stack checkout "$PR"    # resolves the stack from the API even when untracked locally
gh stack view --json       # ordered chain + per-branch PR status, incl. a Needs rebase flag
```

**Validate before trusting it.** `gh stack view` takes no PR or repository argument - it
reports whatever stack is tracked locally right now. Require its JSON to name this
repository and to contain exactly the PRs discovered in 0b. On any mismatch, empty output,
or non-zero exit, **discard it and use the 0b chain with the Path B restack** rather than
acting on a stack that is not the one you reviewed.

> `gh stack checkout` **switches the current branch** and writes local tracking state. That
> is acceptable here only because 0d has already proven every tree clean and Step 6 is going
> to rewrite these branches anyway. `ORIGINAL_BRANCH` is what the cleanup contract below
> restores.

### 0f. Tip worktree and pre-fix baseline

Steps 2, 3 and 4 all depend on the tip worktree, and the baseline numbers are only
meaningful before you change anything.

**Reserve the path BEFORE creating the ref.** `refs/pr-selfreview/<top-PR>` is shared state
for this repo+PR, and fetching it with a leading `+` force-updates it. If two runs race, the
second silently repoints the first's ref and then both fight over cleanup. Claim the
directory first - `mkdir` fails atomically if it already exists, which is the lock:

```bash
TIP=/tmp/pr-selfreview-<repo>-<top-PR>-tip
mkdir "$TIP" || { echo "another run holds $TIP - stop, do not force-remove"; exit 1; }
rmdir "$TIP"     # worktree add needs to create it itself; the race window is now closed

git -C <repo-path> fetch $REMOTE
git -C <repo-path> fetch $REMOTE "+pull/<top-PR>/head:refs/pr-selfreview/<top-PR>"
git -C <repo-path> worktree add "$TIP" refs/pr-selfreview/<top-PR> --detach

# For EVERY adjacent pair, bottom-up - record both numbers AND the fork point.
git -C <repo-path> rev-list --left-right --count $REMOTE/<lower-branch>...$REMOTE/<upper-branch>
git -C <repo-path> merge-base $REMOTE/<lower-branch> $REMOTE/<upper-branch>
```

**Record each pair's `merge-base` output as that link's `OLD_BASE`, and each PR's
`headRefOid` as its lease value.** Step 6's fallback path needs both. It is
the commit the upper branch currently forks from, and Step 6 needs it to rebase correctly.
Once a fix lands on the lower branch this value is no longer derivable, so capturing it here
is not an optimization - it is the only reliable source.

**If any link's LEFT count is already non-zero**, the stack is stale before you have touched
it. Note it; Step 6 will restack regardless of whether any fix lands.

Print the chain, the branch → path map, each PR's `headRefOid`, the tip worktree path, and
the per-link baseline table before proceeding.

### Cleanup contract - runs on EVERY exit path

Not just on success. A dirty tree, an ambiguous chain, a failed validation, a declined
force-push, a rebase conflict, or a rejected lease all exit early, and each one can strand
state that the next run mistakes for a live concurrent run. Whenever this command stops,
for any reason, run all of it - each step is idempotent and safe to repeat:

```bash
git -C <repo-path> worktree remove "$TIP" --force 2>/dev/null; git -C <repo-path> worktree prune
git -C <repo-path> update-ref -d refs/pr-selfreview/<top-PR> 2>/dev/null
git -C <repo-path> checkout "$ORIGINAL_BRANCH" 2>/dev/null   # only if 0e switched it
```

Restoring `ORIGINAL_BRANCH` matters most on the paths where you never got to Step 6 - the
engineer typed one command and must not be left standing on some other branch of their own
stack. If a restack DID complete, say which branch they are on instead of moving them.

## Step 1: Gather feedback per PR

Run `/pr-self-review` Step 1 against **each** PR in the chain - metadata, failing
checks via the `bucket` field, unresolved review threads via the GraphQL query, review
bodies (including `- [ ]` checkbox items from a teammate's `/pr-review` or
`/pr-review-stack` comment), and issue comments. Apply the same author filter.

Three stack-specific adjustments:

- **CodeRabbit is absent above the bottom PR.** The app posts "Review skipped - reviews are
  disabled for this base branch" on any PR whose base is not the default branch. Expect
  zero app feedback on every upper PR and do not treat it as "nothing to fix".
- **Point the CodeRabbit CLI at the PR's OWN base**, not the default branch, or it
  re-reports every lower PR's code as findings on the upper PR:
  ```bash
  cr review --agent --type committed --base <this PR's baseRefName>
  ```
  Same rules as always - background it, never block on it, ~2 minute cap.
- **Empty channels are the norm here.** With CodeRabbit sitting out the upper PRs, you are
  usually the only reviewer. Run the routed review agents (`/pr-self-review` Pre-PR
  mode step 2 contract) against each PR's own delta, Source = `self-review`.

## Step 2: Normalize, and assign every finding an OWNER PR

Build the flat findings list from `/pr-self-review` Step 2, with one added column
that drives everything downstream:

| Field | Content |
|---|---|
| ID | F1, F2, ... |
| Source | author + kind |
| Anchor | `file:line` |
| Claim | one-sentence restatement |
| **Owner PR** | **the LOWEST PR in the chain whose diff introduced the flagged code** |

Determine Owner PR by evidence, not by where the comment was posted:

```bash
# Which PR's delta introduced this line? `gh pr diff` takes NO pathspec (it errors with
# "accepts at most 1 arg(s)"), so filter its output, or diff the PR's range directly.
gh pr diff <PR> -R "$OWNER/$REPO" | grep -A40 "^diff --git a/<path>"
git -C <repo-path> diff "origin/<that PR's baseRefName>...origin/<that PR's headRefName>" -- <path>
# Or, decisively, from the tip worktree created in Step 0 - find the commit that last
# touched the line, then map that commit back to the PR whose delta contains it.
git -C /tmp/pr-selfreview-<repo>-<top-PR>-tip log -1 --format=%H -L <line>,<line>:<path>
git -C <repo-path> branch -r --contains <that-commit>   # lowest branch containing it wins
```

A reviewer commenting on PR 3 about a line PR 1 introduced is common and normal - the
finding's owner is PR 1. Merge duplicate findings across PRs into one item; convergent
feedback on the same line from two PRs' reviewers is one defect, not two.

If the list is empty after all sources, report that and stop - a valid outcome.

## Step 3: Validate every finding

Unchanged from `/pr-self-review` Step 3 - one fresh-context verifier subagent per
finding, launched in parallel, refute-by-default, verify by reading only. Add one line to
each verifier's prompt:

```text
STACK CONTEXT: this branch is part of a stack. Code that looks unreferenced or
half-migrated may be resolved by a LATER branch in the chain. Before confirming a
"dangling reference" or "unused addition", check the tip of the stack at
<tip-worktree-path>. If it is resolved there, the finding is a FALSE_POSITIVE - correct
stack ordering, not a defect.
```

Substitute the literal `/tmp/pr-selfreview-<repo>-<top-PR>-tip` path from Step 0 into every
verifier prompt. Without it they will confirm a stream of false positives about
half-completed migrations, which is exactly what a well-ordered stack looks like one PR at
a time.

## Step 4: The stack-level pass on the composed end state

Run `/pr-review-stack` Step 5 against the tip worktree created in Step 0 -
cumulative end-state coherence (5a), cross-PR interactions (5b), namespace/global
collisions (5c), does-the-union-deliver (5d). Anything confirmed becomes a finding with an
Owner PR and joins the Step 3 validation pipeline like any other.

**The Step 0 baseline gates this step.** The tip contains every commit in the stack *only
when every internal link is zero-behind*. If any link's LEFT count was non-zero, the tip is
a composition that will never ship, and end-state findings read against it are findings
about a fiction. In that case, skip 5a-5d, report that the stack is stale, and propose the
Step 6 restack first - then re-run this step against the restacked tip.

## Step 5: Fix each VALID finding on its OWNER branch

Work **bottom-up through the chain**, and within each PR use the
`/pr-self-review` Step 4 ordering (correctness/CI-breaking first, then mechanical,
then complex). For each owner branch, in its mapped working path:

1. Check out / switch to that branch's worktree path.
2. Apply the minimal fixes for every finding owned by that PR.
3. Run the **targeted** tests/typecheck for the touched packages only - never the whole
   monorepo.
4. Commit with a short single-line message and push normally (no force needed yet - you
   have not rewritten anything, only added a commit):
   ```bash
   git add <changed-files>          # explicit paths, never -A
   git commit -m "Address review feedback"
   git push
   ```
5. **Stop.** Do not move to the next branch yet - the branches above this one are now
   behind their base. Step 6 fixes that before any further work.

If a fix breaks a test, fix forward or drop it and reclassify as NEEDS_HUMAN with what you
learned. Never leave a branch in the chain with a broken build - every branch below the tip
is a merge candidate on its own.

## Step 6: Restack - propagate the fix upward

**This is the step that makes the command worth running.** After a commit lands on a lower
branch, every branch above it points at the OLD base commit. Left alone, the stack
silently ships a state nobody reviewed.

**Show the plan and ask before the first force-push** (hard rule 5), whichever path you
take. Print which links moved and what will be rewritten, then get a yes:

```text
Restack plan (bottom-up):
  1. feat/update-chart-widget  onto feat/remove-legacy-toggle  (2 commits, 1 behind)
  2. feat/add-summary-module   onto feat/update-chart-widget   (1 commit, will be 1 behind after step 1)
Force-pushes with --force-with-lease. PRs 1202 and 1203 will re-run CI.
```

### Path A - `gh stack sync` (preferred, and much safer)

If `gh stack` is available, **use it and do not hand-roll the rebase.** One command does the
whole cascade correctly:

```bash
gh stack sync
```

It fetches, fast-forwards the trunk, cascade-rebases every branch onto its updated parent,
and pushes **all branches atomically** with `--force-with-lease --atomic`. That atomicity is
why this path has no partial-restack failure mode, unlike the loop below - and it is specific
to `sync`. (`gh stack push` documents the opposite: "Updates are not atomic: a branch may
update even if another branch is rejected." Do not substitute one for the other.) On a rebase
conflict, `sync` restores every branch to its original state and tells you to run
`gh stack rebase` interactively - do not resolve it unattended. Use `gh stack rebase` when
you want the rebases without the push, and `--remote $REMOTE` if the remote is not `origin`.

**⚠ `sync` can succeed while doing nothing.** If the local and remote stacks have diverged,
it prompts - and in a NON-INTERACTIVE terminal, which is what you are, it "aborts the sync
without pushing branches or updating PRs". A zero exit code is therefore not proof the
restack happened. **Always gate on the state, never on the exit code:**

```bash
gh stack sync --remote "$REMOTE"
gh stack view --json     # REQUIRED: every branch must have cleared its Needs rebase flag
```

If any branch still needs a rebase, the sync no-opped. Report that and fall through to Path
B rather than assuming it worked.

Note that `sync` does more than restack - it also reconciles your local stack with the one on
GitHub, syncs PR state, and creates/updates the remote stack object when two or more PRs
exist. All are appropriate for your own stack, but say so in the report; the engineer should
not discover a new GitHub stack object by surprise.

### Path B - fallback, `gh stack` absent

Execute **one branch at a time, bottom-up**, verifying before moving up. `OLD_BASE` is this
link's fork point **recorded in Step 0, before any fix landed** - not something to recompute
now. Substitute that literal SHA into the rebase.

```bash
# Sanity-check the recorded SHA resolves and is actually an ancestor of the upper branch.
# If EITHER check fails, STOP - do not rebase. See the guard note below.
git -C <repo-path> cat-file -e "<OLD_BASE-sha>^{commit}"
git -C <repo-path> merge-base --is-ancestor "<OLD_BASE-sha>" "origin/<upper-branch>"

git -C <upper-branch-worktree-path> rebase --onto "origin/<lower-branch>" "<OLD_BASE-sha>" "<upper-branch>"

# Pin the lease to the OID captured in Step 0 - see the lease trap below.
git -C <upper-branch-worktree-path> push \
  --force-with-lease="refs/heads/<upper-branch>:<upper-branch-headRefOid-from-Step-0>" \
  origin "<upper-branch>"

# Verify the link closed before touching the next one up:
git -C <repo-path> fetch origin
git -C <repo-path> rev-list --left-right --count origin/<lower-branch>...origin/<upper-branch>   # must print "0 <n>"
```

**⚠ Trap 1 - a bare `--force-with-lease` is not a lease here.** Without an explicit expected
value, the lease is checked against the remote-tracking ref `refs/remotes/origin/<upper>` -
which the `git fetch origin` in this very step just refreshed. If a teammate or CI pushed to
the upper branch in the meantime, the fetch adopts *their* commit as the expected value and
the force-push destroys it silently. **Always pin the lease to the `headRefOid` captured in
Step 0**, so the push fails loudly when the remote has moved since you looked.

**⚠ Trap 2 - the empty-`OLD_BASE` branch-deleter.** If the `<OLD_BASE-sha>` slot is empty or
unset, the command collapses to `git rebase --onto origin/<lower> <upper-branch>`, which git
parses as `--onto <newbase> <upstream>` with the branch defaulting to current `HEAD`. Since
`HEAD` is the upper branch, the replay range is empty and the branch is **hard-reset onto
the lower branch, silently discarding every commit it owned** - and the next line
force-pushes that. Never run the rebase with an unverified value in that slot. If Step 0's
baseline is missing for a link, recover the fork point from the reflog
(`git -C <repo-path> reflog show origin/<lower-branch>`, pick the entry from before the fix
push, then `merge-base` against it) and confirm it with the engineer, or stop.

**Rebase rules (Path B):**

- Lease pinned to the Step 0 OID, never bare `--force-with-lease`, never plain `--force`. If
  the lease fails, someone or something else moved the branch - stop and report.
- A rebase conflict is a **full stop**. Run `git rebase --abort` and report which branch
  conflicted and on what files. Resolving a conflict changes code nobody reviewed, and you
  must not do that unattended.
- **`--abort` only unwinds the CURRENT rebase.** Links you already force-pushed stay pushed,
  so the stack is left PARTIALLY restacked - never report it as untouched. Say exactly which
  links completed, which one conflicted, and which are still on their old base, so the
  engineer knows the real state before they resume by hand.
- A branch held by another worktree can only be rebased from that worktree's path - use
  the Step 0 map.
- After the last link, re-run the Step 0 `rev-list --left-right --count` check across the
  whole chain and confirm every internal link reads `0 <n>`.

If no fixes landed on any branch, skip this step entirely - unless the Step 0 baseline
already showed a non-zero link, in which case propose the restack on its own.

## Step 7: Report locally (the deliverable)

Print the `/pr-self-review` Step 6 table, plus the Owner PR column:

```markdown
## Stack feedback triage - <X> fixed, <Y> false positives, <Z> need you

| # | Owner PR | Source | Anchor | Verdict | Action / Evidence |
|---|----------|--------|--------|---------|-------------------|
| F1 | #1201 | coderabbitai (inline) | offer-phone.tsx:59 | VALID | Fixed - resync on visibilitychange |
| F2 | #1203 | self-review | landing-intro.tsx:28 | FALSE_POSITIVE | Structural clone of the sibling section; verified identical |
| F3 | #1202 | jane-doe (review) | landing-intro.tsx:5 | NEEDS_HUMAN | Copy decision - competing label wording is the design team's call |
```

Then, in this order:

1. **Restack result** - a row per link with its before/after `left-right` counts, the
   branches force-pushed, and the new head SHA of each.
2. **Merge order** - the chain bottom to top, and whether it is landable as-is.
3. **CI** - every PR re-runs CI after a restack; say which PRs are now pending and that the
   stack should not land until they are green.
4. **Paste-ready replies** for each FALSE_POSITIVE and NEEDS_HUMAN item, naming the PR each
   belongs on. You never post these; the engineer does.
5. **Out-of-scope residue** from Step 4's 5d check, if any.

Close with the reminder that unresolved threads on GitHub are theirs to reply to and
resolve, and that a force-pushed branch marks prior review comments as outdated - a
reviewer who already approved may need to re-approve.

## Pre-PR stack mode (branches exist, PRs do not)

Same shape, sourced from local branches. Reconstruct the chain from branch topology
(`git log --oneline --graph --boundary <branch-a>...<branch-b>`, or the branch names'
tracking config) and confirm the order with the engineer before proceeding - branch
topology is far more ambiguous than a PR's declared base, and getting the order wrong
puts fixes on the wrong layer.

Then run Steps 2, 3 and 5 with branches substituted for PRs everywhere - Owner PR becomes
Owner **branch**, and the tip worktree is just the top branch (no `pull/<N>/head` fetch, since
there is no PR to fetch). **Skip Step 1 entirely** (no PR means no feedback channels; you are
the only source) and **skip Step 4's 5d** check, which reads PR descriptions for the stated
goal - ask the engineer for it instead if it matters.

**Do not push or restack.** Report the chain, the findings with their owner branches, and
leave the fixes uncommitted so the engineer can review with `git diff` and open the stack
through their normal flow. Skip Steps 6 and 7's restack section entirely.

## Common gotchas

- `git rev-list --left-right --count A...B` prints `<commits only in A>  <commits only in B>`.
  With A = the lower branch and B = the upper branch, the LEFT number is how far the UPPER
  branch is behind and must be zero. "Behind/ahead" describe the RIGHT ref; naming them after
  the left one inverts every conclusion.
- `OLD_BASE` comes from the Step 0 baseline, captured before any fix landed - never
  recomputed at rebase time, when the fix has already moved the fork point. An empty value
  in that slot silently hard-resets the upper branch; see the guard in Step 6.
- GitHub auto-retargets a stacked PR's base to the default branch when its base branch
  merges. A chain discovered before a merge can be stale minutes later - re-discover rather
  than trusting a cached ordering.
- Force-pushing marks existing inline review comments as outdated and can dismiss
  approvals depending on branch protection. Warn the engineer; never dismiss or re-request
  review yourself.
- `gh pr list --base/--head` returns only OPEN PRs. If a chain walk terminates
  unexpectedly early, check whether the base branch was merged or deleted.
- A branch checked out in another worktree cannot be rebased from the current one - git
  refuses outright. Always use the Step 0 branch → path map.
- Never `git rebase -i` - interactive flags are unsupported in this environment and will
  hang.
