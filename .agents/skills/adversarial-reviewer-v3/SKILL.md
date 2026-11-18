---
name: adversarial-reviewer-v3
description: V3 | Use for adversarial code and PR reviews, correctness audits, and requests to find bugs or tear a change apart.
---

# Adversarial Code Reviewer

Look for failure modes that a routine review would miss. Treat both the author's assurances and your own suspicions as hypotheses. Review the behavior the code actually delivers.

## Arguments

- (no args) — run the review, report findings in the conversation only. This is the default: NEVER post to GitHub, comment on a PR, or make any `gh` write call unless posting was explicitly requested.
- `explain` — run the review, then also explain every finding in plain language: what the code meant to do, what it actually does, why that hurts, and a short comment you can paste as your own. Report stays in the conversation. See "Explain Mode" below. Combinable: `explain`, `explain post`, `explain 123`.
- `post` — run the review, then publish it to the PR via `gh`: one styled summary comment plus inline review comments on the offending lines. See "Posting to GitHub" below. May be combined with a PR reference: `post 123`, `post <pr-url>`, or `post` alone (resolves the PR for the current branch).
- `post progress`: add one temporary PR comment with a random ASCII Magic GIF at the start. Do not tag anyone. Delete that comment after publishing the final review. Combinable: `post progress 123`, `explain post progress <pr-url>`. `progress` alone does not authorize posting.

Posting requires explicit opt-in: either the `post` argument, or the user asking for it in their own words ("post this to the PR", "comment on the PR"). Reviewing a PR is not a request to post. When in doubt, report in the conversation only. The review itself is read-only. Do not edit code, push changes, or create a PR.

## Process

1. **Pin scope and intent.** Use the request and available PR context to establish the contract. Compare with the specified base or the PR's actual base, including stacked PRs. Verify PR source at the pinned head. For a branch without a specified base, use its merge base with the intended integration branch. For local edits or supplied files, state the exact scope. Ask about intent only if the answer would change a finding.
2. **Review the diff once, highest risk first.** Apply all eleven lenses to each changed behavior in the same pass. Ask: How does it fail? What's missing? Which assumption breaks at 3 AM under load? Consider realistic load, dependency failure, repeat delivery, and unexpected inputs. Consider UX and accessibility for UI changes. Read surrounding code, callers, tests, or config when they establish the contract, expose an omission, or could change a finding. Batch independent reads and reuse the context you already have.
3. **Verify candidates as you go.** Find the reachable starting state, violated contract, changed path, and observable result. Look for the guard, constraint, or retry that would disprove the issue. Use targeted, safe checks when source alone cannot settle a material question. Keep security review defensive. Drop unsupported claims and duplicate symptoms. State missing evidence or coverage in `Review context`.
4. **Report and stop.** Cite the decisive `Source` and any necessary `Related sources`. Say what breaks and how to fix it. If no finding survives, say "No bugs found" and name what you checked. Skip the second pass. If the target was unavailable, report that instead. Re-review fixes only on a new request. Keep the source-link and PR head checks below.

## Adversarial Lens

Consider all eleven lenses for every change. Rule out a lens only when it does not apply to that change. Use the lens names as finding categories.

### 1. Security

- Check trust boundaries for SQL, XSS, or command injection, path traversal, SSRF, unsafe deserialization, CSRF, open redirects, and missing input validation.
- Trace authentication and authorization for the specific object and tenant (IDOR). Include alternate callers and bulk operations. Check rate limits on sensitive operations.
- Check secrets in code, logs, and errors. Look for account enumeration through error responses and sensitive timing differences.

Keep this pass defensive. Identify the missing control, preconditions, impact, and fix from source. Do not create exploit payloads, reproduce exploitation, or probe live systems.

### 2. Correctness

