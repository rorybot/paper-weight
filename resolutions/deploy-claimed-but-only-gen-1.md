# Symptom

Device is still on **NixOS Gen 1** (only one generation listed). Screen looks
like the old flash: stuck on Home, dead buttons, stale `input-bridge`, etc.
Someone already “deployed,” or an agent is mid-diagnosis, but **no Gen 2+
exists**.

# Lead with this (mandatory — do not bury)

| Fact | Fix |
|------|-----|
| Generation is wrong / stale (only Gen 1) | **Build a new gen and deploy it** |

That is the whole primary answer. One sentence:

> Only Gen 1 → nothing newer is on the device → **build + activate a new generation** (`scripts/device-nixos.sh deploy` does both). Without a successful build+activate, you stay on Gen 1 forever.

You **cannot** get Gen 2 by: restarting kiosk, serving a different host fixture,
explaining Home placeholders, killing host ports, or re-deriving input-bridge
theory while Gen stays at 1.

# Agent failure mode (why we went in circles — #161 thrash, 2026-07-23)

Rory said the deployment/generation was wrong. Evidence was already: **only
Gen 1**. Agents did **not** put “build+deploy new gen” first. Instead they:

1. Stacked supporting detail as if it *were* the solution (preflight, right
   worktree/master, list-generations as narrative, input-bridge status, fixture
   hashes, Home placeholders).
2. Pattern-matched older resolutions (buttons dead, stray bridge, wrong UI
   checkout) and kept diagnosing symptoms **under** a stale generation.
3. Treated “deploy claimed” as possible success without requiring Gen ≥ 2.
4. Forced Rory to restate the obvious multiple times (“talk to me like I’m 5,”
   “why didn’t you consider build,” “why fuck about with preflight…”) before
   the simple fact stayed front and center.

**Rule for future agents:** When Rory (or evidence) says wrong deployment /
only Gen 1, the **first** reply is the lead table above. Supporting checks
come **after**, labeled as supporting — never instead of the fix sentence.

# Why only Gen 1 means no later system

A later device image cannot be live as a new generation without appearing in
the generation list. If list stays at 1, either:

1. Build/activate never completed (failed, aborted, wrong host/nesting).
2. Deploy-rs rolled the new gen back (e.g. stray manual `input_bridge` on
   :9137 — [deploy-rollback-from-stray-manual-input-bridge](deploy-rollback-from-stray-manual-input-bridge.md)).
3. Agent confused **host UI** (`:8080` dist / branch worktree) with a **device
   generation**. Fixture JS hash ≠ Gen 2.

# Confirm once (supporting check, not the main monologue)

```bash
ssh root@172.16.42.2 'nixos-rebuild list-generations 2>/dev/null || \
  ls -la /nix/var/nix/profiles/system*; \
  readlink -f /run/current-system'
```

| Result | Do this |
|--------|---------|
| Only Gen 1 | **Build + deploy new gen.** Stop Home/UI/app narratives. |
| Still Gen 1 after “deploy” | Deploy **failed** (build or rollback). Fix that; do not invent a later deployment. |
| Gen ≥ 2 | Generation layer OK; *then* use input-bridge / fixture resolutions as needed. |

# Fix (primary)

```bash
# On physical host when aarch64 build is required (not nested Distrobox Podman — P6-N #84).
# From the intended checkout/worktree for the card.
scripts/device-nixos.sh deploy   # builds + activates
# Success = list-generations shows Gen ≥ 2 (and intended services up).
```

**Abort:** post-deploy still only Gen 1 → treat as failed. Do not pivot to
placeholder-Home theory.

# Supporting detail only (after Gen ≥ 2, or to unblock a failed activate)

- Preflight: free `:9137`, no manual `input_bridge` — so deploy does not roll back.
- Right worktree/branch: so the *contents* of the new gen (or host UI) match the card.
- Host fixture vs device gen: UI is often host-served; still does not replace Gen 2 for on-device packages.
- After Gen ≥ 2 and bridge still dead: [buttons-do-nothing-input-bridge-failed](buttons-do-nothing-input-bridge-failed.md).

These are real; they are **not** a substitute for saying “generation is wrong → build and deploy.”

# Status

Logged 2026-07-23 after #161 on-device acceptance thrash. Open as recurring
agent process failure: **do not circle on symptoms while Gen stays at 1.**
