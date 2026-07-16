import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";

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
    { title: "Last'en", artist: "Tenure" },
    { title: "Housebound", artist: "Tenure" },
    { title: "Natural Light", artist: "Sink" },
    { title: "Circuits", artist: "Tenure" },
    { title: "Soft Static", artist: "Night Bus" },
    { title: "Monorail", artist: "Night Bus" },
    { title: "New Geometry", artist: "Tenure" },
    { title: "Star Map", artist: "Sink" },
    { title: "Receiver", artist: "Night Bus" },
    { title: "Signal Path", artist: "Tenure" },
    { title: "Night Window", artist: "Sink" },
    { title: "Arc Lamp", artist: "Tenure" },
    { title: "Terminal", artist: "Night Bus" },
  ]),
  volume: Object.freeze({ level: 70 }),
  lyrics: null,
});
