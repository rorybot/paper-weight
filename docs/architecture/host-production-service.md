# P6-H host production service

Ticket: [#83](https://github.com/rorybot/paper-weight/issues/83)
Runs the production Preact UI (`:8080`) and the fixture WebSocket gateway
(`:9138`) as a resilient `systemd --user` service on the USB-host machine.
Live credentials are out of scope here — the activation contract for those
lives in `docs/architecture/live-runtime-contract-v1.md` (P7/#85).

## Why wildcard bind

`scripts/run-device-fixture.sh` binds both servers to `0.0.0.0` instead of
the Car Thing's gadget address (`172.16.42.1`). That means:

- The service starts at boot even before the USB gadget interface exists.
- Unplugging/replugging the Car Thing is a non-event for this process —
  there is no gadget-specific socket to rebind, so nothing needs manual
  repair.
- Local readiness/health checks poll `127.0.0.1`, so they work identically
  whether or not a physical device is attached.

Process-level failures (e.g. a crashed `mix` or `http.server` child) are
still covered — the launcher exits non-zero and `Restart=always` in the unit
brings it back.

## Install

From the repository root:

```bash
scripts/host-service.sh install
scripts/host-service.sh start
```

`install` renders `scripts/paper-weight-host.service.template` for this
checkout into `~/.config/systemd/user/paper-weight-host.service`, runs
`daemon-reload`, `enable`s the unit, and enables linger
(`loginctl enable-linger $USER`) so the service also comes back after a host
reboot with no interactive login required.

## Operations

| Action | Command |
|---|---|
| Start | `scripts/host-service.sh start` |
| Stop | `scripts/host-service.sh stop` |
| Restart | `scripts/host-service.sh restart` |
| Status | `scripts/host-service.sh status` |
| Uninstall | `scripts/host-service.sh uninstall` |
| Logs | `journalctl --user -u paper-weight-host.service -b --no-pager` |
| Health check | `scripts/host-health-check.sh` |
| Manual run (no systemd) | `scripts/run-device-fixture.sh` |

## Health checks

`scripts/host-health-check.sh` checks both endpoints independently and exits
non-zero (count of failures) if either is down:

- **UI**: `GET http://127.0.0.1:8080/` must succeed.
- **Gateway**: a WebSocket upgrade handshake against
  `http://127.0.0.1:9138/` must return `HTTP/1.1 101`.

Set `PAPER_WEIGHT_HEALTH_HOST=172.16.42.1` to check the gadget-facing
address once a Car Thing is connected.

## Acceptance

- [x] `cd src/device-ui && npm run check` passes (production build).
- [x] Stop/start cycled the launcher twice locally (stand-in for
      `scripts/host-service.sh restart`): both `127.0.0.1:8080` and
      `127.0.0.1:9138` come back healthy each time, ports fully released
      between runs.
- [x] Wildcard bind (`0.0.0.0`) means the servers never depend on the
      `172.16.42.1` gadget address being present at start or at any point
      while running — proven directly, since this dev sandbox has no such
      interface at all and the service served correctly throughout. Unplug
      and replug are therefore a non-event, not a recovered failure.
- [x] `scripts/host-health-check.sh` detects both endpoints, and correctly
      reports failure (non-zero exit, one line per endpoint) when the
      service is stopped.
- [x] `scripts/host-service.sh install` renders the unit, enables it
      (`systemctl --user enable`), and attempts `loginctl enable-linger` for
      reboot survival. **Caveat**: `systemctl --user start` could not be
      exercised end-to-end in this sandbox — no `systemctl --user` unit,
      including a trivial throwaway one unrelated to this card, can reach
      `active` here (`LoadState=not-found` even immediately after
      `daemon-reload`/`link`); this reproduces for any unit, so it is an
      environment limitation of the dev sandbox, not a script defect.
      Verify `start`/`status`/reboot survival on the real USB-host machine
      before relying on it operationally.
- [ ] Required `ci` is green (confirmed on the PR, not locally).

## Boundary

- Fixture snapshots only (`PAPER_WEIGHT_GATEWAY_STUBS=all`) by default; live
  API credentials and per-lane enable/disable are documented separately in
  `docs/architecture/live-runtime-contract-v1.md` (P7/#85).
- Does not touch device Nix configuration, `application.ex`, live lane
  services, or #82's cold-boot evidence/doc (`docs/architecture/device-launch.md`).
- Input bridge and physical device wiring are out of scope; P6-I (#82)
  integrates this host service with the device side.