- Check off-by-one errors, exact cutoffs, null and undefined paths, and omitted values that take a different path from explicit null.
- Trace coercion, integer overflow, floating-point comparisons, operator precedence, inverted conditions, fallthrough, and short-circuited side effects.
- Verify that defaults, return values, ordering, and filters match the contract that callers rely on.

### 3. Concurrency

- Check race conditions, time-of-check-to-time-of-use gaps, deadlocks, missing locks, torn reads or writes, and transitions that must be atomic.
- Trace stale reads or closures, late responses that overwrite newer state, simultaneous calls with identical arguments, and duplicate or out-of-order delivery.

### 4. Edge cases

- Check empty, single-element, huge, and out-of-range inputs. Distinguish zero, negative zero, and NaN propagation.
- Trace Unicode, emoji, multibyte or right-to-left text, time zones, daylight-saving transitions, and locale-dependent parsing.

### 5. Error handling

- Trace rejected async work, broad catches, swallowed errors, and fallbacks that hide a failure from callers or retries. Check error messages for leaked internals.
- Check rollback, cleanup, and resulting state after partial failure. Trace timeouts both before and after a dependency accepts work.

### 6. Data integrity

- Check partial writes, missing transactions, schema mismatches, missing uniqueness constraints, orphaned references, and unintended cascading deletes.
- Check idempotency after duplicate delivery or an ambiguous write. Trace cache invalidation and whether migrations preserve existing data.

### 7. Performance

- Check quadratic work, N+1 queries, missing indexes or pagination, large payloads, and blocking work on a shared event loop. Estimate cost at a supported input size.
- Bound memory, fan-out, deadlines, and retries. Check backoff, cache eviction, and cleanup of connections, handles, timers, or listeners.

### 8. Backwards compatibility

- Check API and wire contracts, CLI behavior, stored formats, and downstream consumers. Trace old and new readers, writers, and workers coexisting with existing rows or queued jobs.
- Check migration and backfill order, feature flag coverage, and config across rollout and rollback.

### 9. Observability

- Check whether existing logs, metrics, and alerts expose a real failure at the decision point. Verify that operators can identify the failing branch and its impact.
- Look for silent failures, unhelpful errors, and missing audit events for sensitive actions.

### 10. Missing changes

- Check related modules, callers, config, migration scripts, and rollback steps. Look for stale public docs and tests that no longer protect a changed contract.
- Report the affected behavior or operating requirement. A missing test or documentation update alone does not establish a defect.

### 11. Design smell

- Check whether scattered edits, logic in the wrong component, tight coupling, oversized objects, or unnecessary abstractions cause a concrete defect.
- Name the broken invariant, divergence, or measurable cost. Do not report a design preference on its own.

## Output Format

Start every review with navigation context. When the target is hosted on GitHub, resolve these with read-only `gh` calls rather than constructing repository or PR URLs by hand:

```sh
gh pr view <number|url> --json number,title,url,headRefName,headRefOid
gh repo view [<owner/repo>] --json nameWithOwner,url
```

Use the explicit PR reference when the user supplied one. If it cannot be resolved, report that limitation rather than reviewing a different target. Otherwise try the current branch PR unless the user asked for local files or changes. When a PR resolves, use the owner/repository identified by its returned URL for `gh repo view` so an explicit PR from another repository cannot be mislabeled as the current checkout. Treat the returned `headRefOid` as the source of truth for both the review and every source link. Do not substitute the local branch SHA, working tree, base branch, or default branch.

Without a PR, resolve the current repository. A missing PR must not block a local or branch review. Include these entries so the user can immediately tell what was reviewed:

```markdown
## Review context

- Repository: [owner/repo](https://github.com/owner/repo)
- Pull request: [#123 — PR title](https://github.com/owner/repo/pull/123)
- Revision: [`feature-branch` at `abcdef0`](https://github.com/owner/repo/tree/<headRefOid>)
```

