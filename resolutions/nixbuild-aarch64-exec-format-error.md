# Symptom

`scripts/device-nixos.sh build` / `deploy` fails partway through with:

```
error: builder for '/nix/store/...-installkernel.drv' failed with exit code 1;
       last 1 log lines:
       > error: executing '/nix/store/...-bash-5.2p32/bin/bash': Exec format error
error: 1 dependencies of derivation '/nix/store/...-spotify-kernel-4.9.113.drv' failed to build
```

Happens even when run directly on the physical host (not nested Distrobox), and even
with `note: nixbuild enabled (key=... → eu.nixbuild.net)` printed — so it's not the
known P6-N #84 nested-Podman binfmt limitation, and not a missing/unresolved nixbuild key.

# Root cause

`installkernel.drv` (and similar tiny glue derivations produced while building the
aarch64 kernel) is a `preferLocalBuild`-style derivation. Configuring
`builders = ssh://eu.nixbuild.net aarch64-linux ...` makes remote building *available*,
but without `max-jobs = 0` the local machine remains an eligible builder too, and Nix's
scheduler still assigns small glue derivations to it. Locally executing an aarch64
binary (`bash`) with no working aarch64 emulation on this host produces the exact
"Exec format error" above. Because the failure happens on one of the very first
dependencies, nothing ever reaches nixbuild.net — the dashboard showing "no recent
build" does **not** distinguish "nixbuild disabled" from "nixbuild enabled but died
before dispatching anything remotely." The only reliable discriminator is the
`note: nixbuild enabled/disabled (...)` line `run_builder` prints to stderr before any
building starts.

# Fix

Force zero local build capacity so Nix has no choice but to send *everything* —
including glue derivations — to the remote aarch64 machine. Standard Nix idiom for
"never build foreign-arch locally," also nixbuild.net's own recommendation for this
scenario.

`scripts/device-nixos.sh`, `run_builder()`, nixbuild-enabled branch (`use_nixbuild=1`),
added to the exported `NIX_CONFIG`:

```
max-jobs = 0
```

Scoped to the nixbuild-enabled branch only — does not affect `PAPER_WEIGHT_NIXBUILD=0`
(local/QEMU-only) users, who still need local build capacity by definition.

Rory confirmed he has no need for local build capacity on this machine, so no
downside to leaving this on permanently for the nixbuild-enabled path.

# Diagnose (for next time)

Before assuming "no aarch64 machine on the nixbuild plan" or re-deriving the P6-N #84
nested-container theory, check the stderr line printed at the very start of the run:

| Line | Meaning |
|------|---------|
| `note: nixbuild enabled (key=... → eu.nixbuild.net)` | Remote is wired; if it still fails with `Exec format error` on a glue derivation, this is the bug — apply the `max-jobs = 0` fix above. |
| `note: nixbuild disabled (no key at ...)` | Remote was never configured for this run; fix key resolution, not scheduling. |

# Process failure (why this took about a week to fix)

This exact device build had never succeeded even once. Across roughly a week of sessions before
this fix, the failure was repeatedly re-diagnosed at the *device* layer — dead buttons, stuck on
NixOS generation 1, corrupted flash needing a reflash (see
[buttons-do-nothing-input-bridge-failed](buttons-do-nothing-input-bridge-failed.md) and
[deploy-claimed-but-only-gen-1](deploy-claimed-but-only-gen-1.md), both logged the same day this
fix landed) — without ever reading the actual `nix build` error text, which had the answer in
plain English (`Exec format error` executing a bash binary). All of those device-level symptoms
were themselves *downstream* of this one build bug: no build had ever completed, so the device
could never get past generation 1, so every bridge/reflash symptom kept recurring no matter how
many times it was individually "fixed" on-device.

The fix itself, once someone actually read the error text, took two small config lines
(`max-jobs = 0` here, plus a persistent `/nix` volume in
[nixbuild-retries-restart-from-zero](nixbuild-retries-restart-from-zero.md)). The lesson isn't
"this was hard" — it's "read the literal build/deploy error output before pattern-matching it to
a familiar-looking device symptom." Written into `CLAUDE.md`/`AGENTS.md` as a mandatory rule
alongside this file.

The nixbuild.net dashboard's "last build" timestamp is **not** a reliable signal either
way if the failure happens on an early dependency — the build can die locally before
ever reaching a derivation big enough to dispatch remotely.

# Status

Fix applied 2026-07-23 (`scripts/device-nixos.sh` — `max-jobs = 0` added to nixbuild
`NIX_CONFIG`). **Not yet re-run / confirmed** — next session should retry
`PAPER_WEIGHT_NIXBUILD=1 ./device-nixos.sh deploy` from the host-native
`~/repos/paper-weight/scripts` and confirm it builds via nixbuild.net (or surfaces a
clean `required system 'aarch64-linux' ... but no machine` if the plan genuinely lacks
aarch64 capacity, which would be a different, real gap).
