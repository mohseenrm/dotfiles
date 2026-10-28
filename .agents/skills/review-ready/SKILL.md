---
name: review-ready
description: Prepare your pull request or PR stack for review by investigating findings, fixing only confirmed issues within PR scope, enforcing one commit and size limits per PR, verifying, rebasing, pushing, and updating descriptions. Post a concise change summary when a previously reviewed PR changes during the run.
---

# Review Ready

Execute the workflow immediately. The target may be a PR number, URL, or the current
branch's open PR.

## Arguments

- No arguments: prepare the PR or stack, push it, and update each PR description. For each
  PR that already had a review and receives file changes during this run, post one concise
  post-review update as described in section 8. Invoking this skill authorizes that comment.
- `post`: explicitly request the same post-review update. The existing-review and file-change
  conditions still apply; this does not add a second comment or enable comments on unreviewed PRs.
- A PR number or URL may appear with either mode.

Neither mode authorizes resolving threads, dismissing reviews, merging, changing draft
state, or requesting reviewers. Never post a summary to an unreviewed PR.

## Completion contract

Do not call the work review-ready until every PR in scope satisfies all of these:

- Its delta from its declared base is exactly one commit.
- Its GitHub `additions + deletions` is less than 1000. A PR may exceed the limit only when
  every changed file and every changed hunk is exclusively test coverage, test fixtures,
  or snapshots. A PR mixing production changes with tests has no exception.
- The diff is one coherent concern with no unrelated cleanup, formatting churn, generated
  artifacts, or opportunistic refactors.
- If the PR refactors a developer-facing surface, the finished design improves that
  surface's ergonomics within the same scope: clearer types or naming, simpler call sites,
  useful errors, or focused documentation/tests as appropriate. Do not invent unrelated DX
  work for a non-refactor PR.
- Every unresolved review thread has been read and investigated against current code.
  Confirmed issues within PR scope are fixed; out-of-scope, already-fixed, incorrect, and
  ambiguous items are reported with evidence. A blocking item that cannot be fixed within
  scope prevents readiness; it does not authorize expanding the PR. Never resolve a thread
  or silently overrule a human.
- The relevant tests, type checks, linters, and builds pass for each independently
  mergeable PR.
- A fresh adversarial review reports no CRITICAL, HIGH, or MEDIUM findings.
- Each branch is rebased onto its current base, pushed, and its PR description accurately
  describes the final delta.
- Each previously reviewed PR with file changes from this run has one post-review update
  describing those changes.

If a gate cannot be met, stop and report the evidence. Do not weaken the gate or claim the
PR is ready.

## 1. Resolve and guard the scope

Require `git`, `gh`, and authenticated GitHub access. Resolve the repository explicitly and
pass `-R OWNER/REPO` to every `gh pr` command. Resolve an omitted PR from the current branch.
Confirm that every target PR is open and authored by the authenticated user.

Record before changing anything:

- the current branch and worktree path;
- `RUN_STARTED_AT`, used to distinguish existing reviews from feedback added during this run;
- each PR's number, URL, title, body, base and head branch, head SHA, additions, deletions,
  changed files, and draft state;
- `START_HEAD` and the direct-base diff for every branch, used to identify this run's changes;
- the remote head SHA used for a later `--force-with-lease`.

Inspect `git status --porcelain` in every involved worktree. Stop on uncommitted changes
unless the user explicitly included them in this preparation run. Never stash, discard, or
publish unrelated work.

Fetch the remote. If a remote branch moved after metadata was captured, refresh all
baselines before editing.

### Detect stacks

A non-default base alone does not prove a stack. Walk open PRs in both directions: find a
PR whose head is the target's base and PRs whose base is the target's head. Accept links
only within the same repository. Repeat until the complete chain is known.

When a chain exists, load and follow the `gh-stack` skill for stack discovery, navigation,
rebasing, and pushing. Work bottom-up and evaluate every PR against its direct base. A fix
belongs on the lowest PR that owns the affected code. After a lower branch changes, restack
every branch above it before further review.

If an unstacked PR exceeds the size gate or contains multiple separable concerns, propose a
bottom-up split with the exact branch/PR boundaries. Converting an existing PR into a stack
changes shared PR structure, so obtain confirmation before doing it. Use `gh-stack` after
confirmation. Do not pretend an oversized unsplit PR is ready.

## 2. Establish the baseline and assess scope

For each PR, inspect both GitHub metadata and the actual direct-base diff:

```bash
gh pr view <PR> -R OWNER/REPO \
  --json number,url,title,body,state,isDraft,author,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles
git diff --stat <base>...<head>
git diff --numstat <base>...<head>
git rev-list --count <base>..<head>
git diff --check <base>...<head>
```

