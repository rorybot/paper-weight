# Wave-3 smoke — fixture host → desktop UI

Ticket: [#50](https://github.com/rorybot/paper-weight/issues/50) (W3-F)  
Status: **GO** when the checklist below passes on a clean checkout.

Proves the wave-3 stack without Spotify/weather/feed secrets: host gateway pushes
fixture envelopes for every managed channel; device UI renders them over WebSocket;
keyboard volume emits `set_volume` and the host logs it; killing the host shows
reconnect backoff.

## Ports

| Port | Process | Role |
|------|---------|------|
| **9138** | Host gateway (`Bandit` + `PaperWeight.Gateway.*`) | WebSocket envelopes + intents |
| **9137** | Input bridge (optional for this smoke) | SSE `http://127.0.0.1:9137/v1/events` |
| Vite default (5173) | Device UI `npm run dev:live` | Preact shell @ 800×480 |

Desktop smoke uses **keyboard** (`?bridge=0`), so **9137 is not required**.

## Environment

From a clean checkout:

```bash
# Tooling already used by CI
# - Elixir ~> 1.15 + mix (host/)
# - Node 20+ + npm (src/device-ui/)
# No Spotify / NWS / feed tokens required for stubs mode.
```

## Terminal A — fixture host (`gateway: [stubs: :all]`)

```bash
cd host
PAPER_WEIGHT_GATEWAY_STUBS=all MIX_ENV=dev mix run --no-halt
```

Expect: Bandit listens on **9138**; four stub adapters start; no external HTTP.

Optional websocat check (if installed):

```bash
websocat ws://127.0.0.1:9138/
```

Expect one JSON envelope per channel shortly after connect:
`weather`, `now_playing`, `feed`, `photo`, `playlist` (order may vary).

## Terminal B — desktop UI (live gateway)

```bash
cd src/device-ui
npm install   # first time only
npm run dev:live
```

Opens Vite with:

`?bridge=0&gateway=ws://127.0.0.1:9138/`

Browse the printed local URL (typically `http://127.0.0.1:5173/?bridge=0&gateway=ws://127.0.0.1:9138/`).
Viewport **800×480**.

## Expected screens

| Input | Screen | Source channel |
|-------|--------|----------------|
| `1` | Now Playing | `now_playing` (fixture track Galactic / Tenure) |
| `2` | Weather | `weather` (exampleville) |
| `3` | Feed | `feed` (≥3 posts) |
| `4` | Etymology | still fixture-local (not a wave-3 gateway channel) |
| Home → navigate (shell) | Playlist | `playlist` (8 titles; covers null → hatch) |
| Home → navigate | Photo | `photo` |

Presets follow `PRESET_SCREENS` in `shell/model.ts` (1 NP · 2 weather · 3 feed · 4 etymology).
Playlist and Photo are reachable from Home / shell navigate, not presets 1–4.

## Volume intent round-trip

1. Press `1` (Now Playing).
2. Press `↑` / `↓` (wheel → `adjust-volume` → `set_volume` intent).
3. Host log lines:

   `gateway stub: set_volume delta=… level=… gen=…`

## Host loss → reconnect

1. Stop Terminal A (Ctrl-C).
2. UI keeps last snapshots; client backs off (500 ms × 2, cap 15 s — W3-D).
3. Restart Terminal A with the same stubs command.
4. UI reconnects; host may log `refresh_channel …` when the device re-sends open refresh intents; screens keep painting from live envelopes.

## Acceptance checklist

- [ ] Clean-checkout commands above work without secret env vars.
- [ ] All five gateway channels arrive (`websocat` or UI screens for NP/weather/feed/photo/playlist).
- [ ] Keyboard volume on Now Playing produces host `set_volume` logs.
- [ ] Host restart shows reconnect without a hard UI crash.

## Related

- Protocol: `docs/architecture/host-device-protocol-v1.md`
- Device P0 smoke (static mockups): `docs/architecture/device-smoke.md`
- Host stubs: `host/lib/paper_weight/gateway/{fixtures,stub_service,stubs}.ex`
