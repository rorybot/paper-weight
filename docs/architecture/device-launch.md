# P6 persistent device launch

Ticket: [#82](https://github.com/rorybot/paper-weight/issues/82)
Mode: production Preact bundle + fixture WebSocket gateway over USB NCM.

## Runtime contract

| Item | Value |
|---|---|
| USB host | `172.16.42.1` |
| Car Thing | `root@172.16.42.2` |
| Production UI | `http://172.16.42.1:8080/` |
| Fixture gateway | `ws://172.16.42.1:9138/` |
| Kiosk URL | `http://172.16.42.1:8080/?bridge=0&gateway=ws://172.16.42.1:9138/` |
| Host unit | `paper-weight-host.service` (`systemd --user`) |
| Device configuration | NixOS system generation selected by `/nix/var/nix/profiles/system` |
| Device input | Native presets 1–4; input-bridge deployment is outside P6 |

## One-time installation

Run host commands from a native host terminal at the repository root, not from inside
Distrobox:

```bash
scripts/host-service.sh install
scripts/host-service.sh start
scripts/host-health-check.sh
```

`install` enables the user unit and attempts to enable linger. If it reports that linger could
not be enabled, run the printed `loginctl enable-linger <user>` command on the host, then verify:

```bash
loginctl show-user "$USER" -p Linger
scripts/host-service.sh status
```

The accepted P6-N generation must already be deployed. Confirm its active kiosk URL without
creating an override:

```bash
scripts/device-nixos.sh status
```

Expected state:

- `weston_active=active`
- `weston_enabled=enabled`
- `kiosk_url=http://172.16.42.1:8080/?bridge=0&gateway=ws://172.16.42.1:9138/`
- the accepted generation is current and at least one earlier generation remains available

Do not replace the Nix-managed kiosk URL with an `/etc` symlink or a systemd override.

## Temporary development-host verification

The current Archbox development machine is not necessarily the machine that will ultimately host
the production services. On this machine, `mix` may intentionally exist only inside the dev
environment. Its native `systemd --user` manager will not see that toolchain, so installing the
host unit there can fail with `error: required command not found: mix`.

For physical Car Thing verification on such a temporary development host, run both services from
inside the dev environment instead:

```bash
scripts/run-device-fixture.sh
```

Keep that terminal running and use another dev-environment terminal for
`scripts/host-health-check.sh`. The command serves both the production UI on `:8080` and fixture
gateway on `:9138`; it is sufficient for USB/device and physical-control checks, but it is not
evidence of unattended host cold-boot persistence.

Do not repair or bridge host/Distrobox runtime wiring merely to make a temporary development
machine emulate the eventual production host. Before classifying missing native tooling as a
P6-H defect, confirm whether the machine is actually intended to be the final service host.

## Operations

| Action | Command | Verification |
|---|---|---|
| Start host runtime | `scripts/host-service.sh start` | `scripts/host-health-check.sh` passes |
| Stop host runtime | `scripts/host-service.sh stop` | `scripts/host-service.sh status` reports inactive |
| Restart host runtime | `scripts/host-service.sh restart` | health check passes again |
| Host status | `scripts/host-service.sh status` | unit is enabled and active |
| Device status | `scripts/device-nixos.sh status` | generation, Weston, and kiosk URL match |
| Reboot Car Thing | `scripts/device-nixos.sh reboot` | SSH returns and device status passes |
| Reboot host | `sudo systemctl reboot` | after reconnect, host status and health check pass without login |
| Roll back device | `scripts/device-nixos.sh rollback` | previous generation becomes current |
| Restore accepted device generation | `scripts/device-nixos.sh activate <generation>` | accepted generation and kiosk URL return |

Before rollback, copy the current accepted generation number from `device-nixos.sh status`.
After exercising `rollback`, restore that exact generation with `activate`; do not deploy a new
generation merely to return to the accepted state.

## P6-I physical integration acceptance

P6-I accepts the host/device integration seam independently of the hardware that will eventually
run the unattended service. Its evidence must cover the accepted device generation and rollback,
the production kiosk URL, UI and gateway over USB, exact `800×480` rendering, and presets 1–4.

On a temporary development host where `mix` intentionally exists only in the dev environment,
run `scripts/run-device-fixture.sh` there. Do not install or bridge a second host runtime merely
to emulate the eventual appliance.

## P9 final-appliance cold-boot acceptance

The unattended eventual-host test is a P9 #90 gate. It is explicitly retained here for the final
appliance operator; it does not block P6-I, P7, or P8.

1. Confirm the host unit is enabled, active, and permitted to run without an interactive login.
2. Confirm the accepted device generation and preserve the immediately previous generation.
3. Shut down the host and fully remove power from the Car Thing.
4. Power the host and Car Thing, without opening a browser or DevTools.
5. From a host terminal, run:

   ```bash
   scripts/host-service.sh status
   scripts/host-health-check.sh
   scripts/device-nixos.sh status
   ```

6. On the physical 800×480 display, confirm Chromium opens the app fullscreen with no browser
   frame or DevTools.
7. Press physical presets 1–4 and record that they select, in order: Now Playing, Weather, Feed,
   and Etymology.
8. Exercise and record the stop/start, device reboot, generation rollback, and accepted-generation
   restore operations from the table above.

## Evidence records

P6-I integration results belong in `docs/evidence/p6-i-cold-boot.md`. P9 must add its own final
appliance record rather than rewriting the P6-I environment boundary.

For the P9 record, summarize command results rather than pasting full logs, and include:

- test date, operator, host, and Car Thing generation numbers;
- the exact kiosk URL and `800×480` viewport result;
- host status plus UI `:8080` and gateway `:9138` health results after cold boot;
- fullscreen/no-DevTools observation and physical preset 1–4 results;
- device reboot, rollback, and accepted-generation restore results.

## Boundary

- Fixture snapshots only; no live API credentials.
- Etymology remains local fixture-backed.
- Device input-bridge deployment, wheel, press, and back acceptance belong to P8.
- Unattended eventual-host startup and simultaneous host/device cold boot belong to P9.
- Host-service defects require a P6-H follow-up; Nix/deployment defects require a P6-N follow-up.
