import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";

/**
 * Fixture shaped for `spec/now-playing-4a.png` (N2) + timed lyrics (N3).
 * Progress 1:22 (82_000 ms); volume 70% matches mockup segments.
 */
export const nowPlayingFixtureSnapshot: NowPlayingSnapshotV1 = Object.freeze({
  as_of: "2026-07-16T14:32:00Z",
  stale: false,
  track: Object.freeze({
    title: "Galactic",
    artist: "Tenure",
    album: "Sink · 2020",
    art_pbm_base64: "UDQKMTYgMTYKqlVVqqpVVaqqVVWqqlVVqqpVVaqqVVWqqlVVqqpVVao=",
    duration_ms: 221_000,
    progress_ms: 82_000,
  }),
  queue: Object.freeze([
    Object.freeze({ id: "q0000000000000000000001", title: "Last'en", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000002", title: "Housebound", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000003", title: "Natural Light", artist: "Sink" }),
    Object.freeze({ id: "q0000000000000000000004", title: "Circuits", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000005", title: "Soft Static", artist: "Night Bus" }),
    Object.freeze({ id: "q0000000000000000000006", title: "Monorail", artist: "Night Bus" }),
    Object.freeze({ id: "q0000000000000000000007", title: "New Geometry", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000008", title: "Star Map", artist: "Sink" }),
    Object.freeze({ id: "q0000000000000000000009", title: "Receiver", artist: "Night Bus" }),
    Object.freeze({ id: "q0000000000000000000010", title: "Signal Path", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000011", title: "Night Window", artist: "Sink" }),
    Object.freeze({ id: "q0000000000000000000012", title: "Arc Lamp", artist: "Tenure" }),
    Object.freeze({ id: "q0000000000000000000013", title: "Terminal", artist: "Night Bus" }),
  ]),
  volume: Object.freeze({ level: 70 }),
  lyrics: Object.freeze({
    lines: Object.freeze([
      Object.freeze({ t_ms: 0, text: "tape hiss, then a door" }),
      Object.freeze({ t_ms: 12_000, text: "we left the porch light on" }),
      Object.freeze({ t_ms: 28_000, text: "for something that never parks" }),
      Object.freeze({ t_ms: 44_000, text: "galactic — not far, just high" }),
      Object.freeze({ t_ms: 62_000, text: "count the windows in the dark" }),
      Object.freeze({ t_ms: 78_000, text: "your name is still a station" }),
      Object.freeze({ t_ms: 94_000, text: "I tune past on the long drive" }),
      Object.freeze({ t_ms: 112_000, text: "sink the needle, keep the room" }),
      Object.freeze({ t_ms: 130_000, text: "until the map forgets our street" }),
      Object.freeze({ t_ms: 150_000, text: "and the night says stay" }),
    ]),
  }),
});

/** Same track metadata, no lyrics payload (empty overlay state). */
export const nowPlayingFixtureNoLyrics: NowPlayingSnapshotV1 = Object.freeze({
  ...nowPlayingFixtureSnapshot,
  lyrics: null,
});
