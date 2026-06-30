---
name: qa-ui
description: Drive a set of app flows through Playwright at every breakpoint band and hunt for responsive/visual bugs, then fix them. Use when asked to QA a page or flow across screen sizes, check responsiveness, screenshot flows at mobile/tablet/desktop, do a visual sweep before a PR, "make sure it looks right on every device", or "check the implementation matches the Figma design". Optionally compares each flow against a Figma design per band when design node URLs are provided. Fans out one agent per band (mobile, tablet, desktop, 2xl) in parallel; agents report findings, then issues are triaged and fixed. Screenshots are keyed by Linear ID / task and stored outside any repo.
---

# qa-ui

Responsive UI QA sweep. Capture a set of flows across breakpoint bands with **Playwright**, eyeball each
screenshot for responsive/visual defects - and, when a **Figma design** is
provided, diff each flow against its design frame per band - then fix what's
broken. The work fans out: **one agent per band** runs concurrently, each reports
findings, then you triage and fix.

This is a QA-and-fix loop, not a staging-vs-localhost diff. For before/after
migration diffing, use a dedicated visual-diff tool instead.

## What you need before starting

1. **A task key** for screenshot storage. Prefer the **Linear issue ID**
   (e.g. `PROJ-123`). If there's no Linear issue, use a short kebab slug of the
   task (e.g. `settings-page-responsive`). Everything is keyed by this.
2. **A base URL** the flows live under (a running localhost dev server, a stage
   URL, or production). Confirm it's reachable before fanning out.
3. **The list of flows** to sweep. A flow is a named page plus optional
   interaction steps. If the user didn't enumerate them, propose a list from the
   routes/components in scope and confirm.
4. **Auth, if the flows are behind login.** Capture a session cookie once and
   pass it to every band (see Auth below). Without it, protected flows redirect
   to login and you'll screenshot the login page at every size.
5. **A Figma design, if one exists (optional).** When the user has a Figma file
   with the designed flows, the sweep compares the implementation against the
   design per band, not just against itself. Ask for the per-frame node URLs and
   wire them into the flows file (see Figma below). Without a design, the sweep
   still runs - it just hunts for self-evident defects.

If any of these is unknown, ask before capturing. Don't guess flows for an app
you haven't looked at.

## One-time setup (per machine)

The capture script owns its own Playwright. Run once; it's a no-op afterward:

```bash
cd ~/.claude/skills/qa-ui/scripts
pnpm install >/dev/null && pnpm exec playwright install chromium
```

`node_modules/` here is gitignored - never committed.

## Bands

| Band | Viewport | Notes |
| --- | --- | --- |
| `mobile` | 390x844 @2x, touch | iPhone-class |
| `tablet` | 820x1180 @2x, touch | iPad-class |
| `desktop` | 1440x900 | laptop |
| `2xl` | 1920x1080 | large desktop |

Default sweep is `mobile`, `tablet`, `desktop`. Add `2xl` when the user cares
about wide layouts. One agent per band.

## Step 1 - Build the flows file

Write one JSON file describing the flows. The same file is reused by every band.
Save it under the task's screenshot dir so it travels with the run:

```bash
mkdir -p ~/.responsive-qa/<TASK>
$EDITOR ~/.responsive-qa/<TASK>/flows.json
```

Schema - an array of flows:

```json
[
  { "name": "home", "url": "http://localhost:3000/" },
  {
    "name": "dashboard",
    "url": "http://localhost:3000/dashboard",
    "steps": [
      { "waitFor": "[data-testid='main-content']" },
      { "scrollToBottom": true }
    ]
  },
  {
    "name": "login-then-account",
    "url": "http://localhost:3000/login",
    "steps": [
      { "fill": ["#email", "test@example.com"] },
      { "fill": ["#password", "password"] },
      { "click": "button[type=submit]" },
      { "waitForUrl": "**/account" }
    ]
  },
  {
    "name": "settings",
    "url": "http://localhost:3000/settings",
    "figma": {
      "desktop": "https://www.figma.com/design/<KEY>/<FILE>?node-id=12-345",
      "mobile": "https://www.figma.com/design/<KEY>/<FILE>?node-id=12-678"
    }
  }
]
```

Supported steps: `click`, `fill` (`[selector, text]`), `waitFor` (selector),
`waitForUrl` (glob), `press` (key), `wait` (ms), `scrollToBottom`.

The optional `figma` field maps a band name to the Figma node URL of that flow's
design at that size. The capture script ignores it (it's metadata for the band
agent). Use band keys (`mobile`/`tablet`/`desktop`/`2xl`); designs usually only
have a mobile and a desktop frame, so a band agent reuses the closest available
frame (`tablet` → `desktop` design, `2xl` → `desktop` design) unless a specific
one is given. A flow with no `figma` entry is QA'd for self-evident defects only.

## Step 2 - Fan out, one agent per band (PARALLEL)

Spawn the band agents **in a single message** so they run concurrently. Give
each the same flows file and task, differing only in `--band`. Each agent:

1. Runs the capture for its band.
2. Reads back every PNG it produced.
3. Reports a structured findings list (see contract below).

The capture command each agent runs:

```bash
node ~/.claude/skills/qa-ui/scripts/capture.mjs \
  --task <TASK> --band <BAND> --flows ~/.responsive-qa/<TASK>/flows.json
```

Add `--cookie` / `--out-root` as needed (see below). It writes:

```
~/.responsive-qa/<TASK>/<band>/NN-<slug>.png      one full-page PNG per flow
~/.responsive-qa/<TASK>/<band>/manifest.json      run record (status, errors, console errors, file paths)
```