Read the complete diff and enough surrounding code to understand behavior. Write down the
PR's single purpose, out-of-scope changes to remove, validation commands, commit count, and
line count. For a claimed test-only exception, inspect all files and hunks rather than
inferring it from filenames.

Use the PR's purpose, direct-base diff, linked requirements, and repository contracts to
define its scope. A fix belongs here when it addresses a defect introduced or exposed by
this PR, or is necessary for the intended change to work correctly, including focused tests.
Sharing a file or being mentioned by a reviewer is not enough. Leave unrelated pre-existing
bugs, cleanup, and broader redesigns out of the fix set. For a stack, attribute each issue
to the lowest PR that owns it.

Complete the investigation in section 3 before editing files or rewriting history. Include
proposed changes for readiness gates in the same scope assessment.

## 3. Investigate feedback and decide what to fix

Fetch unresolved review threads with pagination. Include root comments and replies because
a reply may contain a rebuttal or a revised request:

```bash
gh api graphql --paginate \
  -f owner=OWNER -f repo=REPO -F pr=<PR> -f query='
query($owner:String!,$repo:String!,$pr:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:50,after:$endCursor){
        pageInfo{hasNextPage endCursor}
        nodes{
          id isResolved isOutdated path line
          comments(first:50){
            pageInfo{hasNextPage endCursor}
            nodes{author{login} createdAt body}
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
```

If a thread's comments have another page, fetch the remaining replies using that thread's
node ID and comment cursor. The outer `--paginate` only paginates review threads.

Also read review bodies, top-level comments, and failing checks. Filter bot summaries and
status-only messages from the findings list, but retain human requests and actionable bot
findings.

Before editing, record `HAD_EXISTING_REVIEW` separately for each PR and retain the review
IDs or links that support it. Count a submitted GitHub review (human or bot, with a
non-null `submitted_at`) or a top-level comment containing substantive code-review findings.
The review's submission or comment's creation must precede `RUN_STARTED_AT`.
Pending reviews, review requests, CI status messages, ordinary discussion, and previous
readiness updates do not qualify. Read the paginated reviews and comments, for example:

```bash
gh api --paginate repos/OWNER/REPO/pulls/<PR>/reviews
gh api --paginate repos/OWNER/REPO/issues/<PR>/comments
```

Freeze this flag for the run. An adversarial pass performed during this run does not turn
an unreviewed PR into a previously reviewed PR for section 8.

For each item, verify the claim by reading current code, callers, tests, and relevant
contracts. Reproduce the failure or establish a concrete failing path when practical;
severity or reviewer wording alone is not proof. Decide whether a change is warranted and
whether this PR owns it before adding it to the fix set. Classify it as:

- `FIX_IN_SCOPE`: confirmed issue within this PR's scope; make the smallest correct fix.
- `OUT_OF_SCOPE`: valid issue outside this PR's purpose or owned delta; report the evidence
  and a suggested follow-up without implementing it or opening an issue automatically.
- `ALREADY_FIXED`: cite the current code that addresses it.
- `FALSE_POSITIVE`: use only for bot feedback and cite contrary evidence.
- `NEEDS_HUMAN`: use for design choices, ambiguous requests, conflicting feedback, and any
  human feedback that appears incorrect. Provide a concise suggested reply.

Record a concise assessment with the source, verdict, evidence, scope rationale, and proposed
fix and validation where applicable. Complete it for the gathered findings before making
edits. Investigate uncertain claims further; if they remain unproven, report the uncertainty
without treating them as confirmed fixes. Apply this assessment to new findings throughout
the run, including CI failures and adversarial findings.

Never mutate, reply to, or resolve review threads as part of this skill.

## 4. Make the diff reviewable

Apply only assessed `FIX_IN_SCOPE` edits and the scoped changes needed for readiness gates.
Preserve the PR's single purpose. Remove unrelated churn already in the PR instead of adding
unrelated fixes. Keep generated output only when the repository requires it to ship with its
source change. If a blocking issue requires expanding scope, report it and stop before that
edit; do not silently broaden the PR.

For refactors, inspect the affected developer workflow and improve DX only inside that
surface. Prefer concrete reductions in cognitive or mechanical work over new abstractions.
Examples include stronger types replacing caller guesswork, fewer required steps at call
sites, actionable boundary errors, and tests that make the intended API obvious.

Run focused validation after edits. Use repository-native commands discovered from CI,
package scripts, make targets, or contributor docs. Every PR in a stack must pass on its
own, not only at the stack tip. Run broader validation when the change affects shared
contracts or build configuration.

## 5. Adversarial review loop

Load and follow the `adversarial-reviewer` skill against the current direct-base diff. For
stacks, review each PR delta and then the composed tip. Verify each finding against the
code and apply section 3's scope assessment before editing.

