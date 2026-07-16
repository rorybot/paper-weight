import type { PlaylistSnapshotV1 } from "../../protocol/playlist";

/**
 * Fixture shaped for `spec/playlist-4c.png` (L1 UI-ahead).
 * 8 playlists; selection index 1 = drive.exe (position 2/8).
 */
export const playlistFixtureSnapshot: PlaylistSnapshotV1 = Object.freeze({
  as_of: "2026-07-16T20:00:00Z",
  stale: false,
  playlists: Object.freeze([
    Object.freeze({
      id: "pl-sink",
      name: "Sink",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-drive",
      name: "drive.exe",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-heavy",
      name: "heavy rotation",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-kentucky",
      name: "kentucky basement",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-storm",
      name: "storm watching",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-radar",
      name: "release radar",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-late",
      name: "late night mix",
      cover_pbm_base64: null,
    }),
    Object.freeze({
      id: "pl-commute",
      name: "commute loop",
      cover_pbm_base64: null,
    }),
  ]),
});
