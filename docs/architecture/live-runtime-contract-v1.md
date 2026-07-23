# P7 live-runtime contract

Ticket: [#85](https://github.com/rorybot/paper-weight/issues/85)

One `EnvironmentFile` contract that switches the host from fixture/stub
adapters to live Weather and Spotify — with fail-clear startup
validation and per-lane enable/disable. Builds on `PAPER_WEIGHT_GATEWAY_STUBS`
(P6-H/W3-F) and the existing `.env.example`, without touching lane client
internals or the frozen host-device envelope.

## Contract table

| Lane | Enable var | Required vars (live) | Default when unset |
|---|---|---|---|
| Weather | `PAPER_WEIGHT_WEATHER_ENABLED` | `WEATHER_LAT`, `WEATHER_LON` | `:enabled` (compiled) |
| Spotify | `PAPER_WEIGHT_SPOTIFY_ENABLED` | `SPOTIFY_CLIENT_ID` 🔒, `SPOTIFY_CLIENT_SECRET` 🔒, `SPOTIFY_REFRESH_TOKEN` 🔒 | `:disabled` (compiled) |

🔒 = secret; never commit a value for these. Optional vars with their own
defaults (`WEATHER_LOCATION_LABEL`, `WEATHER_USER_AGENT`) are not part of
this contract's required set — see each lane's `Config` module below.

The Feed lane was dropped (FS1 / #161); its enable/required vars are gone.

Photo and Etymology are **out of scope** for this milestone (Etymology stays
local fixture-backed; Photo's own env var, `PAPER_WEIGHT_PHOTO_LIBRARY_DIR`,
is unaffected by this card).

Enable-var accepted literals (case-insensitive): `true` / `1` / `enabled` →
live; `false` / `0` / `disabled` → off; unset or unrecognized → the compiled
`host/config/config.exs` default in the table above.

## Precedence

`PAPER_WEIGHT_GATEWAY_STUBS=all` **always wins**: both live lanes are forced
`:disabled` and the gateway serves fixture-backed stub adapters, regardless
of what the `*_ENABLED` vars say. Set it to `none` (or leave it unset) to let
the per-lane enable vars take effect. See `PaperWeight.Application`
(`host/lib/paper_weight/application.ex`) `config_from_env/0`.

## Startup validation

For each lane that resolves `:enabled` (after the stub override above), boot
checks that lane's required vars are **present and non-empty** — nothing
more. It does not parse or format-check values (e.g. it does not confirm
`WEATHER_LAT` is a valid float); that stays where it already lives, inside
each lane's own `Config` module (`PaperWeight.Weather.Config`,
`PaperWeight.Spotify.Config`).

On a missing/empty required var, `PaperWeight.Application.start/2` raises
`ArgumentError` naming the lane and the missing var **names only** — never
values — e.g.:

```
weather enabled but missing required env vars: WEATHER_LAT, WEATHER_LON
```

This crashes application boot. Under the systemd unit (`Restart=always`),
that means the service **crash-loops** rather than stopping cleanly —
expected, not a bug. Check what's actually wrong with:

```bash
journalctl --user -u paper-weight-host.service -b --no-pager | grep -A5 ArgumentError
```

The check lives in `PaperWeight.RuntimeContract` (pure,
`host/lib/paper_weight/runtime_contract.ex`) — a required-var list
maintained by hand, separately from each lane's `Config` module. If a lane's
env vars change, update both `RuntimeContract` and this table; they don't
derive from a single source of truth.

## Two consumption paths

**Production (systemd).** `scripts/paper-weight-host.service.template`
declares:

```
EnvironmentFile=-__PAPER_WEIGHT_ROOT__/.env
```

The leading `-` makes the file optional — a fresh checkout with no `.env`
still boots cleanly in fixture mode (`PAPER_WEIGHT_GATEWAY_STUBS` unset →
`run-device-fixture.sh` defaults it to `all`). Copy `.env.example` to `.env`
in the repo root (never commit it — already gitignored), fill in the lanes
you want live, and reinstall (`scripts/host-service.sh install`) to pick up
the new unit.

**Local dev (`mix run`).** Nothing auto-sources `.env` for a bare `mix run`.
Export it into your shell first:

```bash
set -a; source .env; set +a
cd host && mix run --no-halt
```

## Why `run-device-fixture.sh` still says "fixture"

`scripts/run-device-fixture.sh` used to hardcode
`PAPER_WEIGHT_GATEWAY_STUBS=all`, so there was no live launch path at all.
It now does `PAPER_WEIGHT_GATEWAY_STUBS="${PAPER_WEIGHT_GATEWAY_STUBS:-all}"`
— still fixture-safe by default, but an inherited env var (from the
`EnvironmentFile` above, or a sourced `.env`) can flip it to `none` and let
the per-lane vars take over. The script's name and UI/gateway build-and-serve
logic are unchanged; this card only touched that one default.

## Related docs

- `docs/architecture/host-production-service.md` — the systemd unit itself
  (P6-H); this contract is the credential/activation layer it deferred.
- `docs/architecture/wave-3-smoke.md` — the stub-only smoke profile this
  contract's precedence rule preserves.
- `.env.example` — canonical variable-name template (copy to `.env`, never commit).
