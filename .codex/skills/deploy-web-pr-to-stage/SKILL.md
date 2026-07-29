---
name: deploy-web-pr-to-stage
description: |-
  Deploy an unmerged web (Rails monolith) PR branch to the staging EKS cluster only. Verifies the build-web-image label produced a pr-SHA image in ECR, blocks if the branch carries pending migrations (the deploy's pre-upgrade hook would apply them to stage pre-merge), dispatches the trigger-web-cd workflow scoped to staging, then monitors the rollout via kubectl and reports completion or failure.
---
# Deploy a web PR to staging

Deploy an **unmerged** `web` PR branch to **staging EKS only** (never production), then watch
the rollout and report. The hard problems this skill exists to solve, in order:

1. PR branch images are published to ECR as **`web:pr-<sha>`**, never bare `web:<sha>` — and only
   when the PR carries the `build-web-image` label. A green CI run is **not** proof the image exists.
2. The staging deploy runs a Helm `pre-upgrade` hook that executes `bin/rake db:migrate`. There is
   **no dispatch flag to skip it.** If the branch carries pending migrations, the deploy **will**
   apply them to the staging DB before merge. This skill blocks on that unless you override.
3. Production must never be touched (`deploy-production-eks=false`, always).

`$ARGUMENTS` is the PR number (e.g. `106869`). If absent, ask for it.

Repo is `opendoor-labs/code`. Default actor/ref come from the PR.

---

## Why these constraints are real (ground truth)

- **`build-web-image` label** — `.github/workflows/web.ci.yaml` only builds and pushes the web image
  to ECR when the PR has the `build-web-image` label (`FORCE_LABEL_BUILD` on
  `contains(github.event.pull_request.labels.*.name, 'build-web-image')`). No label → no image →
  deploy will `ImagePullBackOff`.
- **`pr-<sha>` tag** — same workflow derives the PR image tag as `tag=pr-${GIT_SHA}`. The bare
  `web:<sha>` tag is only produced by the master/CD path (`trigger-cd`), which is **SKIPPED** on PR
  branches. Confirmed empirically on PR #106869 (2026-06-17): ECR had `web:pr-<sha>` (+ `-amd64`/
  `-arm64`) but no bare `web:<sha>`.
- **Migrations always run** — `rb/services/web/ci/deploy-eks/values.yaml` sets
  `db-migrations-hook.enabled: true` with `helm.sh/hook: pre-install,pre-upgrade` running
  `bin/deploy/run_migrations.sh` (which is `bin/rake db:migrate` with retries). `staging.yaml` does
  not override it. The dispatch `client_payload` has no migration toggle. `bin/rake db:migrate` is a
  no-op only when there are no pending migration files — hence the pre-flight check below.
- **Dispatch shape** — `.github/workflows/web.deploy-eks.yaml` listens for
  `repository_dispatch: trigger-web-cd`, gates staging on `deploy-staging-eks != 'false'` and prod on
  `deploy-production-eks == 'true'`, and passes `image_tag` verbatim into `publish-gitops-values` —
  i.e. `image_tag` is literally what Argo/Helm pulls. `git_commit` is used for the Sentry release and
  `wait-for-argo-deployment` tracking, not for the image pull.

---

## Steps

### 1. Resolve PR, branch, and commit

```bash
PR=<pr-number>
REPO=opendoor-labs/code
COMMIT=$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid)
BRANCH=$(gh pr view "$PR" --repo "$REPO" --json headRefName -q .headRefName)
ACTOR=$(gh pr view "$PR" --repo "$REPO" --json author -q .author.login)
echo "PR #$PR  branch=$BRANCH  commit=$COMMIT  actor=$ACTOR"
```

`gh` must run **outside any tool sandbox** — a sandboxed `gh api -X POST` is silently blocked
(exit 1, no run created). If the environment sandboxes Bash, run the `gh` calls with the sandbox
disabled.

### 2. Verify the `build-web-image` label

```bash
gh pr view "$PR" --repo "$REPO" --json labels -q '.labels[].name' | grep -qx build-web-image \
  && echo "label present" || echo "MISSING build-web-image label"
```

If missing: **stop**. Tell the user to add the label (`gh pr edit "$PR" --repo "$REPO" --add-label build-web-image`),
wait for the resulting CI run to build and push the image, then re-run this skill. The label is what
makes the `pr-<sha>` image exist in ECR.