Fix confirmed CRITICAL, HIGH, and MEDIUM findings classified `FIX_IN_SCOPE`, rerun affected
validation, and run a fresh adversarial pass. LOW findings may remain. Report out-of-scope
findings without implementing them; if a confirmed finding above LOW remains, report the
blocker without claiming readiness. Stop successfully only when a fresh pass contains no
finding above LOW.

Cap the loop at three adversarial passes. If a confirmed issue above LOW remains after the
third pass, report it and stop without claiming readiness. This cap prevents an unbounded
review/fix cycle while preserving the completion gate.

After the clean pass, rerun the final validation suite and `git diff --check`.

## 6. Produce one commit per PR

Before rewriting history, preserve each old head SHA in the report and verify that the
working diff still matches the intended PR delta.

- If the PR already has one commit, stage explicit paths and amend that commit. Preserve a
  good existing message; otherwise use the final PR title as a concise commit subject.
- If it has multiple commits, squash the direct-base delta into one commit non-interactively
  using the verified merge base. Never use interactive rebase.
- For a stack, perform this bottom-up and then use `gh-stack` to restack upper branches.

Rebase each finished branch onto the latest remote version of its declared base. Re-run
the one-commit count, size gate, diff check, and relevant validation after the rebase.

History rewrites and pushes affect shared state. Show the exact branches, old and new SHAs,
and whether each push will be normal or forced, then obtain confirmation immediately before
the first push. Use a normal push when possible. For rewritten branches, use
`--force-with-lease` pinned to the remote head SHA captured after the last fetch. Never use
plain `--force`, a bare unpinned lease after fetching, or `--no-verify`.

After pushing, fetch and prove that each remote head equals the intended local head and that
each PR still contains exactly one direct-base commit. For stacks, prove every upper branch
contains its current lower branch and every PR still shows only its owned delta.

## 7. Update PR descriptions

Update each PR body to match its final delta. Preserve applicable repository template
sections, issue links, rollout notes, and checklists. Remove stale claims and completed work
that is no longer in the diff. Include, as appropriate:

- what changed and why;
- the implementation shape and important tradeoffs;
- how it was tested, using the commands and outcomes actually observed;
- risks, rollout, screenshots, migrations, or stack dependencies when relevant.

Render the complete body in a temporary Markdown file, inspect it, then use
`gh pr edit <PR> -R OWNER/REPO --body-file <file>`. Updating descriptions is part of normal
mode and needs no additional prompt. Delete temporary files after use.

## 8. Post-review update

After pushing and verifying the final result, post one short update on each PR whose
recorded `HAD_EXISTING_REVIEW` is true and whose files changed during this run, including
tests and documentation. This applies with or without `post`. Skip unreviewed PRs and PRs
with no file changes; a rebase, squash, description edit, or verification-only run does not
by itself warrant a comment.

For each changed PR, compare its recorded `START_HEAD` tree with its final head. Post one
comment summarizing only changes made during this run, not the entire PR. If the starting
tree and final tree are identical, skip the comment. Check the original and final direct-base
diffs to exclude changes merely inherited from a rebase or lower stack PR. In a stack, put
each change summary only on the PR that owns it; evaluate review eligibility per PR.

Use simple, styled Markdown: a short bold label and a few concrete bullets, normally under
150 words. Link the relevant review feedback when useful, use inline code for symbols or
commands, and include only validation actually run. Use this shape, omitting empty fields:

```markdown
**Post-review update**

- Fixed <concrete behavior> in `path/to/file` after review.
- <Another change made during this run, if needed.>
- **Verified:** `<actual command>` - passed.
```

Use fenced code blocks with language tags only for short snippets where syntax materially
clarifies a change, such as `diff`, `typescript`, or `ruby` as appropriate. Avoid a recap of
the whole PR, decorative badges, raw tool logs, and generic prose. Write the body to a
temporary Markdown file and inspect it, then post with
`gh pr comment <PR> -R OWNER/REPO --body-file <file>`. Posting this eligible update is part of
the invoked workflow and needs no additional prompt. Capture its URL; if a post attempt
has an uncertain outcome, check PR comments before retrying to avoid duplicates. Delete
temporary files after use.

## 9. Final evidence

Report per PR:

- final URL, base/head, and remote head SHA;
- commit count and additions + deletions, including the evidence for any test-only
  exception;
- validation commands and their actual results;
- findings assessment, including unresolved feedback and out-of-scope follow-ups;
- adversarial pass count and remaining LOW findings;
- rebase and push result;
- PR description update result;
- whether a post-review update was published, with its URL, or why it was skipped.

Also report pending or failing remote checks. Do not wait indefinitely for CI unless the
user separately asks for monitoring. Do not mark a draft PR ready, request reviewers,
resolve threads, or merge it unless explicitly asked.
