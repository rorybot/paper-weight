#!/usr/bin/env bash
# Fail when a PR touches 2+ product lanes without an explicit cross-lane allow.
# Allow: labels cross-lane|chore|platform  OR branch chore/*|fix/*|docs/*|ci/*
set -euo pipefail

BASE_SHA="${BASE_SHA:-origin/master}"
HEAD_SHA="${HEAD_SHA:-HEAD}"
PR_LABELS="${PR_LABELS:-}"
HEAD_REF="${HEAD_REF:-}"

if git rev-parse --verify "$BASE_SHA" >/dev/null 2>&1; then
  RANGE="${BASE_SHA}...${HEAD_SHA}"
else
  RANGE="origin/master...HEAD"
fi

mapfile -t FILES < <(git diff --name-only "$RANGE" | sed '/^$/d' || true)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "lane-guard: no changed files"
  exit 0
fi

# Explicit allow for process/infra PRs
if [[ "$HEAD_REF" =~ ^(chore|fix|docs|ci|dependabot)/ ]]; then
  echo "lane-guard: branch '$HEAD_REF' is process/infra — OK"
  exit 0
fi

IFS=',' read -r -a LABEL_ARR <<< "$PR_LABELS"
for lab in "${LABEL_ARR[@]}"; do
  lab_trim="$(echo "$lab" | xargs)"
  case "$lab_trim" in
    cross-lane|chore|platform|ci)
      echo "lane-guard: label '$lab_trim' allows multi-lane — OK"
      exit 0
      ;;
  esac
done

# Map path → lane token
lane_for() {
  local f="$1"
  case "$f" in
    host/lib/paper_weight/weather/*|host/test/paper_weight/weather/*|src/device-ui/src/screens/weather/*|src/device-ui/src/protocol/weather.ts|features/weather/*)
      echo weather ;;
    host/lib/paper_weight/feed/*|host/test/paper_weight/feed/*|src/device-ui/src/screens/feed/*|src/device-ui/src/protocol/feed.ts|features/feed/*)
      echo feed ;;
    host/lib/paper_weight/spotify/*|host/test/paper_weight/spotify/*|src/device-ui/src/screens/now-playing/*|src/device-ui/src/protocol/now_playing.ts|features/now-playing/*)
      echo now-playing ;;
    host/lib/paper_weight/etymology/*|host/lib/paper_weight/etymology.ex|host/test/paper_weight/etymology/*|src/device-ui/src/screens/etymology/*|src/device-ui/src/protocol/etymology.ts|features/etymology/*)
      echo etymology ;;
    host/lib/paper_weight/photo/*|host/test/paper_weight/photo/*|src/device-ui/src/screens/photo/*|src/device-ui/src/protocol/photo.ts|features/photo/*)
      echo photo ;;
    src/device-ui/src/shell/*|src/device-ui/src/design/*|src/device-ui/src/sample/*|host/lib/paper_weight/application.ex|host/lib/paper_weight/protocol/*|src/device-ui/src/protocol/envelope.ts)
      echo platform ;;
    src/input-bridge/*)
      echo input-bridge ;;
    *)
      echo "" ;;
  esac
}

declare -A SEEN=()
for f in "${FILES[@]}"; do
  lane="$(lane_for "$f")"
  if [[ -n "$lane" ]]; then
    SEEN["$lane"]=1
  fi
done

# platform + one product lane is OK (shared shell/tokens). 2+ product lanes fail.
PRODUCT=(weather feed now-playing etymology photo)
product_hit=0
product_list=()
for p in "${PRODUCT[@]}"; do
  if [[ -n "${SEEN[$p]:-}" ]]; then
    product_hit=$((product_hit + 1))
    product_list+=("$p")
  fi
done

echo "lane-guard: product lanes touched: ${product_list[*]:-none}"
echo "lane-guard: files:"
printf '  %s\n' "${FILES[@]}"

if [[ "$product_hit" -ge 2 ]]; then
  echo "::error::lane-guard: PR touches multiple product lanes (${product_list[*]})."
  echo "Use one lane per PR, or add label 'cross-lane' / branch chore/*."
  exit 1
fi

echo "lane-guard: OK"
exit 0
