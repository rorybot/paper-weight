# P0 device smoke — run record

Status: **GO — physical Car Thing run complete, all four presets verified**.

Runbook: [`device-smoke/README.md`](../../device-smoke/README.md)  
Ticket: [#21](https://github.com/rorybot/paper-weight/issues/21)

## Prepared artifact

| Item | Result |
|------|--------|
| Page | `device-smoke/index.html`; static HTML/CSS/JS, no build or runtime dependencies |
| Target | Fixed 800×480 viewport |
| Preset 1 | `spec/now-playing-4a.png` |
| Preset 2 | `spec/weather-4b.png` |
| Preset 3 | `spec/playlist-4c.png` |
| Preset 4 | `spec/feed-4f.png` |
| Input paths | `1`–`4`, `F1`–`F4`, configurable DOM codes, page API, browser `postMessage` |
| Diagnostics | Unknown DOM keys shown in HUD; `?hud=0` hides HUD for evidence photos |

## Desktop preflight — 2026-07-15

| Check | Result |
|-------|--------|
| Server | Python HTTP server bound to `127.0.0.1` |
| Browser | Chromium 150 on Windows |
| Geometry | 800×480 viewport; no body overflow |
| Images | All four loaded; each source 1600×960 and rendered at 800×480 |
| Keyboard | Keys 1, 2, 3, 4 selected the exact expected frame |
| Load failures | None |

This is only a host-side preflight. It is not evidence that Chromium, GPU rendering,
memory use, or physical preset input works on the Car Thing.

## Device environment

Fill this table during the first hardware run; do not infer values from a desktop test.

| Field | Observed value |
|-------|----------------|
| Date / operator | 2026-07-16, local |
| Device / reflash image | [nixos-superbird](https://github.com/JoeyEamigh/nixos-superbird); flash completed via manual pyamlboot fallback (Terbium browser flash crashed on WASM libarchive error); `kiosk_url=http://172.16.42.1:8080/device-smoke/` served from host over USB CDC-NCM gadget network (via WSL, since Windows lacks a driver for the Linux gadget's NCM interface — no MS OS descriptor) |
| OS / kernel | NixOS 25.05 "Warbler" (`nixos-25.05.20241207.22c3f2c`); `Linux superbird 4.9.113 #1-NixOS SMP PREEMPT aarch64` |
| Browser binary / version | `chromium-unwrapped-131.0.6778.108` (Nix store path `/nix/store/q5cf83f5b1xhls3zrg82lvc952x3j0rd-chromium-unwrapped-131.0.6778.108`) |
| Launch command and flags | `chromium --no-gpu --disable-gpu --disable-gpu-compositing --ozone-platform-hint=auto --ozone-platform=wayland --enable-wayland-ime --no-sandbox --autoplay-policy=no-user-gesture-required --use-fake-ui-for-media-stream --use-fake-device-for-media-stream --disable-sync --remote-debugging-address=172.16.42.2 --remote-debugging-port=9222 --force-device-scale-factor=1.0 --pull-to-refresh=0 --disable-smooth-scrolling --disable-login-animations --disable-modal-animations --noerrdialogs --no-first-run --disable-infobars --fast --fast-start --disable-pinch --disable-translate --overscroll-history-navigation=0 --hide-scrollbars --disable-overlay-scrollbar --disable-features=OverlayScrollbar --disable-features=TranslateUI --disable-features=TouchpadOverscrollHistoryNavigation,OverscrollHistoryNavigation --password-store=basic --touch-events=enabled --ignore-certificate-errors --kiosk --app=http://172.16.42.1:8080/device-smoke/` |
| User / sandbox mode | Runs as `superbird` user (not root); `--no-sandbox` (Chromium sandbox disabled) |
| MemAvailable before | Pending (need a reading before kiosk launch — currently only captured post-launch) |
| MemAvailable after | `free -h` while kiosk running: total 487Mi, used 284Mi, free 15Mi, buff/cache 251Mi, **available 203Mi** |
| `/dev/input` nodes | `event0` = `gpio-keys` (likely the 4 physical preset buttons + power); `event1` = `rotary@0` (the wheel, `REL` axis); `event2` = `aml_vkeypad` (keypad, purpose TBD — may be unused/legacy); `event3` = `tlsc6x_dbg` (capacitive touchscreen, `ABS` + `KEY`) |
| Render path (`chrome://gpu`) | Software rendering — launched with `--disable-gpu --disable-gpu-compositing`; GPU process present but uses `--use-gl=angle --use-angle=swiftshader-webgl` (SwiftShader software WebGL), not real GPU acceleration |
| Frame geometry / DPR | `--force-device-scale-factor=1.0`; kiosk page confirmed painting visually correct 800×480 layout (matches desktop preflight) — exact viewport not yet measured via remote debugging |

## Physical preset mapping

Inspect with `evtest` without `--grab`. First determine whether each event already
arrives in Chromium as a DOM `keydown`; only add a disposable P0 injector if it does not.

| Preset | Event node | evdev type/code/value | DOM key/code | Injection path | Correct frame? |
|--------|------------|-----------------------|--------------|----------------|----------------|
| 1 | `/dev/input/event0` (gpio-keys) | `EV_KEY` code=2 (`KEY_1`) DOWN/UP | Native — no injector needed | Kernel gpio-keys → Weston → Chromium keydown | **Yes** — Now Playing (4a) |
| 2 | `/dev/input/event0` (gpio-keys) | `EV_KEY` code=3 (`KEY_2`) DOWN/UP | Native — no injector needed | Kernel gpio-keys → Weston → Chromium keydown | **Yes** — Weather (4b) |
| 3 | `/dev/input/event0` (gpio-keys) | `EV_KEY` code=4 (`KEY_3`) DOWN/UP | Native — no injector needed | Kernel gpio-keys → Weston → Chromium keydown | **Yes** — Playlist (4c) |
| 4 | `/dev/input/event0` (gpio-keys) | `EV_KEY` code=5 (`KEY_4`) DOWN/UP | Native — no injector needed | Kernel gpio-keys → Weston → Chromium keydown | **Yes** — Feed (4f) |

All four codes are standard Linux `input-event-codes.h` values (`KEY_1`=2 … `KEY_4`=5); the
gpio-keys driver already emits semantically correct key codes, so the page's built-in `1`–`4`
key handler works with no P0 injector. Each mapping was confirmed one button at a time (isolated
capture window per button, screenshot taken immediately after) to rule out cross-talk — no
disposable injector was required per the fallback table below.

Other input nodes seen on `/proc/bus/input/devices`: `event1` = `rotary@0` (wheel, `REL` axis,
not yet exercised), `event2` = `aml_vkeypad` (purpose not yet determined), `event3` =
`tlsc6x_dbg` (capacitive touchscreen).

## Evidence

- `device-smoke/evidence/device-run-2026-07-16.png` — first successful kiosk paint (Weather frame, from CDP screenshot)
- `device-smoke/evidence/preset1-now-playing.png` — button 1 → Now Playing (4a)
- `device-smoke/evidence/preset2-weather.png` — button 2 → Weather (4b)
- `device-smoke/evidence/preset3-playlist.png` — button 3 → Playlist (4c)
- `device-smoke/evidence/preset4-feed.png` — button 4 → Feed (4f)
- All captured via Chrome DevTools Protocol (`Page.captureScreenshot`) over the device's
  loopback-only remote-debugging port (9222), reached through an SSH local port-forward from WSL
  (Chromium ignored `--remote-debugging-address` and bound `127.0.0.1` only)
- Viewport confirmed via `Page.getLayoutMetrics`: 800×480 exactly, scale 1, no overflow

## Go / no-go

Current verdict: **GO** — all four physical presets select the correct frame, page is exactly
800×480, renderer identified (SwiftShader software WebGL, no GPU), MemAvailable holds around
200Mi under the running kiosk. Remaining nice-to-have (non-blocking): a MemAvailable reading
from before the kiosk process starts (only a post-launch and post-restart-transient reading were
captured — see table above).

Go when all four physical presets select the correct frame, the page is truly 800×480,
memory remains viable, and the renderer is identified. If kiosk startup, image loading,
or input mapping fails, record the exact failure before changing P1:

| Failure | P0 fallback |
|---------|-------------|
| `file://` cannot load sibling images | Serve the repo with Python bound to `127.0.0.1` |
| Chromium first-run/crash UI blocks kiosk | Use the disposable profile and no-first-run flags |
| Presets reach Chromium under other DOM codes | Pass `?codes=Code1,Code2,Code3,Code4` |
| Presets remain evdev-only | Record codes; use a smoke-only injector or defer the reusable bridge to P2 |
| Chromium memory/rendering is unacceptable | Mark no-go and amend P1 with the measured failure |
