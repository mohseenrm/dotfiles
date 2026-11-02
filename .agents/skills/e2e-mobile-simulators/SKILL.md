---
name: e2e-mobile-simulators
description: Use for native app builds and e2e checks on local iOS simulators or Android emulators, including deep links, screenshots, and videos. Not browser-only QA.
---

# Mobile simulator checks with e2e

Use this skill with [e2e](../e2e/SKILL.md). It adds native build, device, and evidence rules to the upstream workflow.

## Establish the test boundary

1. Read the repository instructions and the owning app guide.
2. Identify the app, platform, build variant, environment, and requested flows.
3. Separate app navigation, OS link selection, and vendor attribution. Each needs separate evidence.
4. Record missing accounts, fixtures, associations, or app implementations before the run.
5. Honor explicit exclusions. Do not repeat a request for a flow that the user excludes.

Do not infer permission to send campaigns, create production data, publish associations, release apps, or merge PRs.

## Read the installed runner guide

Use the existing project configuration first. For a new harness, read `npx e2e guide setup`.
Before writing tests, read `npx e2e guide writing-tests`. Before a run, read `npx e2e guide running`.
For live MCP work, read `npx e2e guide mcp`. The installed guide takes precedence over stale examples.

Use the repository package manager. Do not bypass package-manager constraints to install e2e.
If the repository has no e2e project, create an approved harness outside the product tree.
Keep harness dependencies, reports, fixtures, and media out of unrelated product commits.

Deterministic tests need no model credentials. For `agent.*` steps, use a configured model and the upstream authentication workflow.

## Prepare a native artifact and device

### iOS

Use the actual Xcode installation. A per-command `DEVELOPER_DIR` avoids a global `xcode-select` change.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devicetypes
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list runtimes
```

- Select a simulator that meets both app and test-target OS requirements.
- Use the owning build wrapper or the correct Xcode project/workspace and scheme.
- Resolve the exact product path through build settings or a task-owned DerivedData directory. Never select an artifact with a broad glob.
- Read the bundle ID from the built `Info.plist`. Do not confuse production and development identities.
- If the required simulator is absent, create a task-owned simulator from the advertised device/runtime catalog.
- If the build reports a missing Metal Toolchain, use the documented `xcodebuild -downloadComponent MetalToolchain` fix.

### Android

```sh
adb devices -l
emulator -list-avds
```

- Use the owning Gradle wrapper and the requested module, flavor, and build type.
- Resolve the exact APK and application ID from the selected variant.
- Use an emulator from the inventory. Do not select a connected phone unless the user requests it.
- A debug application ID can match production. Use an isolated emulator before installing over that identity.

### Device safety

Run `npx agent-device doctor` before the first mobile run.
Select an explicit device in the e2e target. One device supports one worker at a time.
Close an idle session before a run uses the same device. Do not delete another session's device claim.
Use explicit device identifiers for low-level commands. Avoid `booted` with multiple active simulators.

Do not uninstall apps, clear keychains, or reset device data without approval.
Preserve existing login state unless the requested case requires a fresh install.
Record temporary preferences and boot state. Restore only the state that this task changes.
If the repository requires an environment loader, run its commands through that loader.

## Configure the mobile target

Install `e2e`, `@e2e-dev/mobile`, and required peers with the selected package manager.
Keep the engine and its pinned `agent-device` version compatible.

This configuration selects one explicit device per run:

```ts
import type { E2EConfig } from 'e2e';
import { mobile } from '@e2e-dev/mobile';

const platform = process.env.E2E_PLATFORM ?? 'ios';
if (platform !== 'ios' && platform !== 'android') {
  throw new Error('E2E_PLATFORM must be ios or android');
}
const device = process.env.E2E_DEVICE;
const bundleId = process.env.E2E_BUNDLE_ID;
if (!device || !bundleId) {
  throw new Error('Set E2E_DEVICE and E2E_BUNDLE_ID');
}

