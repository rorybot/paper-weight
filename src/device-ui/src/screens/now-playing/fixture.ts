import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";

/**
 * Fixture shaped for `spec/now-playing-4a.png` + N3 lyrics overlay.
 * Timed lines around progress 1:22 (82_000 ms).
 */
export const nowPlayingFixtureSnapshot: NowPlayingSnapshotV1 = Object.freeze({
  as_of: "2026-07-16T14:32:00Z",
  stale: false,
  track: Object.freeze({
    title: "Galactic",
    artist: "Tenure",
    album: "Sink",
    art_pbm_base64: null,
    duration_ms: 221_000,
    progress_ms: 82_000,
  }),
  queue: Object.freeze([
    Object.freeze({ title: "Last'en", artist: "Tenure" }),
    Object.freeze({ title: "Housebound", artist: "Tenure" }),
    Object.freeze({ title: "Natural Light", artist: "Tenure" }),
    Object.freeze({ title: "Circuits", artist: "Tenure" }),
  ]),
  volume: Object.freeze({ level: 62 }),
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
