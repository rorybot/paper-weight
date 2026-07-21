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
Not yet fixed. Next step is finding why the Nix module generating
`input-bridge.conf` omits `device` — check `device/nix/` for the input-bridge
module/options and confirm what should be supplying that key (a per-device
override, a missing default, or a regression from a related P8 change).

# Status
Open. Diagnosed 2026-07-21; blocks physical wheel/press/back validation for
any card (including E3 #135) until fixed — those cards' *app-level* logic can
still be validated via the dev-keyboard browser path, but on-device physical
input cannot.
