#!/usr/bin/env bash
# If a *Screen.tsx is added/changed under screens/, require a co-located *.test.tsx
# (ScreenName.test.tsx or model.test.ts in the same folder).
set -euo pipefail

BASE="${BASE_SHA:-origin/master}"
HEAD="${HEAD_SHA:-HEAD}"

if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  RANGE="${BASE}...${HEAD}"
else
  RANGE="origin/master...HEAD"
fi

mapfile -t CHANGED < <(git diff --name-only "$RANGE" -- 'src/device-ui/src/screens/**/*Screen.tsx' || true)
if [[ ${#CHANGED[@]} -eq 0 ]]; then
  echo "screen-tests: no Screen.tsx changes"
  exit 0
fi

fail=0
for f in "${CHANGED[@]}"; do
  [[ -f "$f" ]] || continue
  dir="$(dirname "$f")"
  base="$(basename "$f" .tsx)"
  # Prefer FooScreen.test.tsx; also accept model.test.ts in same dir (pure state).
  if [[ -f "${dir}/${base}.test.tsx" ]] || [[ -f "${dir}/model.test.ts" ]]; then
    echo "OK  $f"
  else
    echo "::error::Missing test for $f — add ${base}.test.tsx or model.test.ts in ${dir}/"
    fail=1
  fi
done

exit "$fail"
