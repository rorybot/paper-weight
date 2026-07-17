#!/usr/bin/env bash
# Set GitHub Project #1 Status for a paper-weight issue and verify the result.

set -euo pipefail

readonly owner="rorybot"
readonly project_number="1"
readonly project_id="PVT_kwHOAcWVcc4BdhZ_"
readonly status_field_id="PVTSSF_lAHOAcWVcc4BdhZ_zhYCXX4"
readonly repo="rorybot/paper-weight"

usage() {
  printf 'Usage: %s --issue <N> --status <Status> [--close-issue|--reopen-issue]\n' "$0" >&2
  printf 'Status: Backlog | Ready | In progress | In review | Done\n' >&2
}

issue=""
status=""
close_issue=false
reopen_issue=false

while (($#)); do
  case "$1" in
    --issue|-Issue)
      issue="${2:-}"
      shift 2
      ;;
    --status|-Status)
      status="${2:-}"
      shift 2
      ;;
    --close-issue|-CloseIssue)
      close_issue=true
      shift
      ;;
    --reopen-issue|-ReopenIssue)
      reopen_issue=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ ! "$issue" =~ ^[0-9]+$ ]] || [[ -z "$status" ]]; then
  usage
  exit 2
fi

case "$status" in
  "Backlog") option_id="f75ad846" ;;
  "Ready") option_id="61e4505c" ;;
  "In progress") option_id="47fc9ee4" ;;
  "In review") option_id="df73e18b" ;;
  "Done") option_id="98236657" ;;
  *)
    usage
    exit 2
    ;;
esac

row="$(
  gh project item-list "$project_number" \
    --owner "$owner" \
    --limit 100 \
    --format json \
    --jq ".items[] | select(.content.number == $issue) | [.id, .status, .title] | @tsv"
)"

if [[ -z "$row" ]]; then
  printf 'FAIL: issue #%s is not on project #%s.\n' "$issue" "$project_number" >&2
  printf 'Add it with: gh project item-add %s --owner %s --url https://github.com/%s/issues/%s\n' \
    "$project_number" "$owner" "$repo" "$issue" >&2
  exit 1
fi

IFS=$'\t' read -r item_id current_status title <<<"$row"
printf 'Issue #%s: %s -> %s\n' "$issue" "$current_status" "$status"

gh project item-edit \
  --id "$item_id" \
  --project-id "$project_id" \
  --field-id "$status_field_id" \
  --single-select-option-id "$option_id" \
  >/dev/null

if [[ "$status" == "Done" ]] || [[ "$close_issue" == true ]]; then
  gh issue close "$issue" --repo "$repo" >/dev/null
elif [[ "$reopen_issue" == true ]]; then
  gh issue reopen "$issue" --repo "$repo" >/dev/null
fi

verified_status="$(
  gh project item-list "$project_number" \
    --owner "$owner" \
    --limit 100 \
    --format json \
    --jq ".items[] | select(.content.number == $issue) | .status"
)"

if [[ "$verified_status" != "$status" ]]; then
  printf "FAIL: status mismatch; wanted '%s', got '%s'.\n" "$status" "$verified_status" >&2
  exit 1
fi

printf 'Verified: #%s status=%s title=%s\n' "$issue" "$verified_status" "$title"
printf 'Now update kanban/board.md and the feature spec to match.\n'