If the repository is not on GitHub or no PR applies, write `Repository: Not available` or `Pull request: Not available for this review` instead of inventing a link. For `Revision`, identify the local ref, working tree, or supplied files as applicable. These links belong in the conversational response in every mode, including `explain`. They do not authorize any GitHub write.

### Finding source links

Every finding against a GitHub PR must include at least one fully qualified drill-down link to the exact code that proves the claim. Build links from the repository URL and the PR's `headRefOid`:

```text
https://github.com/<owner>/<repo>/blob/<headRefOid>/<url-encoded-path>#L<start>-L<end>
```

Use a single `#L<line>` anchor for one line. Use the smallest line range that establishes the claim, and add a `Related sources` list when the finding depends on multiple locations. Link labels should be readable locations such as `src/auth.ts:42-48`; never expose a raw URL as the label.

These are source links, not links to the PR Files tab, the default branch, a local `file://` path, or an unqualified `path#L42` reference. Verify each path and line anchor against the file at `headRefOid` on GitHub before publishing the finding. If the PR head changes while reviewing, resolve the new `headRefOid`, re-check the affected claims, and rebuild all source links so one review never mixes revisions.

For a local review with no GitHub PR, keep the normal `path:line` location and state that a GitHub source link is unavailable. Never fabricate a link.

For each bug found:

```markdown
**BUG: [short title]**
Source: [path/to/file.ts:42-48](https://github.com/owner/repo/blob/<headRefOid>/path/to/file.ts#L42-L48)
Related sources: [path/to/caller.ts:10-14](https://github.com/owner/repo/blob/<headRefOid>/path/to/caller.ts#L10-L14) (only when needed)
Category: [from checklist above]
Severity: 🚨 CRITICAL | 🔴 HIGH | 🟡 MEDIUM | ⚪ LOW

[What's wrong — one or two sentences, no filler]

Trigger: [concrete scenario that hits this bug]

Fix: [minimal code change or approach — don't rewrite the function]
```

Order findings by severity (CRITICAL first). Within one severity, put the greater blast radius first.

## Severity Guide

- **CRITICAL**: Severe security impact, irreversible data loss, or a production failure that blocks safe merge
- **HIGH**: Likely significant production impact during normal use or under realistic load
- **MEDIUM**: A defect with material impact limited to an edge case or operating condition
- **LOW**: Concrete defect with limited impact

Calibrate severity against the proven impact and how likely the trigger is at realistic scale. Recheck clusters of extreme severities. Do not aim for a finding count or severity mix.

## Explain Mode (`explain` arg)

Skip this section entirely unless the user passed `explain`. When they do, run the full review as usual **and** append a plain-language walkthrough so the user can follow along and leave their own review comments in their own words. With no findings, keep the normal "No bugs found" result.

Rules for the explanation:

- Write for someone who has not read the code you read. Do not assume they remember the surrounding function.
- No jargon without a one-line definition inline. If you say "TOCTOU", immediately say what it means here.
- Explain **why it is a bug**, not just what the bug is. What did the author probably intend, and where does reality diverge?
- Give a concrete story: real values flowing through, what the user/system sees, what breaks.
- Say what a correct fix does and why it works.
- Keep each finding's explanation to a short paragraph plus the fields below. Depth over length.

For each finding, after the standard output block, add:

```
**In plain terms**

What the code is trying to do: [one sentence]
What actually happens: [one sentence, with concrete values]
Why that's a problem: [impact in user-visible terms]
Walk-through: [2-4 sentences tracing the path, naming each step]
Why the fix works: [one or two sentences]

**Comment you could leave:**
> [1-3 sentences the user can paste as their own review comment, written in their voice — plain, direct, no severity icons or template headers]
```

Keep the standard finding's `Source` and `Related sources` links immediately above this explanation. The walkthrough may add source links when it introduces a separate code location, but it must not replace the evidence links with plain `file:line` text.

Then close the review with:

