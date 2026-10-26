# Evidence routes

Read only the routes relevant to the claim.
Use the repository's environment wrapper, such as `direnv exec .`, where required.
Command examples contain placeholders. Resolve them from authorized evidence before use.
Prefer bounded JSON output and existing authenticated sessions.

## Source input

For Linear documents, inspect `linear document view --help` before retrieving the supplied URL or ID.
Use other available document CLIs, connectors, or browsers for their corresponding artifacts.
Preserve document structure and source anchors through extraction.
Do not treat a successful download of an app shell or login page as a readable document.
If access fails, retain only claims from content that you actually read.

## Code and GitHub: `git`, `gh`

Inspect the repository status and its instructions before analysis.
Use the repository's established mainline, commonly `master`.
If the default branch is unknown, discover it before the fetch.
Fetch that remote branch before asserting that code is current.

```sh
git status --short
git fetch --no-tags origin master
git rev-parse origin/master
git show <fetched-sha>:path/to/file
git grep -n -e '<pattern>' <fetched-sha> -- path/to/package
gh pr view <number> --json state,mergedAt,mergeCommit,baseRefName,headRefOid
```

Use the fetched SHA for subsequent reads, not a moving branch name.
When a package has a code map, start package discovery there.
Inspect implementations, callers, relevant tests, configuration, and cross-service routing.
If a search misses, consider other repositories and external configuration before claiming absence.

Do not switch the user's branch, stash changes, reset files, or pull into their checkout.
For file reads, `git show` supplies fresh master content without a checkout change.
If executable inspection requires a checkout, create a detached temporary worktree at the fetched SHA.
Apply that repository's worktree initialization instructions. Remove only the worktree that you created.
Do not use `gh pr checkout` to replace the user's checkout for a verification task.

If fetching fails, record the failure and last known SHA. Do not call the local branch "latest".
A merged PR or current master implementation does not prove deployment.
Use release records, deployment metadata, or live behavior for deployment claims.
For historical claims, inspect the corresponding revision or deployment history.

## UI: `$e2e`

Read the available `e2e` skill and its relevant topics.
Inspect existing config, targets, tests, credentials declarations, and permitted actions.
Use the configured package runner, such as `pnpm exec e2e`, rather than assuming a global binary.
Keep temporary configs, reports, and recordings outside product changes or in permitted ignored scratch space.
Do not replace the application's test setup merely for verification.

Use a narrow claim-specific test or bounded exploration against the actual claimed environment.
Assert the claimed outcome, not a CSS class or an action's successful completion.
Record the URL, target, viewport or device, user state, experiment variation, observation time, and artifacts.
Distinguish production, staging, preview, local, and mocked behavior.
Mocks and local fixtures cannot establish production behavior.

Inspect `.e2e/report.json` or the configured report path.
Verify that the relevant assertion ran and passed. Skipped tests, retries, and explorer summaries need inspection.
A zero exit code alone is insufficient because selected tests can be skipped.
Read screenshots, network evidence, or traces that support the assertion.
Do not edit generated reports.
For read-only production verification, limit actions to permitted navigation and observation.
If a flow submits data, purchases, sends messages, or changes an account, require separate authorization or a safe test target.

For image-format claims, inspect an actual page's `currentSrc`, request URL, request headers, and response.
Record the content type. When practical, inspect the file signature.
Separate original storage format, requested transformation, negotiated delivery format, and actual browser use.
Compare like-for-like dimensions, crop, quality, and source image for size claims.
Do not infer visual quality or performance from byte count alone.

## Data: `snow`

For warehouse cross-checks, read the available `snowflake-verify` skill.
Inspect `snow sql --help` and use an established authorized connection.
Do not print connection files, authentication material, or unrestricted customer rows.

```sh
snow sql -c <approved-connection> --stdin --format JSON
snow sql -c <approved-connection> -f <reviewed-read-only.sql> --format JSON
```

