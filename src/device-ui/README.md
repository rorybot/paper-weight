# Device UI package (P3 shell + P4 design)

## Goal

- **P3** pure screen shell: router, overlays, back stack, konami → Settings.
- **P4** BERG tokens + `Card`; `FeedSample` acceptance fixture (also preset 4).

## Commands

| Command | Result |
|---|---|
| `npm run dev` | Shell harness @ 800×480 (keyboard map; optional P2 SSE). |
| `npm run dev` + `?bridge=0` | Keyboard only (no EventSource). |
| `npm run test` | Tokens, card, shell interaction map, bridge/dev adapters. |
| `npm run build` | Kiosk-ready static bundle in `dist/`. |
| `npm run check` | Typecheck, test, then build. |

## Dev keyboard (workflow-v1)

| Key | Shell input |
|---|---|
| `1`–`4` | preset hard-switch |
| `H` | hold → home |
| `Esc` | back (dismiss overlay / exit settings) |
| `↑` / `↓` | konami + wheel-turn |
| `←` / `→` / `B` / `A` | konami only |
| `Enter` | wheel-press |

P2 bridge (default): `http://127.0.0.1:9137/v1/events` → `bridgePayloadToShellInput`.

## Public modules

- `src/shell/`: `routeShellInput`, `ScreenShell`, `ShellApp`, bridge + dev keyboard.
- `src/design/tokens.ts`: `designTokens`, `themeClassName`, `ThemeName`.
- `src/design/Card.tsx`: `Card`, `CardProps`, `CardTone`, `joinClassNames`.
- `src/design/index.ts`: stable import surface for downstream screen cards.
