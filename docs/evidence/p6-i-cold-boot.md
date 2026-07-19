# P6-I cold-boot evidence

Ticket: [#82](https://github.com/rorybot/paper-weight/issues/82)

## Recorded checks

| Date | Environment | Check | Result |
|---|---|---|---|
| 2026-07-19 | Archbox dev environment → physical Car Thing over USB | UI `:8080` | Pass |
| 2026-07-19 | Archbox dev environment → physical Car Thing over USB | Gateway `:9138` WebSocket upgrade | Pass (`101 Switching Protocols`) |
| 2026-07-19 | Physical Car Thing, accepted generation 2 | Chromium inner/outer/screen dimensions | Pass (`800×480`, DPR 1) |
| 2026-07-19 | Physical Car Thing, owner verified | Preset 1 → Now Playing | Pass |
| 2026-07-19 | Physical Car Thing, owner verified | Preset 2 → Weather | Pass |
| 2026-07-19 | Physical Car Thing, owner verified | Preset 3 → Feed | Pass |
| 2026-07-19 | Physical Car Thing, owner verified | Preset 4 → Etymology | Pass |

## Evidence boundary

- The fixture services ran interactively inside the development environment because this Archbox
  is not the eventual production service host.
- These results prove USB runtime integration, the exact device viewport, and physical preset
  routing.
- They do not prove unattended host cold boot, host reboot survival, device reboot, or generation
  rollback/restore on the eventual service host.

## Remaining acceptance

- [ ] Final host starts UI and gateway unattended after a cold boot.
- [ ] Physical display opens fullscreen with no browser frame or DevTools after that cold boot.
- [ ] Final-host UI/gateway health checks pass.
- [ ] Device reboot is verified against the final host.
- [ ] Previous-generation rollback and accepted-generation restore are verified.
