---
name: pr-review-stack
argument-hint: "<pr-url-or-number> [more PRs in the stack...]"
description: Review a STACK of teammate PRs - a chain where each PR's base branch is the previous PR's head branch, not the default branch. Discovers the full chain from any single member, reviews each PR's own delta, then runs the stack-level pass that per-PR review structurally cannot produce - cumulative end-state coherence, cross-PR interactions, transient breakage at each intermediate merge, and merge-order safety. Posts ONE checkbox review comment per PR attributed to the PR that introduced each finding, never the same finding twice, and recommends APPROVE or HOLD per PR with blocking findings propagating upward. Always shows every comment and asks before posting. Triggers on "review this stack", "review these stacked PRs", "review my teammate's PR stack", "these PRs are stacked", "review the stack bottom-up", or any pasted list of PRs that turns out to be a chain.
---

# PR Stack Review (chained PRs, per-PR comments + stack-level pass)

**EXECUTE THIS COMMAND IMMEDIATELY** - Do not explain what this command does. Execute the workflow below right now.

A **stack** is a chain of PRs where each PR's `baseRefName` is the previous PR's
`headRefName` rather than the repo's default branch. Reviewing a stack is NOT the same as
reviewing each PR in isolation, and it is NOT the same as reviewing the union of the
diffs. This command does both halves and keeps them straight.

Everything in `/pr-review` still applies - the confirmed-findings-only bar, the
adversarial verification gate, unblock-by-default philosophy, the severity buckets, the
comment format, the hard rules. This command adds the stack layer on top and reuses that
machinery by reference rather than restating it.

**⛔ HARD RULES (the `/pr-review` rules, plus three stack-specific ones):**

1. **One findings comment per PR, ever.** Re-reviews UPDATE in place.
2. **Show before posting.** Print every body and every recommendation, then ask.
3. **The engineer owns the verdict.** You recommend; they decide.
4. **Only confirmed findings.** Everything survives adversarial verification or it does
   not ship.
5. **Never touch any branch's content** - no pushes, no edits, no merges, no rebases.
6. **Attribute each finding to the PR that INTRODUCED it.** Never post the same finding on
   two PRs in the stack. If PR 2 merely inherits a defect from PR 1, it belongs on PR 1.
7. **Never flag a file as missing/unused when a later PR in the stack resolves it.** A
   component still imported at PR 1 and deleted in PR 2 is a CORRECTLY ORDERED stack, not
   a defect.
8. **Blocking propagates upward.** A Blocking finding on PR N holds PR N *and every PR
   above it*, because they cannot merge until it does. Say so explicitly in the report.

## Step 1: Discover the full chain

`$ARGUMENTS` may be one PR or several, in any order, as URLs or bare numbers. You do NOT
need the whole stack from the user - **any single member is enough to discover the rest.**

For every PR given, resolve `OWNER/REPO` + number (same rules as `/pr-review`
Step 1), run the self-review guard (`gh api user --jq .login` vs the PR author) and the
`state == OPEN` check, then read its branch pair:

```bash
gh pr view "$PR" --repo "$OWNER/$REPO" --json number,title,author,state,isDraft,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles
```

