# Claim verification report

Scale the report to the artifact, but keep every claim and decisive evidence traceable.
Use labels rather than an invented truth score.

## Summary

State the source and revision, retrieval time, assessment time, environments, and fetched repository SHAs.
Lead with a contradicted premise or material unresolved premise and its effect on the proposed decision.
Do not equate a failed premise with a false document.
Separate current readiness from claims about the document's original date.

Report the number of factual claims in each verdict category.
Report non-factual items separately.
If reporting conclusive coverage, use `(VERIFIED + CONTRADICTED) / all factual claims`.
Include `PARTIALLY VERIFIED`, `UNVERIFIED`, and `NEEDS CONTEXT` in that denominator.
If the denominator is zero, report coverage as not applicable.
Coverage is not accuracy, approval, or a document-wide verdict.

## Claim ledger

| ID and source anchor | Atomic claim and tested scope | Verdict / confidence | Independent evidence | Correction, caveat, or missing proof |
| --- | --- | --- | --- | --- |
| C1, section or page | Quote or faithful paraphrase. Identify implied premises. | Label and reason for confidence | Evidence IDs and provenance | Supported result, unresolved scope, or exact blocker |

Keep important scope visible: environment, population, timeframe, metric definition, and units.
If the ledger becomes wide, place the scope and explanation in a short detail block under each claim.
Every factual claim needs a verdict, including blocked and unsupported claims.
If independent evidence is unavailable, use `None obtained`. Do not leave the cell ambiguously empty.
If a quote is excessive or sensitive, use a short paraphrase with an exact source anchor.

## Evidence ledger

For each evidence ID, include:

- Locator: an immutable code link, commit and file lines, official page, query ID, issue/event ID, or local artifact path.
- Origin: the owning system and `INDEPENDENT`, `SAME LINEAGE`, `SOURCE ONLY`, or `UNKNOWN` provenance.
- Observation: an absolute timestamp and the tested environment, release, route, population, and window.
- Method: the actual command, query, UI steps, or assertion that produced the evidence.
- Result: a minimal excerpt, aggregate, assertion result, or measured value that supports the conclusion.
- Limits: freshness, retention, sampling, mocks, permission limits, source conflicts, and unsupported generalizations.

Group shared evidence once and reference it from all applicable claims.
Distinguish observations from interpretations.
Do not cite an unexecuted command or a planned query as evidence.
For redacted commands, mark the redaction. Do not imply that a redacted example is an exact executable reproduction.
Avoid exporting credentials, full session payloads, raw customer rows, or private evidence to unrelated systems.

## Consequences and open questions

Explain the smallest supported correction to each decisive premise.
Name the proposed work that requires reconsideration, without implementing or deleting it.
State which conclusions remain valid and which depend on unresolved claims.
For each unresolved claim, name the exact missing evidence or scope decision.

## Coverage audit

Reconcile each source section, table, diagram, and caption with the claim IDs or non-factual classification.
List inaccessible sections, extraction limits, and any pending queue explicitly.
If verification is incomplete, say so and identify the next evidence needed.
Do not use "all claims verified" to mean that every claim merely received a label.

## Calibration example

Input: "The site cannot serve AVIF, so build an encoder. This will cut transfer size by 30%."

- C1, explicit capability claim: Seek a real endpoint response. One valid AVIF response contradicts the universal negative.
- C2, implied prerequisite: Verify whether the proposed encoder is absent or necessary. Existing support alone does not settle all requirements.
- C3, prediction: Verify the baseline and measurement method. Future savings remain `UNVERIFIED` without comparable evidence.
- The proposed implementation is a recommendation, not a verified fact.

A live page that requests AVIF supports use on that page, browser, and observation time.
It does not prove site-wide use, historical support, visual quality, or a 30% saving.