export default {
  tests: 'tests/**/*.e2e.ts',
  targets: [{
    name: platform,
    engine: mobile({ platform, device }),
    app: { bundleId, appPath: process.env.E2E_APP_PATH },
  }],
  workers: 1,
  retries: 0,
  launchTimeout: 120000,
  actionTimeout: 30000,
  assertionTimeout: 5000,
  timeout: 120000,
  trace: 'on',
  video: 'off',
} satisfies E2EConfig;
```

`E2E_APP_PATH` names the built `.app` or `.apk`. Omit it only for an approved installed-build inspection.
The engine does not install the artifact automatically. A test with an artifact calls `device.installApp()` before `app.open()`.
On mobile, `app.open()` takes no route. Use `device.openLink(url)` for a deep link.

## Write and run the requested checks

Import `test` from `@e2e-dev/mobile` and `expect` from `e2e`.
Learn labels and identifiers from the live accessibility tree before writing selectors.
For SwiftUI identifier conflicts, inspect the raw tree and the screenshot.
Nodes can remain in the tree behind another view. Tree membership alone does not prove the visible destination.

- Pin each action with a destination assertion.
- For a deep link, assert the expected resource identity, not only the app name or launch result.
- Cover cold/warm entry, required login resumption, browser intent, and rejected input within the requested scope.
- Distinguish a fixture failure from missing app support or missing associations.
- Use approved test accounts. Keep passwords in e2e `credentials` and other secrets in `secrets`.
- Hand opaque secrets only to supported runner operations. Do not unwrap them into code, logs, or CLI arguments.
- Mobile `test.setup` and browser storage-state sessions are unavailable. Do not copy browser login fixtures into mobile tests.

Run the actual test declaration by `file:line`. Re-read the line after edits.

```sh
npx e2e list --config e2e.config.ts
npx e2e run tests/mobile.e2e.ts:4 --retries 0 --output .e2e-mobile-debug
```

Do not impose a five-second global action timeout on an installation that needs longer.
Use bounded locator waits and the recorded install/launch timings. Do not add fixed sleeps.
For a failure, read the reported `trace.md` before another walk through the app.
Fix every selector that the recorded evidence covers, then rerun only the affected test.
After a pass, repeat once with `--no-cache` and normal timeouts.
Follow the owning guide's build and test time limits.

## Capture useful evidence

Start a recording after setup, on the screen that matters. Use manual recording with the test's `video: 'off'`.

```ts
await app.startRecording({ name: 'destination-proof' });
try {
  // Perform the requested action and assert its actual destination here.
  await app.screenshot('destination');
} finally {
  await app.stopRecording();
}
```

Do not copy the comment as a test body. Replace it with the observed actions and assertions.
For credentials, stop recording before entry. Videos do not mask secrets automatically.
Inspect screenshots and decoded video frames before sharing them.
Keep stable media copies outside runner output that another run can replace.
For a PR upload, use the available PR-media workflow and inspect the published body afterward.

## Keep proof claims separate

`device.openLink` targets the pinned app. On Android, this can restrict the intent to that package.
Successful app-directed navigation does not prove OS association or default-app selection.
`simctl openurl` exit zero does not prove that the intended screen opened.
Use a real external tap and signed-device evidence for release acceptance.
Do not use a typed Safari address as the only Universal Link proof.

For an unrestricted Android selection test, use a browsable VIEW intent without a package restriction.
Inspect domain verification separately with `pm get-app-links` on a supported Android version.
Do not disable verification to manufacture a pass.

For vendor links, use unmodified generated URLs and owned QA recipients.
Do not invent opaque keys, rewrite prefixes, or prefetch measured links to inspect them.
Keep vendor clicks separate from product attribution and destination navigation.
Use zero retries for measured clicks. Report the actual resolver method and evidence limits.

Finish with the artifact/build identity, device/runtime, executed results, media paths, skipped cases, and remaining external gates.
