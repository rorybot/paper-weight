# Resolution: kiosk tab shows fixture placeholder after host restarts

First hit: N5 #128 (2026-07-21), verifying live album art on the physical device.

## Symptom

The Car Thing's Now Playing screen showed the built-in device-ui fixture data
("Galactic" / "Tenure" / "Sink" · 2020, a fixed checkerboard-pattern art tile)
instead of real Spotify data — even though:

- `scripts/device-nixos.sh status` showed the correct `kiosk_url` (matching
  `EXPECTED_KIOSK_URL`), Weston active, input-bridge active.
- A direct WebSocket check from the device to the host gateway (see below)
  returned real, correct live data on the `now_playing` channel.
- The host process itself (`scripts/run-device-fixture.sh`, run in the dev
  environment — see `docs/architecture/device-launch.md`) was healthy, with
  `PAPER_WEIGHT_GATEWAY_STUBS=none` / `PAPER_WEIGHT_SPOTIFY_ENABLED=true`.

So: host correct, gateway correct, kiosk URL correct — yet the on-screen data
was still the client-side placeholder. This means the *browser tab itself*
was the stale part, not the host or the URL.

## Root cause

The kiosk's Chromium tab had been open across several host process
restarts (this session restarted the host multiple times while fixing
unrelated systemd/mix issues). Its `WebSocket` (device-ui's
`createGatewayClient`, `src/device-ui/src/shell/gateway.ts`) had a
reconnect/backoff loop that was not recovering — the tab's own console log
(read via CDP, see below) showed a long run of
`WebSocket connection to 'ws://172.16.42.1:9138/' failed: ... ERR_CONNECTION_REFUSED`
entries, i.e. it kept trying against hosts that were down at the time and
never landed on a good connection once the host was actually back up.

**A `Page.reload()` fixed it immediately** — fresh navigation, fresh
WebSocket, fresh data. No power cycle of the physical device was needed or
would have told us anything different (a power cycle also reloads the page,
but takes minutes and reboots hardware to get the same "reload the tab"
effect).

## How this was diagnosed (reusable — don't redo this from raw sockets)

`scripts/device-cdp.py` wraps Chromium's DevTools Protocol (CDP), which the
kiosk always exposes loopback-only on the device at `127.0.0.1:9222`
(`docs/architecture/device-smoke.md`). No Python package installs are
needed — it's stdlib-only (raw CDP is just a WebSocket; no `websockets`
package was available in the dev/host environment, hence a small hand-rolled
client instead of pulling in a dependency for a debug script).

```bash
# 1. Tunnel to the device's CDP port (run from wherever you can SSH to the device):
ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -f -N -L 19222:127.0.0.1:9222 root@172.16.42.2

# 2. Find the page target id:
ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@172.16.42.2 'curl -s http://127.0.0.1:9222/json'
# -> take "id", e.g. CEE9DC51A4B4210C1560350522FF6D1F

# 3. See what's actually rendered right now (fast sanity check, no screenshot needed):
scripts/device-cdp.py eval <page-id> "document.body.innerText.slice(0,200)"

# 4. Take an actual screenshot (view the PNG with an image-capable Read tool):
scripts/device-cdp.py screenshot <page-id> /tmp/device-screen.png

# 5. Read the tab's own console/network log — this is what actually found the
#    root cause here. Pass "reload" to force a fresh navigation and capture
#    what happens on THIS reconnect attempt, not stale buffered history:
scripts/device-cdp.py watch-log <page-id> 8 reload

# 6. If you need to drive the UI (e.g. switch to the Now Playing preset) and
#    the kiosk URL has `keyboard=0` (real kiosk deploys always do — synthetic
#    key events are ignored by design, see src/main.tsx), temporarily
#    navigate to a keyboard-enabled URL, press keys, then navigate back:
scripts/device-cdp.py navigate <page-id> "http://172.16.42.1:8080/?gateway=ws://172.16.42.1:9138/"
scripts/device-cdp.py key <page-id> "1"   # switch to preset 1 (Now Playing)
scripts/device-cdp.py screenshot <page-id> /tmp/device-screen.png
scripts/device-cdp.py navigate <page-id> "http://172.16.42.1:8080/?keyboard=0&gateway=ws://172.16.42.1:9138/"
```

Also useful for confirming the gateway itself is serving correct data,
independent of any browser: a raw WS handshake curl from the device (proves
device→host network path + host payload correctness in one shot):

```bash
ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@172.16.42.2 'curl -s --max-time 3 \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      http://172.16.42.1:9138/'
```

## Fix, going forward

If the device shows stale/fixture-looking data but host + gateway + kiosk URL
all check out: **reload the kiosk tab first** (`scripts/device-cdp.py
navigate <page-id> <same-url>` or `Page.reload`) before assuming a deeper bug
or reaching for a power cycle. Only escalate to a power cycle if a reload
doesn't fix it.