and prints the manifest JSON to stdout.

### Band-agent prompt template

Spawn each with the `general-purpose` agent type. Use this prompt, substituting
`<BAND>` and `<TASK>`:

> You are the **<BAND>** band agent for a responsive QA sweep of task **<TASK>**.
> 1. Run exactly:
>    `node ~/.claude/skills/qa-ui/scripts/capture.mjs --task <TASK> --band <BAND> --flows ~/.responsive-qa/<TASK>/flows.json`
> 2. Read the manifest it prints. For every flow, **Read the PNG file** it lists
>    and inspect the rendering at <BAND> width.
> 3. **If the flow has a `figma` node for this band** (look it up in the flows
>    file; for `tablet`/`2xl` fall back to the `desktop` node when no exact match
>    exists): fetch the design frame with the Figma MCP `get_screenshot` tool for
>    that node URL, then compare it against the Playwright capture. Report any
>    `designMismatch` - wrong spacing, color, type scale, missing/extra elements,
>    wrong order, components that don't match the design. Note when the
>    difference is expected at this band (the design only specced desktop, etc.).
>    Skip this step for flows with no `figma` node.
> 4. Report findings as the JSON contract below - nothing else. Be specific:
>    name the flow, the file, and what's wrong. Flag HTTP errors, console errors,
>    blank/error pages, overflow, overlap, clipped text, untapped touch targets
>    (mobile/tablet), broken layout, off-screen content, and `designMismatch`
>    against Figma. A flow that renders correctly and matches the design gets
>    `"issues": []`.
>
> Findings contract (return this and only this):
> ```json
> {
>   "band": "<BAND>",
>   "flows": [
>     { "name": "...", "file": "...", "status": 200, "ok": true, "figmaNode": "<url or null>",
>       "issues": [ { "type": "visual|console|http|designMismatch", "severity": "high|medium|low", "summary": "...", "evidence": "what in the screenshot/console/design shows it" } ] }
>   ]
> }
> ```

Because each band is a separate agent reading only its own images, the band
results don't collide - you keep the conclusions, not a flood of image dumps.
Band agents need the Figma MCP server available (it's how they pull design
frames); if it isn't connected, they fall back to self-evident-defect QA and say
so in their report.

## Step 3 - Triage

Collect the three (or four) band reports. Merge into one issue list. For each
issue note which bands it appears in - a bug on mobile only is a responsive bug;
a bug on every band is a general bug. A `designMismatch` on one band but not
another usually means a breakpoint isn't tracking the design. De-duplicate the
same defect reported by multiple bands into one entry that lists its bands. Sort
by severity, keeping `designMismatch` and functional bugs above cosmetic ones.
Present this table to the user before fixing anything substantial.

## Step 4 - Fix

Fix the confirmed issues in the codebase, smallest correct change first.
Responsive bugs usually live in CSS/Tailwind breakpoint classes, container
widths, flex/grid wrapping, or conditional rendering. After fixing:

1. Reload the dev server if needed.
2. Re-run **only the affected band(s)** for the affected flow(s) - you can pass
   a trimmed flows file or `--url` for a single page.
3. Read the new screenshot and confirm the fix. Never claim fixed without
   re-capturing and looking.

## Auth (flows behind login)

Capture a session cookie once (e.g. log in manually in a browser and copy the
cookie, or script a login flow and dump `context.cookies()`), then pass it to
every band. Format is comma-separated entries, each `key=value;` pairs:

```bash
--cookie "name=_session;value=abc123;domain=localhost;path=/"
```

Alternatively, put a login as the first `steps` of each protected flow (see the
`login-then-account` example) so each capture authenticates itself.

## Figma (design comparison)

When the user has a Figma design of the flows, the sweep grades the
implementation against the design instead of only against itself - this is where
responsive bugs and design drift surface most clearly, because the design
usually specifies both a mobile and a desktop frame.

Wiring it up:

1. Get the Figma file URL from the user. A single file usually holds every flow
   as separate frames at one or more sizes.
2. Identify the **node URL per flow per size**. Open the frame in Figma and copy
   its link (it carries `?node-id=…`), or use the Figma MCP `get_metadata` tool
   on the file to list frames and their node ids, then map each to a flow.
3. Put those URLs in each flow's `figma` field, keyed by band. Provide whatever
   sizes the design has - typically `mobile` and `desktop`. Band agents reuse the
   nearest frame for bands the design didn't spec (`tablet`/`2xl` → `desktop`).

Each band agent then pulls its design frame via `get_screenshot` and diffs it
against the live capture, reporting `designMismatch` issues. The comparison is a
visual judgment by the agent, not pixel-diffing - it flags meaningful drift
(spacing, color, type, missing/extra/reordered elements), not sub-pixel noise.

If the Figma MCP server isn't connected, agents skip the design diff and fall
back to self-evident-defect QA, noting that in their report.

## Storage and hygiene

- Root is `~/.responsive-qa/<TASK>/<band>/`, **outside any repo** - screenshots
  are never committed. Override the root with `--out-root <dir>` if needed.
- Keying by Linear ID means re-running the same task overwrites cleanly and you
  can always find the run later by its issue.
- For a PR, attach the relevant PNGs to the Linear issue or PR body manually;
  don't add them to the git working tree.

## Notes

- The script uses `networkidle` + a 500ms settle before each shot; bump with a
  `{ "wait": <ms> }` step for slow pages.
- On any per-flow failure the script still writes whatever rendered and records
  the error in the manifest, so a single bad flow never aborts the band.
- Full-page screenshots can be tall; that's intended for spotting layout bugs
  below the fold.
