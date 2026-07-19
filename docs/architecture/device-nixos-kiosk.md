# Declarative NixOS kiosk

## Contract

| Item | Value |
|---|---|
| Configuration | `device/nix/flake.nix` |
| Upstream | `JoeyEamigh/nixos-superbird@0d2b239683907c19583c51134c6795ded087437d` |
| Builder | `ghcr.io/joeyeamigh/nixos-superbird/builder:latest`, privileged host Podman |
| Remote builders | [nixbuild.net](https://nixbuild.net) when `~/.ssh/my-nixbuild-key` exists (`PAPER_WEIGHT_NIXBUILD=auto`) |
| Device | `root@172.16.42.2` over USB CDC-NCM |
| Kiosk URL | `http://172.16.42.1:8080/?bridge=0&gateway=ws://172.16.42.1:9138/` |
| Rollback | deploy-rs automatic/magic rollback plus retained NixOS system generations |

## Commands

Run from the repository root:

| Operation | Command | Expected evidence |
|---|---|---|
| Evaluate | `scripts/device-nixos.sh evaluate` | deploy schema passes; exact kiosk URL prints |
| Build | `scripts/device-nixos.sh build` | a `nixos-system-superbird-*` store path prints |
| Inspect | `scripts/device-nixos.sh status` | current store path, generation list, Weston state, kiosk URL |
| Deploy | `scripts/device-nixos.sh deploy` | a new current generation appears; Weston remains active |
| Reboot | `scripts/device-nixos.sh reboot` | SSH returns; new generation and production URL remain current |
| Roll back | `scripts/device-nixos.sh rollback` | prior generation becomes current |
| Select | `scripts/device-nixos.sh activate <N>` | generation `N` becomes current |

Inside Distrobox the helper selects the already-installed `distrobox-host-exec podman`; outside it
selects native `podman`. `PAPER_WEIGHT_PODMAN` is an explicit native-binary override. Do not invoke
`/run/host/usr/bin/podman`, rewire container helpers, or install nested Docker.

### nixbuild.net

`evaluate` / `build` / `deploy` share `run_builder`. When
`PAPER_WEIGHT_NIXBUILD` is `auto` (default) and `~/.ssh/my-nixbuild-key` exists, the builder
container gets that key and Nix is configured with remote builders:

- `ssh://eu.nixbuild.net` for `x86_64-linux` and `aarch64-linux`
- `builders-use-substitutes = true`

| Env | Effect |
|---|---|
| `PAPER_WEIGHT_NIXBUILD=auto` | Use nixbuild if the key file exists (default) |
| `PAPER_WEIGHT_NIXBUILD=1` | Require nixbuild; fail if the key is missing |
| `PAPER_WEIGHT_NIXBUILD=0` | Force local/QEMU-only builder image builds |
| `PAPER_WEIGHT_NIXBUILD_KEY` | Override private key path |

Host smoke test (not the Superbird image): `~/bin/nixbuild-smoke.sh`.

Evaluation permits the pinned upstream's small `config.nix` import-from-derivation helper. It does
not build the kernel or full device system; the full build occurs during `build` or `deploy`.

## Deployment sequence

1. Start the production host service and confirm ports `8080` and `9138`.
2. Run `status`; record the current generation number and store path.
3. Run `evaluate`, `build`, then `deploy`.
4. Run `status`; record the new generation and confirm the prior generation is still listed.
5. Run `reboot`; physically confirm Chromium returns fullscreen at 800×480.
6. Run `rollback`; confirm the prior store path and its prior kiosk URL.
7. Run `activate <new-generation>`, then `reboot`; confirm the production URL and fullscreen kiosk.

## Pointer / cursor (#111)

- The visible pointer is Weston's desktop-shell cursor sprite, not Chromium's: the rotary
  encoder emits a relative axis (`wheel_relative=6`), libinput classifies it as a pointer
  device, and the seat's pointer capability makes Weston draw the sprite.
- Upstream `weston.ini` sets `[core] hide-cursor=true`, but that key does not exist in stock
  Weston 14 — it is silently ignored.
- Fix: `device/nix/flake.nix` overrides `environment.etc."weston/weston.ini".source`
  (`lib.mkForce`) with `device/nix/resources/weston.ini`, identical to upstream except
  `[shell] cursor-size=0`. Fallback if the sprite survives on-device: ship a fully
  transparent `cursor-theme` instead.
- Weston only reads the ini at startup: after `deploy`, restart `weston-tty1.service`
  (or `reboot`) before judging the result. `scripts/verify-kiosk-pointer.sh` walks the
  full deploy → restart → cold-boot → rollback observation loop and logs the evidence.

## Evidence (2026-07-18 physical run)

- Baseline: generation 1, `.../nixos-system-superbird-25.05.20241207.22c3f2c`,
  `kiosk_url=http://172.16.42.1:8080/device-smoke/`.
- Deploy: `nix run "path:$deploy_source" -- .#superbird` (fixed a missing `path:` prefix in
  `deploy_system` — a bare store path is not a valid `nix run` installable) succeeded via
  deploy-rs magic rollback confirmation; new current system
  `/nix/store/x8j3mhxh3ir5k8ls0i62npfd54k77fgz-nixos-system-superbird-25.05.20241207.22c3f2c`
  became generation 2, generation 1 retained.
- `switch-to-configuration switch` does not itself restart `weston-tty1.service`; restart it
  manually after any generation change for the new `kiosk_url` to take visual effect.
- Physical reboot: `systemctl reboot`, device returned over SSH at ~2 min uptime, generation 2
  still current, `kiosk_url` still production, Weston active, screen confirmed showing the
  Paper Weight Home screen at 800×480 with all four presets — despite `switch-to-configuration`
  warning "do not know how to make this configuration bootable" (Superbird has no conventional
  `/boot`; the warning is benign for this hardware).
- Rollback: `--rollback` to generation 1 confirmed (`current_system` + `kiosk_url` reverted,
  generation 2 retained), then `--switch-generation 2` + restart Weston confirmed live return to
  production, screen re-verified showing Home.

## Safety gates

- Keep the prior generation until rollback and return-to-new are both demonstrated.
- Do not run `nix-collect-garbage` during this procedure.
- Do not mutate `/etc/kiosk_url`, add a systemd override, or use `scripts/device-kiosk.sh`.
- A failed deploy is not acceptance: capture `status`, correct the flake, and deploy a new generation.
