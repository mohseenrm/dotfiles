---
name: adversarial-review
description: |
  Structured adversarial review of any artifact — code, docs, PRs, designs, approaches.
  Spawns 3 parallel agents (Devil's Advocate, Steelman Defender, Impartial Analyst)
  who independently critique the target, then cross-examines their findings to produce
  a high-confidence verdict. Inspired by claude-octopus grapple/squeeze patterns.
user-invocable: true
disable-model-invocation: true
argument-hint: [target — file path, PR number/URL, "current changes", or description of approach]
allowed-tools: Agent, Bash, Read, Glob, Grep
---

# Adversarial Review

You are conducting a structured adversarial review. The target to review is: $ARGUMENTS

## Phase 0: Identify & Load the Target

Determine what type of artifact you're reviewing based on the argument:

- **PR / GitHub URL** — If the argument looks like a PR number (e.g., `#123`) or URL, fetch the PR diff and description using `gh pr diff` and `gh pr view`
- **File path(s)** — If it's a file or glob pattern, read the files
- **Directory** — If it's a directory, explore and read key files
- **Document** — If it references a doc (Linear, Confluence, etc.), fetch it via available MCP tools
- **Concept / approach** — If it's a description of an approach or design, treat the argument text itself as the subject
- **Current changes** — If it says "current changes", "my changes", "staged", or similar, run `git diff` and `git diff --cached`

Read/fetch the full content of the target now. You MUST have the actual content before proceeding to Phase 1.

### Large Target Handling

After loading the target, assess its size:

- **Small targets (<300 lines):** Inline the full content directly into each agent's prompt.
- **Medium targets (300-800 lines):** Inline the full content, but instruct each agent to focus on the most critical sections first.
- **Large targets (>800 lines):** Do NOT inline. Instead, give each agent the file path(s) and instruct them to use the `Read` tool to load the content themselves. This avoids context bloat and ensures each agent sees the complete artifact. Include a brief summary of the target's structure so agents know what to read.
- **Very large targets (>2000 lines or >10 files):** Tell the user this target is too large for a single adversarial review. Recommend breaking it into focused sub-reviews (e.g., by module, by file, or by concern area).

---

## Phase 1: Adversarial Analysis (3 Parallel Agents)

Launch exactly 3 agents **in parallel** using the Agent tool. Each agent gets the FULL content of the target (inlined for small/medium, via file path + Read tool for large) and a distinct adversarial persona. Each agent MUST return structured findings.

### Verification Gate (REQUIRED in every agent prompt)

Every CRITICAL or HIGH finding MUST include at least one of the two evidence types below. Findings that cannot satisfy the gate MUST be demoted to MEDIUM/LOW or moved to a separate "Unverified Suspicions" section. The gate exists because past reviews have shipped inverted version claims and code-path bugs that didn't exist after the actual flow was traced.

1. **Concrete repro** — a runnable input that triggers the bug (e.g., `curl http://127.0.0.1:80@evil.com/oauth/callback` → expected behavior vs actual), OR a code trace naming each function in the path (entry → assertion site → branch taken), with line citations.
2. **Verified upstream evidence** — for any claim about a library, dependency, framework, or version change, quote the actual source: a changelog entry, a CVE/advisory link with the affected versions, a line from the module cache (`~/go/pkg/mod/...`, `node_modules/...`), or an upstream commit URL. Claims of the form "version X used to do Y, now does Z" without this evidence are DEMOTED, not promoted.

Format each gated finding as:
> **What:** one-line claim
> **Evidence type:** [repro | code-trace | upstream-source]
> **Receipts:** [the actual quoted source / runnable command / file:line trace]
> **Why it matters:** impact
> **Confidence:** [high if receipts are quoted; medium if reasoned-from but not quoted; do not file as HIGH/CRITICAL otherwise]

### Agent 1: Devil's Advocate (Red Team)

Prompt the agent with:

> You are the DEVIL'S ADVOCATE. Your job is to ruthlessly find every flaw, risk, gap, and weakness.
>
> TARGET TO REVIEW:
> [paste full target content here]
>
> INSTRUCTIONS:
> - Assume the worst. Look for what can go wrong, not what's right.
> - Find logical flaws, missing edge cases, unstated assumptions, security risks, performance pitfalls.
> - For code: focus on bugs, race conditions, error handling gaps, security vulnerabilities (OWASP Top 10), untested paths, backwards-compatibility breaks.
> - For docs: focus on inaccuracies, missing context, ambiguities, misleading claims, gaps in reasoning.
> - For PRs: focus on what the diff breaks, what it doesn't test, what reviewers would miss.
> - For designs/approaches: focus on failure modes, scalability limits, hidden complexity, alternatives not considered.
>
> **GATE: Every CRITICAL/HIGH finding must satisfy the Verification Gate (see top of Phase 1). For code-path claims: actually trace the path from the entry point to the alleged failure site and cite line numbers. For version/library claims: read the actual source from the module cache or quote a CVE/changelog. Findings that can't pass the gate go under "Unverified Suspicions" with severity MEDIUM at most.**
>
> OUTPUT FORMAT (you MUST follow this exactly):
>
> ## Devil's Advocate Findings
>
> ### Critical Issues (must fix)
> [numbered list — severity: CRITICAL]
>
> ### Significant Concerns (should fix)
> [numbered list — severity: HIGH]
>
> ### Minor Issues (nice to fix)
> [numbered list — severity: MEDIUM/LOW]
>
> ### Hidden Risks
> [risks that aren't obvious from surface-level review]
>
> ### What's Missing
> [things that should exist but don't]
>
> ### Unverified Suspicions
> [findings you couldn't satisfy the Verification Gate for. Useful signal, but NOT yet HIGH/CRITICAL. Include what evidence would be needed to promote each one.]
>
> Every CRITICAL/HIGH finding MUST follow the Verification Gate format (What / Evidence type / Receipts / Why it matters / Confidence). Findings in the Minor / Hidden Risks / Missing sections may use a lighter format: **What** (one-line), **Why it matters**, **Evidence** (line/quote/reasoning).

### Agent 2: Steelman Defender (Blue Team)

Prompt the agent with:

> You are the STEELMAN DEFENDER. Your job is to find the strongest possible case FOR the current approach and identify what's genuinely good.
>
> TARGET TO REVIEW:
> [paste full target content here]
>
> INSTRUCTIONS:
> - Find the best interpretation of every decision. Assume the author had good reasons.
> - Identify what's well-done, clever, or robust.
> - For code: find good patterns, solid error handling, clean abstractions, security strengths.
> - For docs: find clear explanations, good structure, accurate claims.
> - For PRs: find good test coverage, safe rollout patterns, clean implementation.
> - For designs: find elegant solutions, good trade-off analysis, appropriate constraints.
> - ALSO identify: which criticisms a devil's advocate might raise that are actually WRONG or overblown, and explain why.
>
> **GATE: For every "Likely False Alarm" you list, you must provide the receipts that disprove the criticism: the actual code path showing the case is already handled, the changelog/source quote that contradicts the version claim, or a counter-repro showing the alleged bug doesn't reproduce. A defender saying "that's wrong" without receipts is worth as little as an attacker saying "that's broken" without receipts.**
>
> OUTPUT FORMAT (you MUST follow this exactly):
>
> ## Steelman Defense
>
> ### Genuine Strengths
> [numbered list of things done well, with specific evidence]
>
> ### Good Design Decisions
> [decisions that might look questionable but are actually sound, with reasoning]
>
> ### Likely False Alarms
> [criticisms a reviewer might raise that are actually wrong or overblown — for each: what the criticism would be, and why it's incorrect]
>
> ### Remaining Vulnerabilities
> [even as defender, honestly flag things that ARE legitimately weak]

### Agent 3: Impartial Analyst (Context & Alternatives)

Prompt the agent with:

> You are the IMPARTIAL ANALYST. Your job is to evaluate the target in its broader context and identify alternatives.
>
> TARGET TO REVIEW:
> [paste full target content here]
>
> INSTRUCTIONS:
> - Step back and evaluate the big picture. Don't just look at what's there — consider what COULD be there.
> - Evaluate against industry best practices, common patterns, and known pitfalls.
> - For code: compare against idiomatic patterns for the language/framework, consider maintainability and readability for the next developer.
> - For docs: evaluate completeness, audience-appropriateness, and whether it achieves its stated goal.
> - For PRs: evaluate scope appropriateness (too big? too small? wrong abstraction boundary?).
> - For designs: evaluate against alternatives the author may not have considered.
>
> **GATE: When asserting "industry standard is X" or "the idiomatic pattern is Y", cite a specific source — a style guide URL, a well-known reference implementation, an upstream doc link. Vague appeals to "best practice" without a referent are demoted to MEDIUM at best.**
>
> OUTPUT FORMAT (you MUST follow this exactly):
>
> ## Impartial Analysis
>
> ### Context Assessment
> - What this is trying to achieve
> - Whether the approach is appropriate for the goal
> - How it compares to standard/industry approaches
>
> ### Alternative Approaches Not Considered
> [for each: what the alternative is, trade-offs vs current approach, and whether switching is worth it]
>
> ### Consistency & Standards
> [does this follow the project's existing patterns and conventions? any style, naming, or structural inconsistencies?]
>
> ### Maintainability Verdict
> [how easy will this be to understand, modify, and debug 6 months from now?]
>
> ### Risk/Reward Assessment
> [is the complexity justified by the value delivered?]

---

## Phase 1.5: Receipts Pass (Orchestrator)

Before cross-critique, audit every CRITICAL and HIGH finding from all three agents against the Verification Gate yourself. Do NOT launch more agents — this is your work.

For each gated finding, ask:

1. **Is the evidence actually present?** A finding tagged "code-trace" must cite specific line numbers. A finding tagged "upstream-source" must quote the source, not paraphrase. A finding tagged "repro" must include the literal input that triggers the bug.
2. **Is the evidence correct?** Spot-check it. If the agent claims `~/go/pkg/mod/foo@v1.3.0/bar.go:42` does X, briefly verify by reading that line. If the agent claims "library Y v1.5 changed behavior", read the upstream changelog or `git log` in the module cache.
3. **Does the evidence actually support the conclusion?** Easy failure mode: agent quotes a real line but draws the wrong inference from it. E.g., quoting a function that takes the unsafe input but ignoring the validation that runs three lines earlier.
4. **For code-path claims, did the agent trace the WHOLE path?** Many false-positive findings die at "function X is called from Y which validates the input before X runs." If the trace stops at the suspect line without going up the call stack, the finding is incomplete.

Outcomes per finding:
- **Pass** — keep at original severity, mark `[receipts: verified]`.
- **Partial** — evidence present but only weakly supports the conclusion. Demote one severity level (CRITICAL → HIGH, HIGH → MEDIUM) and mark `[receipts: partial]`.
- **Fail** — evidence missing, wrong, or doesn't trace the full path. Move to "Unverified Suspicions" with severity MEDIUM at most, mark `[receipts: failed]`, and list what would be needed to promote it.

Do NOT silently drop failed findings — they still go in the final report under "Unverified Suspicions", because a smart suspicion without receipts is still useful signal for the author. The point is to never lead with a HIGH/CRITICAL rating you can't defend.

---

## Phase 2: Cross-Critique

After Phase 1.5, synthesize the (now-receipt-checked) findings yourself. Do NOT launch more agents.

Perform cross-critique:

1. **Identify Agreements** — findings that 2+ perspectives agree on. These are HIGH CONFIDENCE.
2. **Identify Conflicts** — where the Devil's Advocate raised an issue that the Defender flagged as a false alarm. Adjudicate each conflict with your own judgment. Explain your reasoning.
3. **Identify Gaps** — things the Impartial Analyst surfaced that neither attacker nor defender considered.

---

## Phase 3: Final Verdict

Present the final structured output:

```
## Adversarial Review: [target name]

### Verdict: [APPROVE | APPROVE WITH CHANGES | REQUEST CHANGES | REJECT]

### Confidence: [HIGH | MEDIUM | LOW] (based on cross-perspective agreement)

### Consensus Findings (2+ perspectives agree)
[numbered list — these are the most reliable findings]

### Adjudicated Conflicts
[for each conflict between perspectives, your ruling and reasoning]

### Key Strengths
[top 3-5 genuine strengths from the Defender]

### Required Changes (if any)
[ordered by priority — only include findings with `[receipts: verified]` from Phase 1.5]

### Recommended Improvements (optional)
[nice-to-haves that aren't blocking]

### Risks to Monitor
[things that aren't problems NOW but could become problems]

### Unverified Suspicions (for the author to investigate)
[findings that didn't pass the Verification Gate. NOT blocking, but worth a look. For each one: the suspicion, what evidence would promote it to verified, and the minimum step the author could take to confirm or refute.]
```

---

## Rules

1. **Never skip Phase 1.** All 3 agents MUST run in parallel.
2. **Give agents FULL content.** Do not summarize the target — agents need the real artifact to find real issues. For large targets, give agents the file path and instruct them to `Read` it themselves (see Large Target Handling in Phase 0).
3. **Be honest in Phase 2.** If the Devil's Advocate is right, say so. If the Defender's rebuttal is stronger, dismiss the criticism.
4. **Verdict must be justified — and counted on receipt-verified findings only.** Don't default to "APPROVE WITH CHANGES." A flawless artifact deserves APPROVE. A dangerous one deserves REJECT. Use these criteria: REJECT if any unresolvable CRITICAL issue (receipts: verified); REQUEST CHANGES if >2 HIGH issues (receipts: verified) or any CRITICAL; APPROVE WITH CHANGES for minor/moderate issues; APPROVE if no significant issues. **Unverified Suspicions never escalate the verdict.** They go in a separate section of the report for the author to investigate, but they are not blocking.
5. **Keep the final output actionable.** Every finding should tell the author exactly what to do.
6. **Handle agent failures gracefully.** If an agent fails, times out, or returns unusable output, proceed with the remaining agents. Note the reduced confidence in the verdict (e.g., "2/3 agents completed — confidence reduced"). Do NOT re-launch failed agents or block on them.

---

## Reviewer Anti-Patterns to Avoid

Each of these has caused real false-positive HIGH/CRITICAL findings in past reviews. When you (or any agent) catches yourself doing one of these, stop and either gather the receipts or demote the severity.

1. **Version-claim without source-check.** "Library X used to do Y, now does Z" is worthless without quoting the actual changelog, CVE/advisory, upstream commit, or source line from the module cache. Recent miss: claimed a Go SDK turned cross-origin protection OFF in a version bump — actually, the previous version had no such protection at all, and the bump added an opt-in version of it. Inverted facts. The fix: read `~/go/pkg/mod/<lib>@<ver>/...` or `node_modules/<lib>/...` for the two versions and compare directly.

2. **Code-path claim without full trace.** "Function X processes untrusted input Y, therefore X is vulnerable" without checking what runs before X. Recent miss: claimed the wizard's POST path was missing access-control validation, when the parser is called from a wrapper that errors out before the upload starts. Always trace entry → assertion site, top to bottom, and cite each function in the chain.

3. **Severity from prose, not from impact.** A finding marked HIGH should answer: "what exactly does the attacker / failing system gain, and what's the blast radius?" Severity inflation from words like "could", "might", "would allow" without a concrete scenario is the tell.

4. **Theoretical bug without reproducible input.** For CRITICAL claims especially, you should be able to write the literal request / payload / state / sequence that triggers the bug. If you can't, the finding is a HYPOTHESIS, not a CRITICAL. Park it in Unverified Suspicions and ask the author to verify.

5. **"Best practice" without referent.** "This violates industry standards" / "the idiomatic pattern is" / "everyone does X" are all hand-waves without a specific link to the style guide, framework doc, or reference implementation being invoked. Either name the source or downgrade the criticism.

6. **One-sided argument framing.** A real adversarial review surfaces the strongest *steelman* of the design before tearing it down. If your critique would survive being reframed as "but the author chose this because…", you're done. If it falls apart, you missed the design intent and your finding needs reconsideration.

7. **Claims about test coverage without running the tests.** "There's no test for X" requires actually grepping the test files (or running them with verbose output). The number of times a finding of "untested" turns out to be tested under a non-obvious name is high enough that the receipts requirement applies here too.

8. **Severity inflation by chaining hypotheticals.** "If A, then B, and then C, an attacker could…" — each link in the chain multiplies uncertainty. If any link in the chain is "and assuming the user sends malicious input that bypasses validator V" without showing how V is bypassed, the chain breaks. Be explicit about every assumption.

When in doubt, file the finding in **Unverified Suspicions** instead of HIGH/CRITICAL. A useful suspicion the author can investigate is more valuable than a confident-sounding wrong finding.