**`gh stack` can do the discovery - with one caveat that matters here.** GitHub's official
extension (`github/gh-stack`, <https://gh.io/stacks>) resolves a whole stack from a single PR
number or URL, including stacks it has never seen locally. But `gh stack checkout` **switches
the engineer's current branch and writes local tracking state**, which violates hard rule 5
for a command that only reviews someone else's work.

So:

- **Already tracked locally** - `gh stack view --json` gives you the ordered chain and a
  per-branch `Needs rebase` flag in one call, which is Step 5e for free. **Validate it
  first:** `gh stack view` takes no PR or repository argument, so it reports whatever stack
  happens to be tracked in the current checkout - which may be a different stack entirely.
  Require its JSON to name this repository AND to contain exactly the PRs you were asked to
  review. On any mismatch, empty output, or non-zero exit, discard it and use the walk below.
- **Not tracked** (the normal case for a teammate's stack) - do NOT run `gh stack checkout`
  unprompted. Use the read-only walk below. Offer the engineer `gh stack checkout <PR>` as a
  faster option and let them decide; it is their working tree.

```bash
gh extension list | grep -q gh-stack && gh stack view --json 2>/dev/null
```

**Walk the chain in both directions** from each seed PR:

```bash
# Downward (what is this PR built on?) - is its base another open PR's head?
gh pr list --repo "$OWNER/$REPO" --state open --head "<baseRefName>" --json number,baseRefName,headRefName,title

# Upward (what is built on this PR?) - does any open PR use this PR's head as its base?
gh pr list --repo "$OWNER/$REPO" --state open --base "<headRefName>" --json number,baseRefName,headRefName,title
```

Repeat until both walks come up empty. The chain is ordered by construction: the **bottom**
is the PR whose `baseRefName` is the repo default branch; each subsequent PR's
`baseRefName` equals the previous one's `headRefName`.

Branch names alone can produce a false edge - a fork's PR can carry the same `headRefName`
as a branch in the upstream repo. Add `headRepository,headRepositoryOwner` to the `--json`
list and only accept an edge when the candidate is in the same repository. If a walk returns
more than one match for a single link, the chain is ambiguous - stop and show the engineer
the candidates rather than guessing.

**Not actually a stack?** The test is the discovered chain length, NOT whether a base is
the default branch. If both walks came up empty for every PR given - no PR's base is
another open PR's head, and no PR's head is another open PR's base - then nothing chains:

- **One PR, chain length 1** - it targets a long-lived release or integration branch, which
  is not a stack. Hand back to `/pr-review` for a normal single-PR review.
- **Several PRs, all chain length 1** - a batch of independent PRs. Hand back to
  `/pr-review` Batch mode.

Say which in one line and hand off. Do not run the stack pass on unrelated PRs; its whole
premise is that the diffs compose. Note that a chain of length 1 has no "bottom" in the
ordering sense - if you find yourself unable to order the chain, that is this case.

**Mixed input?** If the PRs given resolve to more than one disconnected chain - some chain
together, others stand alone - do not review them as one stack; the composition premise only
holds inside a single chain. Report the grouping you found, review the longest chain here,
and tell the engineer the leftovers need `/pr-review` (or a second run of this command
per additional chain). Never merge two independent chains into one stack-level pass.

**Partial stack?** If discovery finds open PRs the user did not name, tell them the full
chain you found and review all of it - a stack member reviewed without its base is
reviewed against a fiction. If a member is closed/merged or authored by you, mark it
skipped in the final table and keep its position in the chain.

Print the discovered chain before doing any review work:

```text
Stack (bottom to top):
  #1201  main                       <- feat/remove-legacy-toggle
  #1202  feat/remove-legacy-toggle  <- feat/update-chart-widget
  #1203  feat/update-chart-widget   <- feat/add-summary-module
```

## Step 2: Set up one worktree per PR, plus the tip

Resolve the local checkout by discovery (`/pr-review` Step 2 - verify `origin`
matches; never assume a layout). Then create a detached worktree per PR, exactly as
`/pr-review` Step 3 does, namespaced per repo + PR so parallel setup cannot race:

```bash
git -C <repo-path> worktree remove --force /tmp/pr-review-<repo>-<PR> 2>/dev/null; rm -rf /tmp/pr-review-<repo>-<PR>; git -C <repo-path> worktree prune
git -C <repo-path> fetch origin "+pull/<PR>/head:refs/pr-review/<PR>"
git -C <repo-path> worktree add /tmp/pr-review-<repo>-<PR> refs/pr-review/<PR> --detach
```

**The tip worktree is the merged end state - once you have confirmed the stack is not
stale.** Because each PR is based on the one below it, the topmost PR's head contains every
commit in the stack **provided every internal link is zero-behind its base**. When that
holds you need no synthetic merge - the tip worktree *is* what the default branch looks
like after the whole stack lands, and every Step 5 check reads from there.

If a lower PR has moved since an upper PR was last rebased, the tip is missing those
commits and is a composition that will never ship. **Run Step 5e FIRST** and only proceed
to 5a-5d once every link reads zero-behind; otherwise report the stack as stale and skip
the end-state checks rather than emitting findings about a fiction.

Always remove every worktree and ref at the end (Step 8), even on failure.

## Step 3: Per-PR delta review

**`gh pr diff` on a stacked PR returns only that PR's delta against its own base branch,
not against the default branch.** That is exactly the right scope for per-PR findings -
review it as-is; do not try to diff against the default branch.

For each PR in the chain, run the normal `/pr-review` pipeline - Step 4 context
gathering (metadata, diff, `gh pr checks`, and the unresolved-review-threads GraphQL
query), Step 5 routed review agents, Step 6 adversarial verification, Step 7 severity
calibration. Triage each PR light vs heavy the way Batch mode does; uncertainty routes
heavy.

Two stack-specific instructions for the review agents, added to the standard stance:

```text
STACK CONTEXT: this PR is part of a stack. Its base branch is another open PR
(#<base-pr>), so the diff you are given is this PR's DELTA ONLY.

- Do NOT flag something as broken because a later PR in the stack has not landed yet.
  A symbol/file/route that is still referenced here and removed one PR up is correct
  ordering, not a defect.
- Do NOT flag something already introduced by a LOWER PR in the stack. Findings belong
  to the PR that introduced them. If the defect is in code this PR merely calls, say so
  and name the lower PR.
```

Because the PRs can be set up and reviewed independently, run their pipelines in parallel -
but keep each PR's findings strictly separate, and stop before posting.

## Step 4: Intermediate-merge safety (per link in the chain)

A stack lands bottom-up, one merge at a time. Each intermediate merge must leave the
default branch coherent on its own. For each PR N in the chain, check its worktree:

1. **No dangling references.** Grep the tree for every symbol/path the PR removed or
   renamed. Zero hits outside the PR's own diff.
2. **The inverse is not a defect.** Something the PR *adds* that nothing consumes yet is
   fine only if a later PR in the stack consumes it, or if a dead-code detector in CI
   (Knip, unused-export lints, `deadcode`) passes. State which one clears it. If neither
   does, that IS a finding - an unreferenced addition landing on main.
3. **CI is per-PR evidence.** Read each PR's `gh pr checks` independently. A green check
   on the tip says nothing about PR 1 merging alone.

Note the CodeRabbit gap while you are here: the app posts **"Review skipped - reviews are
disabled for this base branch"** on any PR whose base is not the default branch, so every
PR above the bottom of a stack gets **zero** CodeRabbit signal. Say this in the final
report so the engineer knows the automated coverage was uneven, and weight your own review
of the upper PRs accordingly.

## Step 5: The stack-level pass (the reason this command exists)

Run these against the **tip worktree** from Step 2. These are the findings per-PR review
structurally cannot produce, because each one is a property of the composition rather than
of any single delta. Do this sequentially and think about each - it is a small, high-value
set, not a checklist to skim.

**Order matters - do 5e first.** 5a-5d read the tip as the merged end state, which it only
is when every internal link is zero-behind (Step 2). If 5e shows a stale link, stop there
and report it; the composition you would otherwise review is one that will never ship.

**5a. Cumulative end-state coherence.** Read the fully-composed result of everything the
stack touches - the whole file, not the diff hunks. Ask:
- Does the union duplicate anything? (The same section/component/route added twice by
  different PRs in the stack, or added by one PR when it already existed elsewhere.)
- Is the copy coherent end to end? An intro paragraph written for the old content, a label
  changed in PR 2 that contradicts a heading added in PR 3, a heading hierarchy that only
  breaks once all the pieces are present.
- Does the composed result match its sibling surfaces? If the stack makes route B mirror
  route A, diff the two and confirm ordering, labels, and copy actually match. This cuts
  both ways - it is how you confirm an ordering choice is *correct* as well as how you
  catch a mismatch.

**5b. Cross-PR interactions.** A component introduced in PR 1 and reused in PR 2 was tuned
for PR 1's container. Check the reused thing against its NEW container's constraints
(fixed heights, overflow, grid definitions, provided context/providers, required ancestor
state). Compare against what the new container held *before* the stack - if the old
occupant had the same characteristics, there is no regression and you must not flag it.

**5c. Namespace and global collisions across the stack.** When one PR adds a global (CSS
class, id, event name, feature-flag key, exported symbol, DB index name) that another PR's
code also defines, prove whether the two can ever co-occur. Enumerate the actual routes /
call sites for each - disjoint render sets mean no collision and the finding is refuted.

**5d. Does the union deliver the stated goal?** Take the goal from the user's framing and
the PR titles/descriptions, then verify it against the tip worktree - typically a grep for
whatever the stack claims to remove or rename. Residue on surfaces outside the stated
scope is **not** a PR finding (it is pre-existing and each PR delivers what it claims), but
it IS something the engineer needs. Report it locally, in its own section, never in a
posted comment.

**5e. Merge-order safety.** Two commands, both cheap, both decisive:

```bash
# Every link must be zero-BEHIND its base. Left number is commits the base has
# that the PR lacks; it must be 0 at every link or the stack needs a rebase.
git -C <repo-path> rev-list --left-right --count refs/pr-review/<lower-PR>...refs/pr-review/<upper-PR>
# ... and for the bottom PR, against the default branch:
git -C <repo-path> rev-list --left-right --count origin/<default>...refs/pr-review/<bottom-PR>

# Has the default branch touched anything the stack touches since the merge-base?
# Empty output means no conflict risk; non-empty means the stack needs a rebase
# before it can land cleanly.
MB=$(git -C <repo-path> merge-base origin/<default> refs/pr-review/<bottom-PR>)
git -C <repo-path> log --oneline $MB..origin/<default> -- <every file touched anywhere in the stack>
```

The second command is a fast path-overlap heuristic - empty output proves no conflict, but
non-empty output only means *maybe*. To settle it, do the real merge (git 2.38+, writes
nothing to the worktree; exit 0 clean, 1 conflicts, other = error):

```bash
git -C <repo-path> merge-tree --write-tree --quiet origin/<default> refs/pr-review/<bottom-PR>
```

The bottom PR being N commits behind the default branch is normal churn and not a finding
**as long as** the conflict check comes back clean. A non-zero left count at any *internal* link
means the stack is internally inconsistent - that is a real finding on the upper PR, and
it is Should Fix Before Merge (the fix is a rebase, and merging as-is would land a state
nobody reviewed or CI'd).

**Where stack-level findings go.** Attribute each to the PR that introduced the
interaction - usually the *later* PR, since it is the one that created the composition.
A finding that belongs to no single PR (a genuine emergent property of the whole chain)
goes in the local report to the engineer, not in a posted comment.

## Step 6: Compose per-PR comments

Identical format to `/pr-review` Step 7 - the hidden `<!-- growth:pr-review -->`
marker, the attribution line, then severity sections with checkbox findings, or the plain
`lgtm` body when nothing survived. Use the same marker so `/pr-review` re-review
mode can find and update these comments later.

Per-PR verdicts, then the stack verdict:

- Per PR - **APPROVE** with zero Blocking findings, **HOLD** otherwise.
- Stack - if any PR is HOLD, every PR **above** it is effectively held too, even when its
  own body is clean. Recommend APPROVE on those upper PRs if their own code is clean (the
  approval is still accurate and unblocks them the moment the base is fixed), but state
  plainly in the report that they cannot land until PR N is resolved.

## Step 7: One consolidated confirmation, then post bottom-up

Print, in stack order bottom to top - each PR's full comment body, its recommendation, and
a one-line rationale. Then the stack-level section - end-state findings, merge-order
result, the CodeRabbit coverage gap, and anything noted-but-not-posted (out-of-scope
residue, refuted candidates, skipped noise).

Then ask ONCE via AskUserQuestion:

- "Post all as recommended" - APPROVE PRs get `--approve` with their body, HOLD PRs get
  `--comment` with theirs.
- "Decide per PR" - re-ask with the `/pr-review` Step 8 options, one question per
  PR (up to 4 per AskUserQuestion call).
- "Approve only the clean PRs above/below" - useful when one PR in the chain needs work
  and the rest should not wait.
- "Post none - I'll handle it".

**Re-check eligibility right before posting** - each PR still `OPEN`, each `headRefOid`
unchanged. A moved head anywhere in the stack invalidates the stack-level pass too, not
just that PR's anchors - refresh the worktrees, re-verify, and re-ask if anything changed.

**Post bottom-up**, one submission per PR, so the approval order matches the merge order the
engineer will follow. `gh pr review` is for a PR's FIRST findings comment only - any PR that
already carries a `<!-- growth:pr-review -->` body from a previous round is updated in place
via the reviews PUT endpoint (see Re-review mode), never re-posted:

```bash
gh pr review "$PR" --repo "$OWNER/$REPO" $FLAG --body-file /tmp/pr-review-<repo>-<PR>-body.md
```

## Step 8: Clean up and report

```bash
git -C <repo-path> worktree remove /tmp/pr-review-<repo>-<PR> --force
git -C <repo-path> update-ref -d refs/pr-review/<PR>
```

Every PR, always, even if the run was aborted. Then close with one table in stack order:

| PR | Title | Class | Blocking | Should Fix | Medium | Gaps | Nits | Recommendation | Posted as |

...followed by the merge order, the stack-level findings, and the noted-but-not-posted
section.

## Re-review mode

Follow `/pr-review` Re-review mode per PR (compare against your prior review's
`commit_id`, verify prior findings FIXED vs STILL_OPEN, review only the delta, update the
existing comment in place via the reviews PUT endpoint - never a second findings comment).

Two stack-specific additions:

- **Re-run Step 5 in full, every time.** New commits on ANY PR change the composed end
  state, so the stack-level pass is never cacheable - even for a PR whose own delta did not
  move.
- **Re-run Step 5e in full, every time.** The author fixing a lower PR is exactly what
  leaves the upper PRs behind their base. A stack that was internally consistent last round
  routinely is not after a round of fixes, and that is the single most common real defect
  a stack re-review catches.

## Common gotchas

- `gh stack` (`github/gh-stack`) is the official tool for this shape of work and is worth
  suggesting to the author - `gh stack sync` cascade-rebases and pushes atomically, which is
  what keeps a stack from going stale between rounds. Reviewing is still read-only here:
  `gh stack checkout` mutates the local checkout, so never run it on a teammate's stack
  without asking.
- **CodeRabbit is absent above the bottom PR** - "reviews are disabled for this base
  branch". Bot-authored PRs also get "bot user not eligible for review". Neither is a
  failure; both mean your own review is the only signal.
- `gh pr diff` on a stacked PR is the delta against its base branch. Do not "fix" this by
  diffing against the default branch - you would re-review the lower PRs' code and post
  duplicate findings.
- `gh pr list --base <branch>` / `--head <branch>` only returns OPEN PRs by default. A
  merged base is why a chain walk can terminate early - check whether the base branch still
  exists before concluding a PR is the bottom.
- A stack whose bottom has already merged is no longer a stack: the next PR up will
  re-target the default branch (GitHub does this automatically), so re-discover the chain
  rather than trusting a cached ordering.
- `git rev-list --left-right --count A...B` prints `<commits only in A>  <commits only in B>`.
  With A = the base and B = the PR, the LEFT number is how far the PR is BEHIND its base and
  must be zero; the right number is how far ahead it is and can be anything. "Behind/ahead"
  describe the RIGHT ref - naming them after the left one inverts the whole conclusion.
- Worktree paths and fetch refs must stay namespaced per repo + PR. Never `FETCH_HEAD`;
  it is shared repo state and races across parallel setup.
- Review bodies cap at 65,536 characters each - that is per PR, so a large stack does not
  come close, but keep the stack-level section in the LOCAL report rather than duplicating
  it into every comment.