```
## Follow-along summary

[3-6 sentences: what this change is doing overall, the shape of the problems found,
and what you'd want the author to answer. Refer back to the linked repository and pull
request from Review context when directing the user where to inspect the change. No
table, no severity icons — just prose.]
```

`explain` is independent of `post`: it changes what is written in the conversation, never what is posted. When both are passed, post the normal (unexplained) summary and inline comments to GitHub, and keep the plain-terms walkthrough in the conversation for the user only.

## Posting to GitHub (`post` arg)

Only when invoked with the `post` argument or when the user explicitly asked to post. Complete the full review first, show the findings in the conversation, then publish them. Before any `gh` write call, confirm with the user unless they already told you to post without asking. An explicit `post progress` invocation authorizes the single start comment, the final review, and deletion of that exact start comment. Plain `post` never sends a start comment.

### 1. Resolve the PR

```sh
gh pr view --json number,title,headRefName,headRefOid,url,baseRefName   # current branch
# or: gh pr view <number|url> --json number,title,headRefName,headRefOid,url,baseRefName
gh repo view <owner/repo> --json nameWithOwner,url
```

If no PR exists, stop and say so. Do not create one.

#### Optional start comment (`post progress`)

After resolving the PR and before reading its diff, post the start comment without any mentions.

Pick a fresh GIF with [ASCII Magic's gallery](https://www.ascii-magic.com/ascii) on each run. Use `agent-browser` in a new named session:

1. Open the gallery and click **Shuffle**. Re-snapshot and follow the selected piece's name above **Shuffle** to its detail page on the same site.
2. Under **Export**, choose **Size → Piece only, no frame**. Confirm that size is selected before using **Download → GIF**. If the option click only closes the menu, reopen it and activate the visible option by its text with a DOM click. Save the export as `progress_gif` in a private temporary directory. Verify it is a GIF and under 10 MB before attaching it.
3. Close the browser session. Attach `progress_gif` with GitHub CLI and remove the temporary file after the attempt. Do not send PR data to ASCII Magic or substitute a fixed GIF if the export fails.

```sh
progress_comment_url=$(gh pr comment "$pr_url" --body '*Checking the diff for landmines. Review incoming...*' \
  --attach "$progress_gif#Animated ASCII art from ASCII Magic")
progress_comment_id=
case "$progress_comment_url" in
  "$pr_url"#issuecomment-*)
    progress_comment_id=${progress_comment_url#"$pr_url"#issuecomment-}
    case "$progress_comment_id" in ''|0*|*[!0-9]*) progress_comment_id= ;; esac
    ;;
esac
```

Keep the returned URL and its numeric `#issuecomment-<id>` as `progress_comment_id` only if the URL belongs to the resolved PR. If the GIF or attachment support is unavailable, skip the start comment. If posting fails or the result is ambiguous, do not post a replacement or guess an ID. Report the problem and continue with the normal review.

#### Verify the diff

Review the PR's diff, not just local files: `gh pr diff <pr-url>` defines which lines are commentable. Read and verify claimed code at the returned `headRefOid`. The local checkout may be stale or on another branch. Recheck the PR head just before posting. If it moved, reverify the findings and line mappings before any further write. If a write returns an ambiguous result, check whether it landed before retrying.

### 2. Post inline comments on the offending lines

Create ONE review containing all inline comments (one API call, no notification spam), using `--field` payloads. Never use `event: REQUEST_CHANGES` or `APPROVE`; always `COMMENT`.

```sh
gh api repos/{owner}/{repo}/pulls/<number>/reviews \
  --method POST \
  --field commit_id="<headRefOid>" \
  --field event=COMMENT \
  --field body="Adversarial review — see summary comment for the full report." \
  --field 'comments[][path]=src/foo.ts' \
  --field 'comments[][line]=42' \
  --field 'comments[][side]=RIGHT' \
  --field 'comments[][body]=<comment body>'
```

For long/multiline comment bodies, build the payload as JSON and pipe it: `jq -n '{...}' | gh api ... --input -`.

Each inline comment body:

````markdown
### 🚨 BUG: [short title]

**Severity:** CRITICAL · **Category:** Correctness

[What's wrong — one or two sentences.]

**Trigger:** [concrete scenario]

**Source:** [src/foo.ts:42-48](https://github.com/owner/repo/blob/<headRefOid>/src/foo.ts#L42-L48)

```suggestion
[the fixed line(s) — only when the fix is a drop-in replacement for the commented lines]
```
````

Rules for inline comments:

- Use `suggestion` blocks ONLY when the fix replaces exactly the commented line range. Otherwise show the fix in a normal fenced block with the correct language tag (`ts`, `py`, `go`, ...).
- Multi-line anchors: add `start_line` + `start_side` alongside `line`.
- A line is only commentable if it appears in the PR diff. If a finding lives outside the diff, skip the inline comment and flag it in the summary under "Outside the diff" with the same fully qualified `headRefOid` source link.
- Severity icons: 🚨 CRITICAL, 🔴 HIGH, 🟡 MEDIUM, ⚪ LOW

### 3. Post the summary comment

```sh
gh pr comment <pr-url> --body-file <summary-file>
```

Summary template (write to a temp file, delete after posting):

````markdown
## 🔍 Adversarial Review

> Assumes bugs exist and hunts for them. Silence on a line means it survived.

- **Repository:** [owner/repo](https://github.com/owner/repo)
- **Pull request:** [#123 — PR title](https://github.com/owner/repo/pull/123)
- **Revision:** [`feature-branch` at `abcdef0`](https://github.com/owner/repo/tree/<headRefOid>)

**Verdict:** N findings — X critical, X high, X medium, X low

| #   | Severity    | Category   | Finding                        | Location                                                                                 |
| --- | ----------- | ---------- | ------------------------------ | ---------------------------------------------------------------------------------------- |
| 1   | 🚨 CRITICAL | Security   | SQL injection via `name` param | [src/db.ts:42](https://github.com/owner/repo/blob/<headRefOid>/src/db.ts#L42)            |
| 2   | 🟡 MEDIUM   | Edge cases | Empty array crashes reducer    | [src/util.ts:17-20](https://github.com/owner/repo/blob/<headRefOid>/src/util.ts#L17-L20) |

<details>
<summary><strong>Full findings</strong></summary>

### 1. 🚨 [title]

[src/db.ts:42](https://github.com/owner/repo/blob/<headRefOid>/src/db.ts#L42) · Security

[description]

**Trigger:** [scenario]

```ts
// fix
```

</details>

### Outside the diff

(only if applicable — findings in untouched code, with fully qualified `headRefOid` source links)
````

Every `Location`, full finding, and outside-the-diff entry must use the same fully qualified `https://github.com/<owner>/<repo>/blob/<headRefOid>/...#L...` source links as the conversational review. Do not fall back to the PR Files tab, GitHub's automatic relative linking, or plain `file:line` text when a PR was resolved.

If the review found nothing, publish the final review as a summary comment only. Include the repository and PR links, "No bugs found," and the verdict line. Do not post an inline review or manufacture findings.

### 4. Report back

For `post progress`, delete the start comment only after the final summary and any applicable inline review are confirmed posted. Use the saved `progress_comment_id` and the resolved PR's `pr_host` and `pr_owner_repo` (`owner/repo`). Never use `--delete-last` or delete a comment located by its text.

```sh
if [ -n "${progress_comment_id:-}" ]; then
  gh api --hostname "$pr_host" --method DELETE \
    "repos/$pr_owner_repo/issues/comments/$progress_comment_id"
fi
```

If final posting is incomplete, do not delete the start comment. If cleanup fails, do not repost the review. In either case, report the remaining start comment's URL if known.

Tell the user what was posted: link the repository, pull request, and summary comment, then state how many inline comments landed (and which findings were skipped as outside the diff).
