# Symptom
`./scripts/device-nixos.sh deploy` (and `build`) exits almost instantly with
no error, no build output, just a truncated "Before deployment:" status block
(cuts off mid-way, e.g. right after `input_bridge_active=`). Looks like
nothing happened — no `podman`/`nix build` output ever appears, even after
waiting minutes.

# Root cause
`device_status()` in `scripts/device-nixos.sh` runs the remote SSH block
under `set -eu` and calls `systemctl is-active <unit>` / `is-enabled <unit>`
unguarded. `systemctl is-active` exits non-zero (3) for any unit that isn't
currently active — including a unit that's `failed`. If any service being
checked (e.g. `input-bridge.service` mid crash-loop) is not active, the
remote script dies the instant it hits that line, before printing the rest
of the status block, and — because this happens inside the "before" status
check — before the deploy script ever reaches the actual build/deploy step.
The result looks exactly like a hang or silent failure, but it's actually
exiting in under a second on a `set -e` trip.

# Fix
Guard each `is-active` / `is-enabled` call so a failed/inactive/disabled
unit doesn't kill the script:
```sh
systemctl is-active weston-tty1.service || true
systemctl is-enabled weston-tty1.service || true
systemctl is-active input-bridge.service || true
systemctl is-enabled input-bridge.service || true
```
Applied in `scripts/device-nixos.sh` `device_status()`.

# Status
Resolved 2026-07-21.
