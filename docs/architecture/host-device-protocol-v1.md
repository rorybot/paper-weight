# Host ↔ device protocol v1.1 (frozen envelope)

**Status:** frozen for parallel lanes  
**Transport:** WebSocket JSON (host gateway; not implemented yet — envelope only)  
**Rule:** domain agents **must not** change envelope fields; only their `channel` payload.

---

## Envelope (every message)

```ts
type EnvelopeV1 = {
  v: 1;
  /** wall-clock ms when host produced the payload */
  ts: number;
  channel: ChannelV1;
  /** monotonic generation for atomic snapshot swap on device */
  gen: number;
  payload: unknown; // domain-owned; see features/*/spec.md
};

type ChannelV1 =
  | "now_playing"
  | "weather"
  | "photo"
  | "etymology"
  | "playlist"
  | "system";
```

### Host → device (snapshot push)

| Field | Meaning |
|-------|---------|
| `channel` | Which screen store to update |
| `gen` | Bump on every successful refresh; device replaces whole store for that channel |
| `payload` | Domain snapshot (nullable = clear / unknown) |
| `stale` optional on payload | Domain may set `stale: true` when serving cache after fetch fail |

Wire shape:

```json
{ "v": 1, "ts": 1721150000000, "channel": "weather", "gen": 42, "payload": { } }
```

### Device → host (intents)

```ts
type IntentV1 = {
  v: 1;
  ts: number;
  type: "intent";
  name: IntentNameV1;
  args?: Record<string, unknown>;
};

type IntentNameV1 =
  | "set_volume"          // N1: { delta: number }
  | "play_playlist"       // L1/N1 later: { id: string }
  | "refresh_channel";    // optional: { channel: ChannelV1 }
```

Only **now-playing** lane handles `set_volume` in wave 1. Other lanes ignore unknown intents.

---

## Ownership of payload shapes

| Channel | Owner card | Spec |
|---------|------------|------|
| `now_playing` | N1 | `features/now-playing/spec.md` |
| `weather` | W1 | `features/weather/spec.md` |
| `playlist` | L1 | `features/playlist/spec.md`; payload type `PlaylistSnapshotV1` in `src/device-ui/src/protocol/playlist.ts` |

Payload schema changes require a **spec.md edit first**, same lane only — no cross-lane “drive-by” types.

### `playlist` payload (v1.1)

Snapshot shape is `PlaylistSnapshotV1` (TS-owned, see `src/device-ui/src/protocol/playlist.ts`):

```ts
type PlaylistItemV1 = {
  id: string;
  name: string;
  cover_pbm_base64: string | null; // P4-dithered cover; null → CSS hatch fallback
};

type PlaylistSnapshotV1 = {
  as_of: string;
  stale: boolean;
  playlists: readonly PlaylistItemV1[];
};
```

Elixir-side shape (host builds this as the envelope `payload` for `channel: :playlist`):

```elixir
%{
  as_of: String.t(),
  stale: boolean(),
  playlists: [
    %{id: String.t(), name: String.t(), cover_pbm_base64: String.t() | nil}
  ]
}
```

---

## Device client (later wire-up — not lane work)

- One WS connection; fan-out by `channel` into pure screen stores.
- Host-down: keep last payload per channel (snapshot store).
- Input (wheel/presets) stays on device via P2/P3; only intents that need host APIs cross the wire.

---

## Elixir / TS stubs (repo)

| Path | Owner |
|------|--------|
| `host/lib/paper_weight/protocol/envelope.ex` | orchestrator only |
| `src/device-ui/src/protocol/envelope.ts` | orchestrator only |
| `src/device-ui/src/protocol/<channel>.ts` | domain lane (payload types) |