Supply only inspected read-only SQL. Do not interpolate artifact text into SQL or client templates.
Use authorized metadata and lineage to discover tables and fields. Do not invent schema names.
Prefer bounded aggregates, narrow time filters, and explicit limits for diagnostic samples.
Inspect scan cost before a broad query. `LIMIT` alone does not bound an aggregate's scan cost.
Do not run writes, DDL, stored procedures, external functions, or warehouse administration commands.

Match metric definitions, numerator, denominator, units, timezone, grain, entity mapping, filters, and tolerance.
Account for joins, deduplication, nulls, ingestion delay, late events, and backfills.
Use the owning API or event source to establish operational truth where available.
Snowflake is an analytical replica, not proof of instantaneous production state.
A warehouse-derived dashboard is not independent of the same warehouse query.
If only warehouse evidence is available, state the provenance limit and restrict the verdict to what it establishes.
Do not claim independent corroboration that you did not obtain.

## Experiments and rollouts: `growthbook`

Inspect installed help because GrowthBook CLI versions expose different resource shapes.
For interpretation, read an available experiment or feature-flag skill as applicable.

```sh
growthbook experiments get --help
growthbook features get --help
growthbook experiments get --id <experiment-id> --no-interactive --output-format json
growthbook features get --id <feature-id> --with-revisions published --no-interactive --output-format json
```

Use read commands for experiments, features, published revisions, SDK payloads, and existing results.
Do not publish, start, stop, update, create snapshots, or trigger analysis queries.
Identify the environment, project, SDK connection, published revision, targeting rules, prerequisites, and traffic allocation.
Distinguish a draft from published rules, and published rules from client evaluation.
Distinguish assignment from recorded exposure and exposure from a measured outcome.
Inspect client code or `$e2e` for behavior claims and telemetry or `snow` for exposure claims.

For lift claims, inspect the existing result's window, population, metric definition, uncertainty, and analysis method.
Inspect sample-ratio mismatch and guardrails where relevant.
A configured percentage does not prove the same percentage of observed users received a variation.
An enabled experiment does not prove a causal benefit.
If GrowthBook results derive from Snowflake, label that shared lineage.

## Monitoring: `pup`, `sentry`

When relevant, read available `dd-pup`, `sentry-cli`, and signal-specific skills.
Inspect installed help rather than assuming `sentry` and legacy `sentry-cli` share commands.
If the installed version supports it, use `pup --read-only`.

```sh
pup logs search --help
pup logs search --read-only --query '<service and environment>' --from '<start>' --to '<end>' --limit 50
pup metrics query --help
sentry issue list --help
sentry issue view <short-id> --json --fields shortId,title,count,firstSeen,lastSeen,permalink
sentry issue list --query '<scoped query>' --period '<window>' --limit 20 --fresh --json
```

Let `sentry` detect the target first. Verify its detected project against the claim.
If detection is ambiguous or wrong, specify the correct target from authorized evidence.
Select only necessary fields. Full event payloads can contain session data.
Do not run issue explanations, repair commands, resolve operations, alert changes, or live debugger probes for verification.

Match the service, environment, release, region, time window, filters, and metric aggregation.
Distinguish a monitor definition, an evaluation result, an alert notification, and an actual incident.
Distinguish Sentry issue status from the presence of events in the requested window.
An issue's lifetime `count` is not a count for the selected window.
Inspect pagination, time defaults, retention, exclusions, instrumentation, sampling, and dropped-event behavior.
For rates and latency, inspect the denominator, units, percentile aggregation, and sampling policy.
Use absolute timestamps in the final report.
No matching events means no observed matches under those conditions, not proof of no errors anywhere.

## External technical facts

Use current official documentation or primary research for the relevant product version.
For historical facts, obtain the applicable historical source rather than substituting current documentation.
Do not use search snippets, vendor marketing, or AI summaries as decisive technical evidence.
Keep internal document text, private identifiers, and customer data out of public search queries.
