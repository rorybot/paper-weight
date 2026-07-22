# Symptom
`scripts/device-nixos.sh deploy` builds and attempts to activate a new
generation, but `input-bridge.service` immediately crash-loops on the new
generation, deploy-rs's magic-rollback kicks in, and the device ends up back
on the previous generation (removed by ID) even though the build itself
succeeded. `journalctl -u input-bridge.service` on the freshly-attempted
generation shows:
```
input_bridge: could not bind 127.0.0.1:9137: Address already in use (os error 98)
```

# Root cause
A process named `input_bridge` was already bound to `127.0.0.1:9137` on the
device, started **outside systemd** against a hand-rolled config
(`/tmp/input-bridge.runtime.conf`) — left over from an earlier manual
proof-of-concept session (used to confirm the app/host were fine independent
of the systemd unit; see
[input-bridge-crash-looping](input-bridge-crash-looping.md)). That manual
process was never killed, so it kept holding the port indefinitely — long
after the session that started it ended — and every subsequent systemd-managed
activation attempt fails to bind and crash-loops, which deploy-rs interprets
as a bad deploy and rolls back.

Find it:
```
ssh root@172.16.42.2 "ss -tlnp | grep 9137; ps aux | grep input_bridge"
```
Look for a PID running `/nix/store/.../bin/input_bridge --config
/tmp/input-bridge.runtime.conf` (or any config path outside
`/nix/store/...-input-bridge.conf`) — that's the tell it's a manual leftover,
not the systemd-managed instance.

# Fix
Kill the stray PID on the device, confirm the port is free, then redeploy:
```
ssh root@172.16.42.2 "kill <pid>"
ssh root@172.16.42.2 "ss -tlnp | grep 9137 || echo 'port free'"
scripts/device-nixos.sh deploy
```

# Status
Resolved 2026-07-22. If you ever manually start `input_bridge` by hand on the
device for a quick proof-of-concept, kill it before ending the session —
it silently blocks every future `deploy` until someone notices.
