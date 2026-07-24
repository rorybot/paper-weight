# Symptom

`scripts/device-nixos.sh build|deploy` (with the nixbuild.net fix from
[nixbuild-aarch64-exec-format-error](nixbuild-aarch64-exec-format-error.md) already applied,
confirmed dispatching to `ssh://eu.nixbuild.net`) fails partway through with:

```
copying path '/nix/store/...' from 'ssh://eu.nixbuild.net'...
copying 0 paths...
error: unexpected end-of-file
error: builder for '/nix/store/...-source.drv' failed with exit code 1
```

Retrying reproduces the same shape of failure, but each time at a **different** store path —
never the same derivation twice. Feels like no progress is being made across retries.

# Root cause

Two separate facts compound each other:

1. **The remote link is flaky over long sessions.** The entire remote build for one
   `nix build`/`deploy` invocation runs over a single long-lived SSH connection to
   `eu.nixbuild.net`. If that connection drops once (network blip, idle timeout, whatever),
   *whatever happened to be mid-transfer at that moment* fails — which is why the failing path
   is different every time; it's a function of how long the connection survived, not which
   derivation is "bad."
2. **The builder container was fully ephemeral (`podman run --rm` with no persistent `/nix`).**
   Every retry started with a completely empty local Nix store, so every retry had to re-fetch
   *everything* — the entire kernel, gtk4, chromium, all of it — giving the flaky connection a
   fresh full-length run to break on every single time. This is what made the problem feel
   unfixable: retries never got to build on top of prior partial progress.

A third candidate, possibly the primary one: Nix logged
`warning: download buffer is full; consider increasing the 'download-buffer-size' setting`
during the same runs. `download-buffer-size` caps an in-memory buffer used for NAR downloads
(default is well under 100 MiB on most Nix versions); large paths — kernel sources, Chromium —
can exceed it, and older/default-configured Nix can hard-abort that specific fetch when it does.
That lines up with failures consistently landing on large paths (`source.drv`, kernel-sized
derivations) rather than being uniformly random across all path sizes.

A machine going to sleep mid-transfer (suspend/idle) would also produce this exact symptom and
is worth ruling out independently — wrap the build in `systemd-inhibit --what=sleep:idle:handle-lid-switch`
if that's a possibility on the machine running the build.

# Fix

Two changes, both in the nixbuild-enabled `NIX_CONFIG` block:

1. Give the builder container a persistent Nix store across invocations, so retries only need to
   transfer what's still missing instead of starting from zero.
2. Raise `download-buffer-size` well above default so large NARs can't overflow it mid-fetch.

`scripts/device-nixos.sh`, `run_builder()`, added to `podman_args` (unconditional, not just the
nixbuild-enabled branch):

```
--volume "${PAPER_WEIGHT_NIX_STORE_VOLUME:-paper-weight-nix-store}:/nix"
```

And in the `NIX_CONFIG` exported inside the nixbuild-enabled branch:

```
download-buffer-size = 1073741824
```

Podman auto-creates the named volume on first use and copies the image's existing `/nix` content
into it (standard "copy-up" behavior for a first-mount empty volume), so the container still
starts with everything the builder image ships — it just keeps growing instead of resetting.

First run after this change is slower (populating the volume). Every run after that should only
need to fetch the delta, converging toward a full success across retries instead of restarting
the flaky-link lottery from scratch each time.

# Status

Fix applied 2026-07-24 (`scripts/device-nixos.sh`). Not yet confirmed by a full successful
`deploy` — next session should retry and confirm retries visibly progress further / faster than
before. If the SSH connection itself still drops on a near-empty remaining transfer, consider
tightening `ServerAliveInterval`/`ServerAliveCountMax` in the SSH config block inside
`run_builder()`, or investigating whether `eu.nixbuild.net` enforces a hard session duration/idle
limit on this account tier.

Unrelated noise seen in the same output, not the cause of this failure: `device/nix/flake.nix`'s
`nixConfig.extra-substituters` lists `https://superbird.attic.claiborne.soy/superbird`, which is
unreachable and retried ~5x with backoff before falling through to `cache.nixos.org` /
`nix-community.cachix.org`. Costs real wall-clock time on every single build attempt; worth
removing, but not a correctness blocker.
