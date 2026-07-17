#!/usr/bin/env bash
# Non-interactive GitHub CLI health check for agents running in a POSIX shell.
# Exit 0 = ready for paper-weight kanban work. Exit 1 = a real local auth/tooling problem.

set -u
set -o pipefail

readonly owner="rorybot"
readonly project_number="1"
readonly required_scopes=("repo" "project" "read:org")

if ! command -v gh >/dev/null 2>&1; then
  printf 'FAIL: gh is not on PATH in this POSIX environment.\n' >&2
  exit 1
fi

printf 'gh: %s\n' "$(command -v gh)"

if ! auth_status="$(gh auth status 2>&1)"; then
  printf '%s\n' "$auth_status" >&2
  printf 'FAIL: gh is not authenticated in this POSIX environment.\n' >&2
  exit 1
fi

if scope_line="$(printf '%s\n' "$auth_status" | grep -m1 'Token scopes:')"; then
  for scope in "${required_scopes[@]}"; do
    if [[ "$scope_line" != *"$scope"* ]]; then
      printf "FAIL: gh auth is missing required scope '%s'.\n" "$scope" >&2
      exit 1
    fi
  done
else
  printf 'WARN: gh did not report token scopes; continuing with the project API smoke test.\n'
fi

if ! gh project view "$project_number" --owner "$owner" --format json >/dev/null 2>&1; then
  printf 'FAIL: cannot read GitHub Project #%s for %s.\n' "$project_number" "$owner" >&2
  printf 'Check this environment'\''s gh auth, network, scopes, or SSO.\n' >&2
  exit 1
fi

printf 'OK: native POSIX gh auth can read project #%s.\n' "$project_number"
printf 'Do not run gh auth login/refresh unless this check exits 1.\n'