### 3. Confirm the `pr-<sha>` image is actually in ECR

The deploy pulls `web:pr-<COMMIT>`. Confirm it exists before dispatching — a green CI run is not
proof (the manifest step can be green while the tag is absent). The web image lives in the
**cross-account** registry `365342630876.dkr.ecr.us-east-1.amazonaws.com`. The eng SSO role
(acct `073545338079`) can read it via `--registry-id 365342630876`.

```bash
# Requires an eng AWS profile, e.g. `saml2aws login` first.
aws ecr describe-images \
  --registry-id 365342630876 \
  --repository-name web \
  --image-ids imageTag="pr-${COMMIT}" \
  --region us-east-1 >/dev/null 2>&1 \
  && echo "ECR has web:pr-${COMMIT}" \
  || echo "NOT in ECR — image not built yet (check the build-web-image CI run)"
```

If the tag is absent: the build hasn't finished (or the label was just added). Check the PR's
`CI - RB - Web` run; wait for `build-web-image` to succeed, then re-check. Do **not** dispatch against
a missing tag — it deadlocks the Argo sync on `ImagePullBackOff`.

### 4. Pre-flight: block on pending migrations

The staging deploy's `pre-upgrade` hook runs `bin/rake db:migrate` against the **staging DB** with no
opt-out. Detect whether this branch adds migration files relative to `master`:

```bash
git fetch origin master --quiet
PENDING=$(git diff --name-only --diff-filter=A "origin/master...${COMMIT}" -- \
  'rb/services/web/db/migrate/*' 'rb/services/web/db/data/*')
if [ -n "$PENDING" ]; then
  echo "⚠️  This branch adds migration(s) that the staging deploy WILL apply:"
  echo "$PENDING"
else
  echo "No pending migrations — pre-upgrade hook will be a no-op."
fi
```

- **If migrations are found: STOP and surface it.** The policy is migrations run on merge only. State
  clearly that deploying this branch to stage will apply these migrations to the staging DB **before
  merge**, and that there is no flag to suppress the hook. Ask the user to confirm before proceeding.
  Do not dispatch on your own initiative when migrations are present.
- **If none: proceed.** The hook still runs but `db:migrate` does nothing.

### 5. Dispatch `trigger-web-cd` — staging only

Production is hard-pinned off. Run outside the sandbox:

```bash
gh api -X POST -H "Accept: application/vnd.github+json" \
  /repos/opendoor-labs/code/dispatches \
  -f event_type=trigger-web-cd \
  -F 'client_payload[project]=web' \
  -F 'client_payload[slack_channel]=alerts-deploy-web' \
  -F 'client_payload[deploy-staging-eks]=true' \
  -F 'client_payload[deploy-production-eks]=false' \
  -F "client_payload[image_tag]=pr-${COMMIT}" \
  -F "client_payload[git_commit]=${COMMIT}" \
  -F "client_payload[triggered_by][actor]=${ACTOR}" \
  -F "client_payload[triggered_by][ref]=refs/heads/${BRANCH}" \
  -F "client_payload[triggered_by][run_url]=https://github.com/opendoor-labs/code/pull/${PR}"
```

Key invariants: `image_tag=pr-${COMMIT}` (the tag that exists in ECR), `git_commit=${COMMIT}` (bare
sha, for Sentry + Argo tracking), `deploy-production-eks=false`.

`repository_dispatch` returns no run id. Find the run it triggered:

```bash
sleep 5
RUN_ID=$(gh run list --repo "$REPO" --workflow "Deploy - rb - Web" --limit 5 \
  --json databaseId,createdAt,displayTitle \
  -q "[.[] | select(.displayTitle | contains(\"${COMMIT}\"))][0].databaseId")
echo "run=$RUN_ID  https://github.com/$REPO/actions/runs/$RUN_ID"
```

All web deploys share concurrency group `web-cd-deployments` with `cancel-in-progress: false`, so the
run may queue behind another deploy. If it's stuck behind a known-bad run, cancel that one
(`gh run cancel <id> --repo "$REPO"`).

### 6. Monitor the rollout

