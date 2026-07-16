/** Now-playing channel payload — owned by N1/N2. See features/now-playing/spec.md */

export type NowPlayingTrackV1 = {
  readonly title: string;
  readonly artist: string;
  readonly album: string;
  readonly art_pbm_base64: string | null;
  readonly duration_ms: number;
  readonly progress_ms: number;
};

export type NowPlayingSnapshotV1 = {
  readonly as_of: string;
  readonly stale: boolean;
  readonly track: NowPlayingTrackV1 | null;
  readonly queue: readonly { readonly title: string; readonly artist: string }[];
  readonly volume: { readonly level: number };
  readonly lyrics: null | {
    readonly lines: readonly { readonly t_ms: number; readonly text: string }[];
  };
};
