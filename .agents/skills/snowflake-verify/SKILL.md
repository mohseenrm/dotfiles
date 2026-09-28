---
name: snowflake-verify
description: Independently check a factual claim against its source of record and Snowflake tables, then report VERIFIED, INCORRECT, UNVERIFIED, or NEEDS MORE INFORMATION with evidence and caveats. Use for cross-checking metrics, events, or operational assertions, not for writing or changing warehouse data.
---

# Verify claims against Snowflake

Treat every claim as unverified at intake, including claims supplied by an assistant, dashboard, ticket, or prior query. Establish the claim independently **before** comparing it to Snowflake. Never use a Snowflake-derived dashboard or a copy of the same pipeline as independent corroboration; trace provenance if uncertain. A passing Snowflake query alone does not verify the claim.

## Evidence workflow

1. Restate each testable claim with entity, metric/event, expected value, time window, timezone, grain, filters, and acceptable tolerance. Identify what evidence would *disprove* it. If material scope is missing, investigate what can be established and mark the remainder NEEDS MORE INFORMATION; do not invent a definition.
2. Prefer an available, authorized read-only CLI for the source of record: `gh` for code, PRs, checks, and issues; `pup` for Datadog telemetry; `sentry-cli` for Sentry events, issues, and releases; `growthbook` for feature configuration or experiment setup; or another authoritative API, document, or event log. Check the relevant command's `--help` before use, and select only read operations. Confirm the evidence is independent: a GrowthBook analysis or other report sourced from Snowflake is not an independent cross-check. Record the source identity, observation time, exact scope, and relevant result. Do not treat a claim's own text as evidence. If independent evidence is unavailable, say so; never promote the Snowflake result to an independent source.
3. Use the `snow` CLI to find the relevant Snowflake table(s) and their lineage/definitions from authorized documentation or read-only metadata. Confirm which connection/role and environment you are using without exposing configuration, tokens, or account identifiers. `snow sql --help` and `snow connection test --help` describe the installed CLI. Run bounded, read-only queries with `snow sql -c <approved-connection> --stdin --format JSON`, supplying a reviewed `SELECT` on standard input (or use `-q` for nonsensitive SQL); use only actual identifiers discovered from authorized metadata. Avoid templating untrusted input, write/DDL commands, stored procedures, external functions, and unbounded row dumps. Prefer aggregates and narrow time/entity filters; use a deliberate `LIMIT` for diagnostic rows. Check query cost before broad scans.
4. Compare like with like: timestamps and timezone, ingestion lag, source vs warehouse update time, metric definitions, entity mapping, join cardinality, deduplication, nulls, late arrivals, backfills, and access/row-level filtering. For a negative claim, establish the coverage and freshness needed to make absence meaningful. Where feasible check source-to-table lineage so two matching numbers are not mistaken for independent evidence.
5. Re-share a verdict **per claim** in the authorized conversation. Include what the independent source says, what Snowflake says, the tested scope/time, key caveats or disagreement, and a minimally identifying evidence locator (e.g. issue/commit identifier and table/query description). Preserve uncertainty; avoid overclaiming beyond the records actually inspected.

## Verdicts

- **VERIFIED**: An authoritative *independent* source supports the specific claim and matching Snowflake evidence covers the same definition and window, with no material unresolved caveat. State any nonmaterial caveats.
- **INCORRECT**: Sufficient, comparable evidence from the independent source and Snowflake establishes that the specific claim is false (including a claimed number outside its stated tolerance). Give the actual supported value or range and explain the mismatch; do not use this label merely because the two sources disagree with each other.
- **UNVERIFIED**: Both sources have been checked, but they materially disagree or their evidence does not establish either the claim or its negation. Describe the conflict and what would resolve it; do not mistake an unresolved disagreement for proof the claim is false.
- **NEEDS MORE INFORMATION**: A source, table/lineage, mapping, permission, or freshness/coverage requirement is missing, or the claim is too ambiguous to test. Specify precisely what is needed; lack of evidence is not proof of falsehood.

If a claim has multiple parts, split it into independently labeled verdicts. A matching count does not verify identities or causation. Query failures and limited permissions are missing evidence, not confirmation.

## Public-repository boundary

This skill is deliberately organization-agnostic. Never put company names, internal URLs, schema/table names, account IDs, credentials, real SQL results, or sensitive claim examples in this public repository, its commits, tests, or generated artifacts. Keep investigation results in the authorized conversation; do not send internal claims or query output to public web search, issues, PR comments, or third-party services without explicit authorization. Avoid putting sensitive literals in shell history, command arguments, or warehouse query history. Do not print Snowflake config or auth material while diagnosing. Before committing any changes to this skill, inspect the staged diff for proprietary information. Run no live company queries merely to test the skill's installation.
