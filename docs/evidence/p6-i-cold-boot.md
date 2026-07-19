# P6-I physical integration evidence

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
- P6-N evidence separately proves accepted-generation device reboot, rollback to generation 1,
  restoration to generation 2, and preservation of generation 1.
- These results do not prove unattended startup on the eventual service host.

## Transferred final-appliance acceptance

P9 #90 retains the unattended eventual-host requirements:

- final host starts UI and gateway without login, a dev-environment process, or manual start;
- simultaneous final-host/Car Thing cold boot opens fullscreen at exactly `800×480`;
- UI/gateway health passes after that boot and final operations evidence is committed.

This transfer prevents P6-I from blocking P7/P8 on hardware reserved for final-appliance
acceptance; it does not waive the cold-boot requirement.
