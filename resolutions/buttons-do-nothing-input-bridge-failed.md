# Symptom

Fixture host is up, kiosk loads Paper Weight Home (placeholder glance tiles look
fine), but **physical presets / wheel / back do nothing**. Restarting
`device-kiosk.sh` or cycling the device does not help. Agents keep treating this
as a UI/host issue; it is almost always the **on-device input path**.

# Why (fixed path — stop re-deriving this)

```
evdev (event0 keys, event1 wheel)
  → input-bridge.service on the Car Thing
  → SSE http://127.0.0.1:9137/v1/events   (device loopback only)
  → Chromium app (kiosk URL has keyboard=0 so dev keyboard is OFF)
```

If `input-bridge` is not `active (running)` and nothing listens on **:9137**,
buttons are dead. The Home placeholder is unrelated.

# Diagnose (30 seconds — do this FIRST)

```bash
# Host IP (if SSH fails, re-bind first)
sudo ip addr replace 172.16.42.1/24 dev "$(ip -br link | awk '/enp.*u/{print $1; exit}')"

ssh root@172.16.42.2 'systemctl is-active input-bridge.service; ss -ltnp | grep 9137; journalctl -u input-bridge.service -n 15 --no-pager'
```

| Result | Meaning |
|--------|---------|
| `active` + listen on 9137 | Input path OK — look at kiosk URL / app |
| `failed` / nothing on 9137 | **This is the bug** |

# Known root causes on this project

1. **Stale input_bridge binary vs modern conf** (recurring after last-good reflash / gen 1)  
   - Conf in nix store has `devices=/dev/input/event0,/dev/input/event1`  
   - Old binary only accepts singular `device=` → exits with  
     `input_bridge: missing required config key device`  
   - systemd restarts 5× then stays **failed**  
   - Documented in [input-bridge-crash-looping](input-bridge-crash-looping.md)

2. **Stray manual `input_bridge` holding :9137**  
   - Deploy rolls back; unit crash-loops "Address already in use"  
   - [deploy-rollback-from-stray-manual-input-bridge](deploy-rollback-from-stray-manual-input-bridge.md)

# Fix (proper)

From a **clean worktree on origin/master** (not a zombie `agent/*` branch):

```bash
# ensure gadget IP
sudo ip addr replace 172.16.42.1/24 dev <enp…u…>
scripts/device-nixos.sh status   # must show SSH; note input_bridge_active=
scripts/device-nixos.sh deploy  # builds + activates gen with modern binary
scripts/device-nixos.sh status   # want input_bridge_active=active
scripts/device-kiosk.sh restart
```

Then press preset 1–4 on the physical device.

# Fix (emergency session only — presets, not wheel)

When you need buttons **now** and cannot wait for a full deploy. Old binary +
singular conf on **event0 only** (GPIO presets/back/hold; **wheel needs event1**
and a modern binary):

```bash
ssh root@172.16.42.2 '
  systemctl stop input-bridge.service
  pkill -x input_bridge || true
  cat > /tmp/input-bridge.runtime.conf <<EOF
device=/dev/input/event0
listen=127.0.0.1:9137
hold_ms=650
debounce_ms=30
home_hold=2,3,4,5
wheel_relative=6
wheel_press=28
preset_1=2
preset_2=3
preset_3=4
preset_4=5
back=1
EOF
  BIN=$(systemctl cat input-bridge.service | sed -n "s/.*ExecStart=\\([^ ]*\\).*/\\1/p")
  nohup "$BIN" --config /tmp/input-bridge.runtime.conf >/tmp/input-bridge.runtime.log 2>&1 &
  ss -ltnp | grep 9137
'
scripts/device-kiosk.sh restart
```

**Kill this before the next `device-nixos.sh deploy`** or you will hit the stray-PID
rollback bug:

```bash
ssh root@172.16.42.2 'pkill -x input_bridge; systemctl reset-failed input-bridge.service'
```

# Agent rule

When Rory says **buttons do nothing** / stuck on Home with no response:

1. Do **not** explain Home fixture placeholders.
2. Do **not** restart only the fixture host / kiosk first.
3. Run the diagnose block above. Fix `input-bridge` (or say deploy is required).
4. Confirm `input_bridge_active=active` (or emergency :9137 listen) before claiming input is fixed.

# Status

Recurring operational issue. Emergency singular-conf workaround verified 2026-07-23
when device was on **generation 1 only** after reflash with mismatched binary/conf.
Permanent fix remains: deploy a generation whose `input_bridge` binary understands
`devices=`.
