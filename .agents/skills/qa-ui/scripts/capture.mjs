#!/usr/bin/env node
// Responsive QA sweep capture: drive a set of flows through Playwright at one
// breakpoint band and write full-page screenshots keyed by task id.
//
// Zero project dependencies: resolves Playwright via the caller's npx. Each of
// the parallel band-agents invokes this once for its own band.
//
// Usage:
//   node capture.mjs --task PROJ-123 --band mobile --flows flows.json [opts]
//
// flows.json is an array of { name, url, steps? } where steps is an optional
// array of Playwright actions applied before the screenshot:
//   { "click": "<selector>" } | { "fill": ["<selector>", "<text>"] }
//   | { "waitFor": "<selector>" } | { "waitForUrl": "<glob>" }
//   | { "press": "<key>" } | { "wait": <ms> } | { "scrollToBottom": true }
//
// Output:
//   <root>/<task>/<band>/<NN>-<slug>.png        one full-page PNG per flow
//   <root>/<task>/<band>/manifest.json          machine-readable run record
// Default root: ~/.responsive-qa  (override with --out-root). Never inside a repo.

import { mkdir, writeFile, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, isAbsolute, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const __dirname = dirname(fileURLToPath(import.meta.url));

const BANDS = {
  // name -> { width, height, deviceScaleFactor, isMobile }
  mobile: { width: 390, height: 844, deviceScaleFactor: 2, isMobile: true },
  tablet: { width: 820, height: 1180, deviceScaleFactor: 2, isMobile: true },
  desktop: { width: 1440, height: 900, deviceScaleFactor: 1, isMobile: false },
  "2xl": { width: 1920, height: 1080, deviceScaleFactor: 1, isMobile: false },
};

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) out[key] = true;
      else (out[key] = next), i++;
    }
  }
  return out;
}

function slugify(s) {
  return String(s)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

async function resolveChromium() {
  // Resolve Playwright from, in order: the skill's own node_modules (installed
  // once by the SKILL), the caller's cwd, then this script's own resolution.
  const candidates = [join(__dirname, "noop.js"), join(process.cwd(), "noop.js")];
  for (const base of candidates) {
    const require = createRequire(base);
    for (const mod of ["playwright", "playwright-core", "@playwright/test"]) {
      try {
        return require(mod).chromium;
      } catch {}
    }
  }
  return (await import("playwright")).chromium;
}

async function applyStep(page, step) {
  if (step.click) return page.click(step.click, { timeout: 15000 });
  if (step.fill) return page.fill(step.fill[0], step.fill[1], { timeout: 15000 });
  if (step.waitFor) return page.waitForSelector(step.waitFor, { timeout: 20000 });
  if (step.waitForUrl) return page.waitForURL(step.waitForUrl, { timeout: 20000 });
  if (step.press) return page.keyboard.press(step.press);
  if (typeof step.wait === "number") return page.waitForTimeout(step.wait);
  if (step.scrollToBottom)
    return page.evaluate(async () => {
      await new Promise((res) => {
        let y = 0;
        const t = setInterval(() => {
          window.scrollBy(0, 400);
          y += 400;
          if (y >= document.body.scrollHeight) {
            clearInterval(t);
            window.scrollTo(0, 0);
            res();
          }
        }, 50);
      });
    });
  throw new Error(`unknown step: ${JSON.stringify(step)}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const task = args.task;
  const band = args.band;
  if (!task || !band) {
    console.error("error: --task and --band are required");
    process.exit(2);
  }
  const viewport = BANDS[band];
  if (!viewport) {
    console.error(`error: unknown band '${band}'. one of: ${Object.keys(BANDS).join(", ")}`);
    process.exit(2);
  }

  let flows;
  if (args.flows) {
    flows = JSON.parse(await readFile(args.flows, "utf8"));
  } else if (args.url) {
    flows = [{ name: args.name || "page", url: args.url }];
  } else {
    console.error("error: provide --flows <file.json> or --url <url>");
    process.exit(2);
  }

  const root = args["out-root"]
    ? isAbsolute(args["out-root"])
      ? args["out-root"]
      : join(process.cwd(), args["out-root"])
    : join(homedir(), ".responsive-qa");
  const outDir = join(root, task, band);
  await mkdir(outDir, { recursive: true });

  const chromium = await resolveChromium();
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: viewport.deviceScaleFactor,
    isMobile: viewport.isMobile,
    hasTouch: viewport.isMobile,
  });
  if (args.cookie) {
    // --cookie name=value;domain=...;url=... repeated, comma-separated entries
    const cookies = String(args.cookie)
      .split(",")
      .map((c) => {
        const obj = {};
        c.split(";").forEach((kv) => {
          const [k, v] = kv.split("=");
          obj[k.trim()] = v?.trim();
        });
        return obj;
      });
    await context.addCookies(cookies);
  }

  const results = [];
  for (let i = 0; i < flows.length; i++) {
    const flow = flows[i];
    const idx = String(i + 1).padStart(2, "0");
    const slug = slugify(flow.name || `flow-${i + 1}`);
    const file = join(outDir, `${idx}-${slug}.png`);
    const consoleErrors = [];
    const page = await context.newPage();
    page.on("console", (m) => m.type() === "error" && consoleErrors.push(m.text()));
    page.on("pageerror", (e) => consoleErrors.push(String(e)));
    const record = { name: flow.name, url: flow.url, band, file, ok: false };
    try {
      const resp = await page.goto(flow.url, { waitUntil: "networkidle", timeout: 45000 });
      record.status = resp?.status() ?? null;
      for (const step of flow.steps || []) await applyStep(page, step);
      await page.waitForTimeout(500);
      await page.screenshot({ path: file, fullPage: true });
      record.ok = true;
    } catch (err) {
      record.error = String(err?.message || err);
      try {
        await page.screenshot({ path: file, fullPage: true });
      } catch {}
    }
    record.consoleErrors = consoleErrors.slice(0, 20);
    results.push(record);
    await page.close();
    const tag = record.ok ? "ok " : "ERR";
    console.error(`[${band}] ${tag} ${idx}-${slug}  ${record.status ?? ""} ${record.error ?? ""}`);
  }

  await context.close();
  await browser.close();

  const manifest = { task, band, viewport, generatedFlows: flows.length, results };
  await writeFile(join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2));
  // stdout = the manifest, for the calling agent to read
  console.log(JSON.stringify(manifest, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
