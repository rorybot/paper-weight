# Symptom
Fixture host confirmed up, kiosk confirmed loading the current build (verified
the target fix is present in the built JS bundle), yet physical wheel/preset
buttons on the Car Thing do nothing — screen stays on Home no matter what's
pressed. A pure-browser check (`npm run dev`, arrow keys) works fine, which
is misleading: it isn't exercising the real hardware input path.

# Root cause
Real hardware input flows `evdev → input-bridge daemon (on-device) → local
SSE at 127.0.0.1:9137/v1/events → app`. The app's only *keyboard* listener
(`devKeyboard.ts`, used by the `npm run dev` arrow-key check) is a dev-only
convenience and is explicitly disabled by `?keyboard=0` in the production
kiosk URL — so it never masks a real hardware-path failure once deployed.

Found via `systemctl status input-bridge.service` on the device:
```
× input-bridge.service - Paper Weight Car Thing input bridge
    Active: failed (Result: exit-code)
```
and in the journal:
```
input_bridge: missing required config key device
```
The Nix-generated config at `/nix/store/...-input-bridge.conf` is missing a
required `device` key, so the daemon exits immediately, systemd's restart
rate limit trips after 5 attempts, and it stays dead until something restarts
the unit (a manual `systemctl restart`, or a full reboot that re-triggers the
same crash loop).

# Fix
Not a Nix module bug — the device's currently-installed generation had been
built from a stale local branch (`agent/persistent-device-launch-82`) whose
`config.rs` had regressed to only accepting a singular `device` key. `master`
(commit `1acc234`) already supports both `device` and `devices` (plural,
comma-separated), which is what `device/nix/input-bridge.conf` actually uses
(`devices=/dev/input/event0,/dev/input/event1`). Redeploying from a clean
`origin/master` worktree fixed it — see also
[deploy-script-dies-on-failed-service-check](deploy-script-dies-on-failed-service-check.md)
for a second bug that blocked the redeploy itself (the deploy script died in
its own status check before ever reaching the build step, because the unit
was already failed).

# Status
Resolved 2026-07-21. Confirmed via `systemctl status input-bridge.service` on
device: `active (running)`, new generation deployed.
