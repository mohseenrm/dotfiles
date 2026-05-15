#!/usr/bin/env bash
# detect-preview-url.sh — Find a deploy preview URL for a PR (for UX screenshots).
#
# Usage: detect-preview-url.sh <bundle.json>
#
# Output (one of):
#   - On stdout: the preview URL (e.g. "https://myapp-feature-x-org.vercel.app")
#   - On stdout: empty string + exit 0 if no URL found (caller skips screenshots)
#
# Detection sources, in order:
#   1. PR body — common preview-deploy markers (Vercel, Netlify, Cloudflare, Render)
#   2. PR comments (existing_reviews/comments in bundle) — bot comments from
#      deploy services that post URLs as PR comments
#   3. Status check details URLs — Vercel/Netlify post a check with target_url
#
# Detection is best-effort. False positives are acceptable (UX agent will fail
# gracefully on a bad URL); false negatives mean "skip screenshots, note it."
set -euo pipefail

BUNDLE="${1:-}"
[[ -z "$BUNDLE" || ! -r "$BUNDLE" ]] && { echo "detect-preview-url.sh: missing or unreadable bundle: $BUNDLE" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "detect-preview-url.sh: jq not found" >&2; exit 2; }

KIND=$(jq -r '.kind' "$BUNDLE")

# Local diffs and file-based diffs cannot have a preview URL
if [[ "$KIND" != "github" ]]; then
  echo ""
  exit 0
fi

BODY=$(jq -r '.body // ""' "$BUNDLE")

# Common preview-URL patterns. Match whole URLs, return the first hit.
# Order: most specific to least specific to avoid false matches.
extract_url() {
  # Note: ] is intentionally NOT in the negated char class because escaping it
  # inside POSIX ERE [^...] is fragile across shells. URLs rarely contain
  # literal ] anyway; if one shows up, trailing chars get dropped — acceptable.
  # `|| true` suppresses grep's exit-1-on-no-match so `set -e` won't kill the script.
  local text="$1"
  echo "$text" | grep -oE 'https://[a-zA-Z0-9._-]+\.(vercel\.app|netlify\.app|pages\.dev|onrender\.com|herokuapp\.com|fly\.dev)(/[^[:space:]"<>)]*)?' 2>/dev/null | head -1 || true
}

# 1. Try PR body first (most reliable when the user posts a preview link)
URL=$(extract_url "$BODY")
if [[ -n "$URL" ]]; then
  echo "$URL"
  exit 0
fi

# 2. Try the bundle's stored review/comment bodies (bot comments)
REVIEW_BODIES=$(jq -r '.existing_reviews[]?.body // ""' "$BUNDLE")
URL=$(extract_url "$REVIEW_BODIES")
if [[ -n "$URL" ]]; then
  echo "$URL"
  exit 0
fi

# 3. Status checks — query gh for check_runs with target_urls
# This requires a fresh gh call since the bundle doesn't include target_urls
OWNER=$(jq -r '.owner' "$BUNDLE")
REPO=$(jq -r '.repo' "$BUNDLE")
HEAD_SHA=$(jq -r '.head_sha' "$BUNDLE")

if [[ -n "$OWNER" && -n "$REPO" && -n "$HEAD_SHA" ]] && command -v gh >/dev/null 2>&1; then
  # `|| true` on every fallible step: this entire branch is best-effort.
  # gh api may 404, jq may filter to nothing, grep may match nothing.
  # None of those are errors — they just mean "no preview URL from this source".
  CHECK_URLS=$( (gh api "repos/${OWNER}/${REPO}/commits/${HEAD_SHA}/check-runs" 2>/dev/null || echo '{}') | \
    jq -r '.check_runs[]? | select(.name | test("vercel|netlify|cloudflare|render"; "i")) | .details_url // ""' 2>/dev/null | \
    (grep -v '^$' || true) | head -5)

  if [[ -n "$CHECK_URLS" ]]; then
    # The check details_url is usually the dashboard, not the preview itself.
    # We won't follow it (too brittle). Just return the first check URL;
    # UX agent can decide what to do with it.
    URL=$(extract_url "$CHECK_URLS")
    if [[ -n "$URL" ]]; then
      echo "$URL"
      exit 0
    fi
  fi
fi

# Nothing found — return empty string on stdout, exit 0. An empty result is
# a legitimate outcome (most PRs lack preview URLs), not a failure.
echo ""
exit 0
