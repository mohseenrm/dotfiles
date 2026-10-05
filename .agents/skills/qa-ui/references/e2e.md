# Responsive QA with e2e

Use this path for interactive flows, bounded discovery, and regression tests.
Read [the e2e skill](../../e2e/SKILL.md) and its relevant topics rather than
inventing Playwright-compatible options or copying its whole API into qa-ui:
[setup](../../e2e/references/setup.md),
[writing tests](../../e2e/references/writing-tests.md),
[agent steps](../../e2e/references/agent.md),
[running](../../e2e/references/running.md), and
[exploration](../../e2e/references/explore.md).

## Configure the bands

Work in the app under test, not dotfiles. Reuse its installed `e2e` and
`@e2e-dev/web`, configured model, fixtures, and authentication. With no model,
use deterministic `screen`/`browser` actions and `expect`; do not claim that
agent-driven exploration ran. Follow the setup topic if installation is needed.

Add named browser targets for `mobile` (390x844), `tablet` (820x1180), and
`desktop` (1440x900); add `2xl` (1920x1080) when requested. This minimal separate
config preserves the app's shared settings and uses an already-running server:

```ts
// e2e.qa-ui.config.ts, beside the app's existing e2e.config.ts
import type { E2EConfig } from 'e2e';
import { web } from '@e2e-dev/web';
import base from './e2e.config.ts';

const shared: E2EConfig = base;
const app = { url: process.env.QA_BASE_URL ?? 'http://localhost:3000' };

export default {
  ...shared,
  targets: [
    { name: 'mobile', engine: web({ viewport: { width: 390, height: 844 } }), app },
    { name: 'tablet', engine: web({ viewport: { width: 820, height: 1180 } }), app },
    { name: 'desktop', engine: web({ viewport: { width: 1440, height: 900 } }), app },
  ],
  retries: 0,
} satisfies E2EConfig;
```

Adapt this to the actual URL and preserve any necessary engine `headers`,
`basicAuth`, or other app-specific options. `web()` gets engine options;
the target's `app` gets the URL. A viewport alone is not @2x/touch emulation
or native-device QA. Keep the capture helper for its full-page/device-style
screenshots; use the e2e mobile topic only for an explicitly requested native app.

Start one shared app before parallel band runs and omit `app.command` from
this QA config, so one finishing runner cannot stop the others' server or stack.
Alternatively give each run its own port-0 app. Separate test accounts/data
for flows that mutate state; browser context isolation does not isolate server
state. On a shared deployed site, keep exploration read-only unless the user
explicitly authorizes the actions and test account involved.

## Exercise a known flow

Translate a flow's `goal` into an `agent.act` step and its `checks` into
assertions. Use exact `screen` actions for exact input values. The flows JSON
is planning metadata, not an e2e config or test file. Tests must match the app's
`tests` glob. For example, adapting routes/labels to the app's real UI:

```ts
// tests/qa-ui/account-menu.e2e.ts
import { test } from '@e2e-dev/web';
import { expect } from 'e2e';

test('account navigation remains usable', async ({ app, agent, screen, browser }) => {
  await app.open('/account');
  await agent.act('Open the account menu and navigate to Settings');
  await expect(screen.getByRole('heading', 'Settings')).toBeVisible();
  await expect(browser).toHaveURL('/settings');
  await expect.poll(() => browser.evaluate(() =>
    document.documentElement.scrollWidth <= document.documentElement.clientWidth
  )).toBe(true);
  await app.screenshot('settings');
});
```

Pin each `act` outcome immediately. Use `agent.assert(..., { vision: true })`
only when judgment is needed, after reaching the intended state; it does not
replace inspecting screenshots or comparing the supplied Figma frame.
`app.screenshot()` saves a viewport artifact and returns its path, not a
full-page capture. Secret fills may deny it; respect that policy.

Run from the app root (npm projects can use `npx e2e` instead):

```bash
pnpm exec e2e list tests/qa-ui/account-menu.e2e.ts \
  --config e2e.qa-ui.config.ts --target mobile --reporter json
pnpm exec e2e run tests/qa-ui/account-menu.e2e.ts \
  --config e2e.qa-ui.config.ts --target mobile --retries 0 \
  --output .e2e/qa-ui/PROJ-123/mobile/account-menu/test
```

Repeat with the other band targets. `list` verifies selection without starting
an engine. Give every concurrent process a different `--output`; include a
flow/run slug for explorations. Ensure `.e2e/qa-ui/` is gitignored: init's
individual output ignore entries do not necessarily cover this custom folder.
Outputs must stay inside the app project root, not at the external screenshot
root. The replay cache and app logs do not move with `--output`; preserve the
project's cache policy and avoid parallel writers to a shared app log.

## Discover an unfamiliar flow

Use one bounded charter per flow/band, naming the starting route, goal, checks,
and allowed actions. Reuse configured sessions via `--session <name>` when a
setup test declares them. For example:

```bash
pnpm exec e2e explore \
  'Starting at /account, open the account menu and navigate to Settings. Check navigation, clipping and horizontal overflow; do not change saved data.' \
  --config e2e.qa-ui.config.ts --target mobile \
  --max-steps 4 --timeout 180000 --trace on \
  --output .e2e/qa-ui/PROJ-123/mobile/account-menu/explore
```

`--max-steps` counts exploration steps, not individual actions. Ensure the
chosen agent's per-step `maxSteps`/`maxModelCalls` are suitable for exploration
(the bug-bash topic recommends at least 40); preserve its model/context and
avoid silently selecting a new provider. Exploration has no replay cache.

Read `report.json` even after a nonzero exit: `run.explore` holds steps,
budgets, assessment, and findings. `ended: step-limit/time/stuck` or blocked
steps mean incomplete coverage, not a clean sweep. A finding's `artifactId`
refers to evidence in the exploration result's attempt artifacts; inspect it,
do not invent a screenshot filename. Reports and videos can contain sensitive
data; review before exporting evidence to `~/.responsive-qa/<TASK>/<band>/`.
Include every per-flow report in the band findings' `reports` array. Map e2e
severity 5/4 to `high`, 3 to `medium`, and 2/1 to `low` in qa-ui's contract.

## Prove and recheck findings

Treat explorer findings as candidates. Reject lazy-loading, new-tab, fixture,
and environment artifacts with evidence. Follow
[e2e bug-bash verification](../../e2e/references/bug-bash.md#6-verify) for
functional candidates: write a focused test under the configured `tests` glob,
reproduce at the affected target, and require failure on the expected-behavior
assertion (`ASSERTION_FAILED`), not a missing locator, model, or app.

Preserve the original report/evidence before rerunning a path that overwrites
artifacts. Fix only confirmed issues when app changes are requested, then rerun
the repro at affected bands and retain useful regression tests. Reinspect the
intended screenshot state against Figma as well; a green functional test is not
proof of visual fidelity. Report partial/blocked coverage separately, and do
not post findings or send upstream feedback without authorization.
