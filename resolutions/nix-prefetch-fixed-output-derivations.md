# Symptom

Even with the `max-jobs = 0` fix
([nixbuild-aarch64-exec-format-error](nixbuild-aarch64-exec-format-error.md)) and the persistent
`/nix` volume fix
([nixbuild-retries-restart-from-zero](nixbuild-retries-restart-from-zero.md)) both applied, one
specific derivation — the spotify-kernel source tarball fetch
(`wdl4px6426v5x8cinngh6jm0ap9nihyc-source.drv`, fetching a ~143M GitHub archive) — kept failing
the same way on every retry: `unexpected end-of-file` mid-transfer over the nixbuild.net SSH
link, unchanged across multiple full-build attempts.

# Root cause

Inspecting the derivation directly (`nix derivation show`) showed it's a fixed-output derivation
(FOD) — content-addressed via `outputHash`/`outputHashAlgo`/`outputHashMode` — tagged to build on
the same aarch64 remote builder as everything else. Its size and this specific host's link to
`eu.nixbuild.net` made it the single most fragile step in the whole build graph: large enough to
be likely to hit a flaky SSH session, unlike the small glue derivations `max-jobs = 0` was fixing.

Likely also explains "why did this work before but not now": `device/nix/flake.nix`'s
`nixConfig.extra-substituters` lists `https://superbird.attic.claiborne.soy/superbird`, a
third-party binary cache that appears to be down now. If it was up during the last known-good
deploy (2026-07-18ish), it would have substituted this derivation's output directly — meaning
this particular flaky fetch/build path may never have actually been exercised until this cache
went dark.

# Fix

Fixed-output derivations don't care *how* their content was produced, only that it matches the
declared hash. `scripts/nix-prefetch-fixed-output.sh` (new script) fetches the source directly
with plain curl (real host internet, no SSH-to-remote-builder involved), reproduces nixpkgs'
generic-fetcher `postFetch` unpack step exactly, and registers the result into the **same
persistent Nix store volume** (`paper-weight-nix-store`) via `nix-store --add-fixed --recursive
sha256`. Because that registration makes the exact expected store path valid in the store
`device-nixos.sh` mounts, the next `deploy` run finds it already valid and skips
fetching/building it entirely — confirmed: the finished deploy's log never re-attempted this
derivation.

Usage:

```
scripts/nix-prefetch-fixed-output.sh <url> <expected-store-path>
```

Two details that matter and cost real debugging time to get right (see file header comment in
the script for the fully-reproduced logic):

- `name` must be derived from the *expected* store path's basename, not any name of your
  choosing — it's part of the digest computation, not cosmetic.
- Permission bits are part of the NAR hash. Must mirror the real `postFetch` exactly: recursive
  `+w` during unpack, then one non-recursive `chmod 755` on the final top-level output only.

# Status

Confirmed 2026-07-24: registered store path matched the expected path exactly
(`/nix/store/a06q8hxn4mk1015k4yz2d3fp073vv010-source`), and the subsequent full `deploy` skipped
this derivation and completed successfully — ending the week-long stuck-on-generation-1 blocker
together with the two companion fixes above. Currently on branch `chore/nixbuild-agent-rules`
(PR #170), not yet merged to `master`.

Reusable for any future flaky fixed-output derivation in this flake, not just this one URL/hash.
