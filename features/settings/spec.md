# Feature: settings

Lane owner for **D2** (hidden Settings screen, konami entry).  
Shell already implements konami → `settings` + `move-settings-field` / `edit-settings-field`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| D2 | [#19](https://github.com/rorybot/paper-weight/issues/19) | Settings screen — design + build | **Done** (PR #37) |

## Ownership

| Area | Path |
|------|------|
| Device screen | `src/device-ui/src/screens/settings/**` |
| Feature spec | `features/settings/spec.md` |

**Do not touch:** shell (P3 frozen), design tokens, other lanes, Application.

## Design snippet (mock approved direction — no canvas mock)

Hidden config is **not** on presets 1–4. BERG paper card on dark desk:

| Element | Spec |
|---------|------|
| Entry | Shell konami sequence (already P3) |
| Exit | Shell **back** → previous screen or home |
| Presets | Inactive while on settings (shell) |
| Layout | 800×480; topbar “hidden · settings · konami only”; cream card field list |
| Fields | wifi · brightness · feed handles · photo source · hold → home |
| Wheel | Nav: move field · Edit: adjust value |
| Press | Toggle edit / confirm |

## Interaction (shell → screen)

| Shell command | Screen |
|---------------|--------|
| `move-settings-field` `{ delta }` | Not editing → change selection; editing → adjust value |
| `edit-settings-field` | Toggle `editing` |
| `back` | Shell exits settings (no screen action) |

## Acceptance (D2)

- [x] Pure reduce for move/edit
- [x] Five minimal fields rendered
- [x] Unreachable via presets (shell invariant; documented)
- [x] Full wheel-only field operation (nav + edit modes)
- [ ] Wave-3: `ShellApp` maps `settings` → `SettingsScreen`

## Next Session Context Chunk

- D2: `screens/settings/**` pure model + BERG `SettingsScreen`.
- Shell owns konami entry, preset lock, back exit — do not edit shell.
- Values are local fixture defaults; persistence is a later host/settings store.
