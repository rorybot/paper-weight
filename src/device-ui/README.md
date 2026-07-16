# P4 device UI package

## Goal

- Shared BERG visual primitives for the fixed 800×480 Chromium kiosk.
- `designTokens` and CSS custom properties expose the same immutable theme contract.
- `Card` owns the hard outline + hard offset shadow recipe.
- `FeedSample` is the acceptance fixture; `theme="gruvbox"` proves fallback availability.

## Commands

| Command | Result |
|---|---|
| `npm run dev` | Render the 800×480 sample at the local Vite URL. |
| `npm run test` | Verify tokens, card recipe, and both themes. |
| `npm run build` | Produce the kiosk-ready static bundle in `dist/`. |
| `npm run check` | Typecheck, test, then build. |

## Public modules

- `src/design/tokens.ts`: `designTokens`, `themeClassName`, `ThemeName`.
- `src/design/Card.tsx`: `Card`, `CardProps`, `CardTone`, `joinClassNames`.
- `src/design/index.ts`: stable import surface for downstream screen cards.
