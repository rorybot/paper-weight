#!/usr/bin/env bash
# One-shot verification for W5 (#109) Open-Meteo migration.
# Safe to run from anywhere — locates its own worktree root.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/../host"

echo "== mix deps.get =="
mix deps.get

# Format only the files this card touched — leaves pre-existing formatting
# elsewhere untouched (some untouched files fail --check-formatted here,
# which looks like a mix/Elixir version mismatch with CI, not real debt).
W5_FILES=(
  lib/paper_weight/runtime_contract.ex
  lib/paper_weight/weather/config.ex
  lib/paper_weight/weather/fetch.ex
  lib/paper_weight/weather/open_meteo.ex
  lib/paper_weight/weather/snapshot.ex
  lib/paper_weight/weather/weather_code.ex
  test/paper_weight/application_test.exs
  test/paper_weight/application_weather_test.exs
  test/paper_weight/runtime_contract_test.exs
  test/paper_weight/weather/fetch_test.exs
  test/paper_weight/weather/open_meteo_test.exs
  test/paper_weight/weather/service_test.exs
)

echo "== mix format --check-formatted (W5 files only) =="
mix format --check-formatted "${W5_FILES[@]}"

echo "== mix compile --warnings-as-errors =="
mix compile --warnings-as-errors

echo "== mix test (weather + runtime_contract + application) =="
mix test test/paper_weight/weather test/paper_weight/runtime_contract_test.exs test/paper_weight/application_test.exs test/paper_weight/application_weather_test.exs

echo "== mix test (full host suite) =="
mix test