Watch both the GH workflow and the cluster. Use the workflow first; drop to `kubectl` when something
stalls or to see migration-hook detail.

**Workflow-level:**
```bash
gh run watch "$RUN_ID" --repo "$REPO" --exit-status
```

**Cluster-level (staging workload cluster `okta-oidc-services-services-staging` / context
`okta-oidc-services-staging`, namespace `web`):** the `argocd` CLI is frequently broken
(`invalid_client`), so prefer `kubectl`.

```bash
KCTX=okta-oidc-services-staging   # adjust to your kubeconfig's staging context name
NS=web

# Migration pre-upgrade hook (this is what applies migrations / fails first on a bad image):
kubectl --context "$KCTX" -n "$NS" get job web-db-migrations-hook-helm-pre-upgrade
kubectl --context "$KCTX" -n "$NS" get pods -l job-name=web-db-migrations-hook-helm-pre-upgrade
# Image the hook is trying to pull (should be web:pr-<COMMIT>):
kubectl --context "$KCTX" -n "$NS" get job web-db-migrations-hook-helm-pre-upgrade \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
# Tail migration logs:
kubectl --context "$KCTX" -n "$NS" logs -l job-name=web-db-migrations-hook-helm-pre-upgrade --tail=100

# App rollout:
kubectl --context "$KCTX" -n "$NS" rollout status deploy/web-http-server --timeout=300s
# Confirm the deployed image flipped to pr-<COMMIT>:
kubectl --context "$KCTX" -n "$NS" get deploy web-http-server \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl --context "$KCTX" -n "$NS" get pods -l app=web-http-server
```

**Green signal:** the hook pod's image is `web:pr-<COMMIT>` and it goes `Running → Completed`, then
`web-http-server` (and other web deploys) flip to `pr-<COMMIT>` and roll out healthy. The GH run's
`deploy-staging-eks` job (and `smoke-test-eks`) report success.

### 7. Diagnose failures

- **`ImagePullBackOff` / `ErrImagePull` on the hook or app pod** → the `pr-<sha>` tag isn't in ECR
  (step 3 was skipped or the build hadn't finished). Verify ECR, then re-dispatch once the tag exists.
- **Hook Job `Failed` / `DeadlineExceeded`** → migration failed or timed out (`activeDeadlineSeconds:
  300`, `backoffLimit: 0`). Read the hook logs. A terminally-failed PreSync hook **deadlocks the Argo
  sync** — auto-sync does not retry it. After fixing the cause, clear it:
  `kubectl --context "$KCTX" -n "$NS" delete job web-db-migrations-hook-helm-pre-upgrade`, then let
  the next reconcile recreate it (or re-dispatch).
- **Run queued forever** → blocked by the `web-cd-deployments` concurrency group; cancel the blocking
  run.
- **Argo stuck `OutOfSync` and idle** → manually Sync `web-staging` in the Argo UI (terminate any
  stuck operation first). Note: `web` staging auto-tracks `master` with auto-sync ON, so a later
  master CD deploy will revert stage off this branch image — verify your branch deploy promptly, and
  re-deploy if needed.

### 8. Notify

Report a single clear status to the user:
- ✅ **Deployed** — branch image `web:pr-<COMMIT>` live on staging, app pods healthy, smoke tests
  green. Include the GH run URL and the staging URL (`https://web.apps-staging.opendoor.com`).
- ❌ **Failed** — which stage failed (label / ECR / dispatch / migration hook / rollout / smoke), the
  relevant log excerpt, and the suggested fix. Do not claim success unless step 6's green signal is
  actually observed.

---

## Rules

- **Staging only.** Always `deploy-production-eks=false`. Never dispatch a production deploy from this
  skill.
- **Migrations run on merge only.** If the branch carries pending migrations, stop and get explicit
  user confirmation before dispatching — the deploy has no flag to skip them and will apply them to
  the staging DB pre-merge.
- **Verify before claiming done.** Confirm the deployed image is `pr-<COMMIT>` and pods are healthy
  before reporting success.
- Use `image_tag=pr-<sha>` (exists in ECR for labeled PR builds), `git_commit=<bare sha>`.
- Run `gh` outside the sandbox; sandboxed `gh api -X POST` silently no-ops.
- Read-only DB/console access only — never open a write console to "verify" a migration.
