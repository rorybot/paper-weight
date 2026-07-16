/**
 * Playlist grid payload types — owned by L1.
 * Not a frozen host channel yet (playlists may ride `now_playing` later).
 * Intent: envelope `play_playlist` with `{ id: string }`.
 * @see features/playlist/spec.md
 */

export type PlaylistItemV1 = {
  readonly id: string;
  readonly name: string;
  /** Optional host-dithered cover (P4 PBM base64); null → CSS hatch fallback. */
  readonly cover_pbm_base64: string | null;
};

export type PlaylistSnapshotV1 = {
  readonly as_of: string;
  readonly stale: boolean;
  readonly playlists: readonly PlaylistItemV1[];
};
