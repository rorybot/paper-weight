# Device smoke (P0)

Static kiosk page: **preset buttons 1–4 switch locked mockup frames** from `spec/`.

| Key / button | Frame |
|--------------|--------|
| **1** | `spec/now-playing-4a.png` |
| **2** | `spec/weather-4b.png` |
| **3** | `spec/playlist-4c.png` |
| **4** | `spec/feed-4f.png` |

Photo / etymology mockups are not on the 1–4 presets for this smoke (six screens, four hard keys).

## Desktop check

Run the server from the **repo root** so `device-smoke/` and `spec/` keep the same
relative layout.

### Windows PowerShell

```powershell
py -3 -m http.server 8080 --bind 127.0.0.1
# Open http://127.0.0.1:8080/device-smoke/
```

### Linux / macOS

```sh
python3 -m http.server 8080 --bind 127.0.0.1
# Open http://127.0.0.1:8080/device-smoke/
```

Set the browser viewport to **800×480**, then press **1–4** or **F1–F4**. The expected
frame fills the viewport; the source PNG remains 1600×960.

## First Car Thing trial

Copy the repo to the device with `device-smoke/` next to `spec/`. The commands below
assume `/opt/paper-weight`; substitute the actual path and Chromium binary from the image.

### 1. Record the baseline

```sh
cat /etc/os-release
uname -a
command -v chromium chromium-browser
chromium --version
id
cat /proc/bus/input/devices
ls -l /dev/input
awk '/MemAvailable:/ {print $2 " kB"}' /proc/meminfo
```

### 2. Prefer a local file launch

Run Chromium as an unprivileged user. A disposable profile avoids first-run and
crash-recovery dialogs:

```sh
chromium \
  --user-data-dir=/tmp/paper-weight-smoke \
  --no-first-run \
  --disable-session-crashed-bubble \
  --force-device-scale-factor=1 \
  --window-size=800,480 \
  --kiosk \
  --app=file:///opt/paper-weight/device-smoke/index.html
```

If the image only provides `chromium-browser`, use that binary name. Avoid
`--no-sandbox`; record it explicitly if the image forces a root-only launch.

If `file://` image loading is blocked, serve the repo on loopback in one terminal:

```sh
python3 -m http.server 8080 \
  --bind 127.0.0.1 \
  --directory /opt/paper-weight
```

Then change the kiosk URL to:

```text
http://127.0.0.1:8080/device-smoke/
```

### 3. Exercise the presets

- A USB keyboard can prove the page path first: **1–4** and **F1–F4** are accepted.
- Press each physical preset. An unknown DOM key is printed in the HUD as
  `code=<value> · key=<value>`.
- If the four buttons reach Chromium under different `KeyboardEvent.code` values,
  relaunch with them in order:

  ```text
  file:///opt/paper-weight/device-smoke/index.html?codes=Code1,Code2,Code3,Code4
  ```

- If pressing a preset produces no HUD event, inspect the candidate node with
  `evtest /dev/input/eventN` **without `--grab`**. Record the four observed codes;
  do not guess or install a reusable input daemon in P0.
- `window.smokeShow(n)` is available from the page/DevTools console.
  `postMessage({preset:n})` is available to browser contexts. Neither is directly
  callable by an arbitrary evdev process without an explicit injection mechanism.

Add `?hud=0` for unobstructed acceptance photos after the mapping works.

### 4. Record the result

After checking all four presets, record available memory again, photograph at least
two frames, and inspect `chrome://gpu` in a diagnostic browser window. Fill in
`docs/architecture/device-smoke.md` with firmware, flags, input mapping, rendering
path, evidence, and the Chromium go/no-go.

## Not in scope

App router, Elixir, Preact, hold/back, a reusable evdev daemon, or the typed event bus.
Those belong to P2+.
