#!/usr/bin/env bash
set -euo pipefail

section() {
  local file="$1"
  awk '
    /^## Launchers and dependency preflight \(mandatory\)$/ { printing = 1 }
    printing && /^## / && !/^## Launchers and dependency preflight \(mandatory\)$/ { exit }
    printing { print }
  ' "$file"
}

for file in AGENTS.md CLAUDE.md docs/CLAUDE_PROJECT_TEMPLATE.md; do
  [[ -f "$file" ]] || {
    echo "::error::missing agent instruction source: $file"
    exit 1
  }
done

agents_section="$(section AGENTS.md)"
claude_section="$(section CLAUDE.md)"

[[ -n "$agents_section" ]] || {
  echo "::error::AGENTS.md is missing the launcher and dependency preflight section"
  exit 1
}

[[ "$agents_section" == "$claude_section" ]] || {
  echo "::error::launcher and dependency preflight rules differ between AGENTS.md and CLAUDE.md"
  diff -u <(printf '%s\n' "$agents_section") <(printf '%s\n' "$claude_section") || true
  exit 1
}

grep -Fq 'Treat any ordered sequence of commands that Rory would have to copy, run, and interpret as' AGENTS.md || {
  echo "::error::agent instructions no longer classify multi-command handoffs as missing automation"
  exit 1
}

grep -Fq 'A host/container/device/credential boundary does **not** make a manual preflight or orchestration' AGENTS.md || {
  echo "::error::agent instructions no longer preserve the launcher rule across execution boundaries"
  exit 1
}

grep -Fq '**One-Command Human Handoffs**' docs/CLAUDE_PROJECT_TEMPLATE.md || {
  echo "::error::reusable project template is missing the one-command handoff principle"
  exit 1
}

echo "agent-instructions: launcher handoff boundary is synchronized"
