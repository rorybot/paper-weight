#!/usr/bin/env bash
# Best-effort: when a PR merges with Closes/Fixes #N, set project Status=Done and close issue.
# Needs: gh auth with project scope (GITHUB_TOKEN often lacks user-project write — non-fatal).
set -euo pipefail

PR_BODY="${PR_BODY:-}"
PR_TITLE="${PR_TITLE:-}"
REPO="${REPO:-rorybot/paper-weight}"
OWNER="${OWNER:-rorybot}"
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
PROJECT_ID="${PROJECT_ID:-PVT_kwHOAcWVcc4BdhZ_}"
STATUS_FIELD_ID="${STATUS_FIELD_ID:-PVTSSF_lAHOAcWVcc4BdhZ_zhYCXX4}"
DONE_OPTION_ID="${DONE_OPTION_ID:-98236657}"

TEXT="${PR_TITLE}"$'\n'"${PR_BODY}"
mapfile -t ISSUES < <(echo "$TEXT" | grep -Eio '([Cc]loses|[Ff]ixes|[Rr]esolves)[[:space:]]*#[0-9]+' | grep -Eo '[0-9]+' | sort -u || true)

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  echo "kanban-on-merge: no Closes/Fixes #N in PR — skip"
  exit 0
fi

if ! command -v gh >/dev/null; then
  echo "kanban-on-merge: gh not available — skip"
  exit 0
fi

for n in "${ISSUES[@]}"; do
  echo "kanban-on-merge: issue #$n → Done"
  gh issue close "$n" --repo "$REPO" 2>/dev/null || true

  item_id="$(
    gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 50 --format json 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((i['id'] for i in d.get('items',[]) if i.get('content',{}).get('number')==int(sys.argv[1])),''))" "$n" 2>/dev/null \
      || true
  )"

  if [[ -z "$item_id" ]]; then
    echo "kanban-on-merge: #$n not on project or project API denied — skip status field"
    continue
  fi

  if gh project item-edit \
      --id "$item_id" \
      --project-id "$PROJECT_ID" \
      --field-id "$STATUS_FIELD_ID" \
      --single-select-option-id "$DONE_OPTION_ID" 2>/dev/null; then
    echo "kanban-on-merge: #$n project Status=Done"
  else
    echo "kanban-on-merge: could not edit project field for #$n (token may lack project scope)"
  fi
done

exit 0
