#!/usr/bin/env bash
# classify-files.sh — Bucket changed files by category for smart agent routing.
#
# Usage: classify-files.sh /tmp/pr-review-bundle.json
#
# Reads the bundle from load-pr.sh, classifies each file, and emits a JSON object:
#   {
#     "buckets": {
#       "backend":   ["src/api/users.ts", ...],
#       "frontend":  ["src/components/Button.tsx", ...],
#       "infra":     ["Dockerfile", "k8s/deploy.yaml", ...],
#       "test":      ["test/users.test.ts", ...],
#       "docs":      ["README.md", ...],
#       "generated": ["package-lock.json", "dist/bundle.js", ...]
#     },
#     "stats": { "backend": 3, "frontend": 2, ... }
#   }
#
# Classification heuristics:
#   - generated: lockfiles, dist/build/node_modules/vendor, snapshots, binaries
#   - test:      path contains /test/, /tests/, /__tests__/, *.test.*, *.spec.*
#   - docs:      *.md, *.mdx, *.rst, *.txt, docs/**
#   - infra:     Dockerfile*, *.yaml, *.yml, *.tf, *.tfvars, k8s/**, .github/**, Makefile
#   - frontend:  *.tsx, *.jsx, *.vue, *.svelte, *.css, *.scss, *.html, *.astro
#   - backend:   everything else with code extensions
set -euo pipefail

BUNDLE="${1:-}"
[[ -z "$BUNDLE" || ! -r "$BUNDLE" ]] && { echo "classify-files.sh: missing or unreadable bundle: $BUNDLE" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "classify-files.sh: jq not found" >&2; exit 2; }

# Read filenames from bundle
mapfile -t FILES < <(jq -r '.files[].filename' "$BUNDLE")

declare -a GENERATED=() TEST=() DOCS=() INFRA=() FRONTEND=() BACKEND=()

classify() {
  local f="$1"

  # generated — order matters, check first
  case "$f" in
    package-lock.json|pnpm-lock.yaml|yarn.lock|Gemfile.lock|go.sum|Cargo.lock|poetry.lock|composer.lock|*.lockb)
      echo "generated"; return ;;
  esac
  case "$f" in
    */dist/*|dist/*|*/build/*|build/*|*/node_modules/*|node_modules/*|*/vendor/*|vendor/*|*/.next/*|.next/*|*/.nuxt/*|.nuxt/*)
      echo "generated"; return ;;
    *.generated.ts|*.generated.js|*.generated.tsx|*.gen.go|*_pb.go|*_pb.ts|*.pb.go|*.min.js|*.min.css)
      echo "generated"; return ;;
    */__snapshots__/*|*.snap)
      echo "generated"; return ;;
    *.png|*.jpg|*.jpeg|*.gif|*.svg|*.pdf|*.ico|*.woff|*.woff2|*.ttf|*.otf|*.webp)
      echo "generated"; return ;;
  esac

  # test
  case "$f" in
    */test/*|test/*|*/tests/*|tests/*|*/__tests__/*|__tests__/*|*/spec/*|spec/*)
      echo "test"; return ;;
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx|*_test.go|*_test.py|*_spec.rb)
      echo "test"; return ;;
  esac

  # docs
  case "$f" in
    *.md|*.mdx|*.rst|*.txt|*.adoc)
      echo "docs"; return ;;
    docs/*|*/docs/*|doc/*|*/doc/*)
      echo "docs"; return ;;
  esac

  # infra
  case "$f" in
    Dockerfile|Dockerfile.*|*.dockerfile|docker-compose*.y*ml)
      echo "infra"; return ;;
    *.yaml|*.yml|*.tf|*.tfvars|*.hcl)
      echo "infra"; return ;;
    Makefile|makefile|GNUmakefile|*.mk)
      echo "infra"; return ;;
    .github/*|k8s/*|kubernetes/*|terraform/*|ansible/*|helm/*|charts/*|.circleci/*|.gitlab-ci.yml)
      echo "infra"; return ;;
    *.sh|*.bash|*.zsh)
      echo "infra"; return ;;
  esac

  # frontend
  case "$f" in
    *.tsx|*.jsx|*.vue|*.svelte|*.astro)
      echo "frontend"; return ;;
    *.css|*.scss|*.sass|*.less|*.stylus|*.styl)
      echo "frontend"; return ;;
    *.html|*.htm)
      echo "frontend"; return ;;
  esac

  # backend (default for code)
  case "$f" in
    *.ts|*.js|*.mts|*.cts|*.mjs|*.cjs)
      echo "backend"; return ;;
    *.py|*.go|*.rb|*.rs|*.java|*.kt|*.scala|*.swift|*.cs|*.cpp|*.cc|*.c|*.h|*.hpp|*.php|*.ex|*.exs|*.erl|*.elm|*.clj|*.cljs|*.lua)
      echo "backend"; return ;;
    *.sql|*.proto|*.graphql|*.gql)
      echo "backend"; return ;;
  esac

  # Unknown — bucket as backend so it still gets reviewed
  echo "backend"
}

for f in "${FILES[@]}"; do
  bucket=$(classify "$f")
  case "$bucket" in
    generated) GENERATED+=("$f") ;;
    test)      TEST+=("$f") ;;
    docs)      DOCS+=("$f") ;;
    infra)     INFRA+=("$f") ;;
    frontend)  FRONTEND+=("$f") ;;
    backend)   BACKEND+=("$f") ;;
  esac
done

# Emit JSON
jq -n \
  --argjson generated "$(printf '%s\n' "${GENERATED[@]+${GENERATED[@]}}" | jq -R . | jq -s .)" \
  --argjson test      "$(printf '%s\n' "${TEST[@]+${TEST[@]}}"      | jq -R . | jq -s .)" \
  --argjson docs      "$(printf '%s\n' "${DOCS[@]+${DOCS[@]}}"      | jq -R . | jq -s .)" \
  --argjson infra     "$(printf '%s\n' "${INFRA[@]+${INFRA[@]}}"     | jq -R . | jq -s .)" \
  --argjson frontend  "$(printf '%s\n' "${FRONTEND[@]+${FRONTEND[@]}}"  | jq -R . | jq -s .)" \
  --argjson backend   "$(printf '%s\n' "${BACKEND[@]+${BACKEND[@]}}"   | jq -R . | jq -s .)" \
  '{
    buckets: {
      backend:  ($backend  | map(select(. != ""))),
      frontend: ($frontend | map(select(. != ""))),
      infra:    ($infra    | map(select(. != ""))),
      test:     ($test     | map(select(. != ""))),
      docs:     ($docs     | map(select(. != ""))),
      generated:($generated| map(select(. != "")))
    }
  } | .stats = (.buckets | map_values(length))'
