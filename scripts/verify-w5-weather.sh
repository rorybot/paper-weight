#!/usr/bin/env bash
# One-shot verification for W5 (#109) Open-Meteo migration.
# Run from the repo root of this worktree in your Elixir dev environment.
set -euo pipefail

cd host
echo "== mix format --check-formatted =="
mix format --check-formatted
echo "== mix compile --warnings-as-errors =="
mix compile --warnings-as-errors
echo "== mix test (weather + runtime_contract + application) =="
mix test test/paper_weight/weather test/paper_weight/runtime_contract_test.exs test/paper_weight/application_test.exs
echo "== mix test (full host suite) =="
mix test
