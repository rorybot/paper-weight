#!/usr/bin/env python3
"""
Talk to the Car Thing kiosk's Chromium DevTools Protocol (CDP) without any
external dependency (stdlib socket only — no `websockets`/`websocket-client`
package needed, since the dev/host boxes don't reliably have one installed).

CDP listens loopback-only on the device (127.0.0.1:9222) — see
docs/architecture/device-smoke.md. Reach it via an SSH local port-forward
from a machine that can SSH to the device:

    ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \\
        -f -N -L 19222:127.0.0.1:9222 root@172.16.42.2

Then find the page target id:

    ssh ... root@172.16.42.2 'curl -s http://127.0.0.1:9222/json'
    # -> take the "id" field, e.g. CEE9DC51A4B4210C1560350522FF6D1F

Usage (once the tunnel above is up):

    scripts/device-cdp.py screenshot <page-id> <out.png>
    scripts/device-cdp.py eval <page-id> "<js expression>"
    scripts/device-cdp.py navigate <page-id> "<url>"
    scripts/device-cdp.py key <page-id> "<key>"        # e.g. "1", "Escape"
    scripts/device-cdp.py watch-log <page-id> <seconds> [reload]

Why this exists: N5 #128 needed to confirm real (not fixture) data was
rendering on the physical device, and to debug why a long-lived kiosk tab
kept showing stale fixture data after several host restarts (see
docs/resolutions/stale-kiosk-websocket-after-host-restart.md — the fix was
a page reload, found by reading this tab's own console log via `watch-log`).
Reuse this script instead of re-deriving the raw WS handshake from scratch.
"""

import base64
import json
import os
import socket
import struct
import sys
import time

HOST, PORT = "127.0.0.1", 19222


def _ws_handshake(sock: socket.socket, path: str) -> None:
    key = base64.b64encode(os.urandom(16)).decode()
    req = (
        f"GET {path} HTTP/1.1\r\nHost: {HOST}:{PORT}\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
    )
    sock.sendall(req.encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        resp += sock.recv(4096)
    if b"101" not in resp.split(b"\r\n", 1)[0]:
        raise ConnectionError(f"CDP handshake failed: {resp!r}")


def _ws_send(sock: socket.socket, obj: dict) -> None:
    payload = json.dumps(obj).encode()
    length = len(payload)
    mask = os.urandom(4)
    if length < 126:
        header = struct.pack("!BB", 0x81, length | 0x80)
    elif length < 65536:
        header = struct.pack("!BBH", 0x81, 126 | 0x80, length)
    else:
        header = struct.pack("!BBQ", 0x81, 127 | 0x80, length)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    sock.sendall(header + mask + masked)


def _recvn(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("socket closed")
        buf += chunk
    return buf


def _ws_recv_frame(sock: socket.socket) -> tuple[int, bytes]:
    first2 = _recvn(sock, 2)
    opcode = first2[0] & 0x0F
    length = first2[1] & 0x7F
    if length == 126:
        length = struct.unpack("!H", _recvn(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", _recvn(sock, 8))[0]
    return opcode, _recvn(sock, length)


def connect(page_id: str, timeout: float = 20) -> socket.socket:
    sock = socket.create_connection((HOST, PORT), timeout=timeout)
    sock.settimeout(timeout)
    _ws_handshake(sock, f"/devtools/page/{page_id}")
    return sock


def call(sock: socket.socket, msg_id: int, method: str, params: dict | None = None):
    _ws_send(sock, {"id": msg_id, "method": method, "params": params or {}})
    while True:
        opcode, payload = _ws_recv_frame(sock)
        if opcode == 0x8:
            raise ConnectionError("CDP connection closed")
        if opcode not in (0x1, 0x2):
            continue
        try:
            obj = json.loads(payload.decode())
        except Exception:
            continue
        if obj.get("id") == msg_id:
            return obj


def cmd_screenshot(page_id: str, out_path: str) -> None:
    sock = connect(page_id)
    obj = call(sock, 1, "Page.captureScreenshot", {"format": "png"})
    data = obj.get("result", {}).get("data")
    if not data:
        print("FAILED", obj, file=sys.stderr)
        sys.exit(1)
    with open(out_path, "wb") as f:
        f.write(base64.b64decode(data))
    print(f"wrote {out_path} ({os.path.getsize(out_path)} bytes)")


def cmd_eval(page_id: str, expr: str) -> None:
    sock = connect(page_id)
    obj = call(sock, 1, "Runtime.evaluate", {"expression": expr, "returnByValue": True})
    print(json.dumps(obj, indent=2))


def cmd_navigate(page_id: str, url: str) -> None:
    sock = connect(page_id)
    obj = call(sock, 1, "Page.navigate", {"url": url})
    print(json.dumps(obj))


def cmd_key(page_id: str, key: str) -> None:
    sock = connect(page_id)
    call(sock, 1, "Input.dispatchKeyEvent", {"type": "keyDown", "key": key, "text": key})
    call(sock, 2, "Input.dispatchKeyEvent", {"type": "keyUp", "key": key})
    print(f"sent key {key}")


def cmd_watch_log(page_id: str, seconds: float, reload: bool) -> None:
    """Enable Log/Runtime/Page domains and print events for `seconds`.
    Pass `reload` to trigger Page.reload right after enabling, so you see the
    events from a fresh navigation rather than whatever's already buffered."""
    sock = connect(page_id, timeout=1)
    _ws_send(sock, {"id": 1, "method": "Runtime.enable"})
    _ws_send(sock, {"id": 2, "method": "Log.enable"})
    _ws_send(sock, {"id": 3, "method": "Page.enable"})
    if reload:
        _ws_send(sock, {"id": 4, "method": "Page.reload"})

    end = time.time() + seconds
    while time.time() < end:
        try:
            opcode, payload = _ws_recv_frame(sock)
        except socket.timeout:
            continue
        except ConnectionError:
            break
        if opcode not in (0x1, 0x2):
            continue
        try:
            obj = json.loads(payload.decode())
        except Exception:
            continue
        if obj.get("method") in (
            "Runtime.exceptionThrown",
            "Log.entryAdded",
            "Runtime.consoleAPICalled",
        ):
            print(json.dumps(obj))


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    action, page_id = sys.argv[1], sys.argv[2]
    rest = sys.argv[3:]

    if action == "screenshot":
        cmd_screenshot(page_id, rest[0] if rest else "device-screen.png")
    elif action == "eval":
        cmd_eval(page_id, rest[0])
    elif action == "navigate":
        cmd_navigate(page_id, rest[0])
    elif action == "key":
        cmd_key(page_id, rest[0])
    elif action == "watch-log":
        seconds = float(rest[0]) if rest else 8.0
        reload = len(rest) > 1 and rest[1] == "reload"
        cmd_watch_log(page_id, seconds, reload)
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
