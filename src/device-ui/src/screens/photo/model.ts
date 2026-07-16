/** Pure photo screen helpers — shell emits skip/keep; host owns library (H1). */

import type { PhotoSnapshotV1 } from "../../protocol/photo";

/** Shell command names for wave-3 wire-up (match `shell/model.ts`). */
export type PhotoUiCommand =
  | Readonly<{ type: "skip-photo"; delta: number }>
  | Readonly<{ type: "keep-photo-on-show" }>;

/** Local demo library for fixture tests / harness (mirrors H1 rotate rules). */
export type PhotoEntryV1 = Readonly<{
  id: string;
  caption: string;
  path: string;
  art_pbm_base64: string | null;
}>;

export type PhotoLocalState = Readonly<{
  entries: readonly PhotoEntryV1[];
  /** 0-based */
  index: number;
  kept: boolean;
  reprints_in_min: number;
  reprint_interval_min: number;
  as_of: string;
  source: string;
  stale: boolean;
}>;

export const initialPhotoLocalState = (
  entries: readonly PhotoEntryV1[],
  opts?: Readonly<{
    index?: number;
    reprints_in_min?: number;
    reprint_interval_min?: number;
    as_of?: string;
    source?: string;
  }>,
): PhotoLocalState => {
  const interval = opts?.reprint_interval_min ?? 5;
  return Object.freeze({
    entries,
    index: clamp(opts?.index ?? 0, 0, Math.max(0, entries.length - 1)),
    kept: false,
    reprints_in_min: opts?.reprints_in_min ?? interval,
    reprint_interval_min: interval,
    as_of: opts?.as_of ?? "2026-07-16T15:00:00Z",
    source: opts?.source ?? "local library",
    stale: false,
  });
};

export const reducePhotoLocal = (
  state: PhotoLocalState,
  command: PhotoUiCommand,
): PhotoLocalState => {
  if (state.entries.length === 0) return state;

  switch (command.type) {
    case "skip-photo": {
      const delta = command.delta === 0 ? 1 : Math.sign(command.delta) || 1;
      const n = state.entries.length;
      const next = ((state.index + delta) % n + n) % n;
      return Object.freeze({
        ...state,
        index: next,
        kept: false,
        reprints_in_min: state.reprint_interval_min,
      });
    }
    case "keep-photo-on-show":
      return Object.freeze({ ...state, kept: !state.kept });
    default:
      return state;
  }
};

export const localToSnapshot = (state: PhotoLocalState): PhotoSnapshotV1 => {
  const entry = state.entries[state.index] ?? null;
  const empty = entry === null;
  return Object.freeze({
    as_of: state.as_of,
    stale: state.stale,
    source: state.source,
    empty,
    index: empty ? 0 : state.index + 1,
    total: state.entries.length,
    caption: entry?.caption ?? "",
    id: entry?.id ?? null,
    path: entry?.path ?? null,
    kept: state.kept,
    reprints_in_min: state.reprints_in_min,
    reprint_interval_min: state.reprint_interval_min,
    art_pbm_base64: entry?.art_pbm_base64 ?? null,
  });
};

/** Footer / meta: `photo N/M · reprints in X min` */
export const statusLine = (snapshot: PhotoSnapshotV1): string => {
  if (snapshot.empty || snapshot.total <= 0) {
    return "photo 0/0 · no reprints";
  }
  return `photo ${snapshot.index}/${snapshot.total} · reprints in ${snapshot.reprints_in_min} min`;
};

export const keepLabel = (kept: boolean): string =>
  kept ? "kept on show" : "press keep";

export const skipLabel = (): string => "◉ turn to skip";

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
