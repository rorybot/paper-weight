/** Photo channel payload — owned by H1/H2. See features/photo/spec.md */

export type PhotoSnapshotV1 = {
  readonly as_of: string;
  readonly stale: boolean;
  readonly source: string;
  readonly empty: boolean;
  /** 1-based N in "photo N/M"; 0 when empty */
  readonly index: number;
  /** M in "photo N/M" */
  readonly total: number;
  readonly caption: string;
  /** stable id (basename without ext); null when empty */
  readonly id: string | null;
  /** host path for dither pipeline; null when empty */
  readonly path: string | null;
  /** pin: auto-rotation does not advance while true */
  readonly kept: boolean;
  /** ceil remaining minutes until auto-reprint; 0 when due */
  readonly reprints_in_min: number;
  readonly reprint_interval_min: number;
  /** pre-dithered slot; null until host art path produces it */
  readonly art_pbm_base64: string | null;
};
