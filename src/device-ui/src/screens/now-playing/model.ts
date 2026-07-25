import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import { pbmBase64ToDataUrl } from "../photo/pbm";

export const NOW_PLAYING_QUEUE_WINDOW = 4;

export type NowPlayingUiState = Readonly<{ selectedIndex: number }>;

export type NowPlayingUiCommand =
  | Readonly<{ type: "move-queue-selection"; delta: number }>
  | Readonly<{ type: "play-selected-queue-item" }>;

export type PlayQueueItemArgs = Readonly<{ id: string }>;

export type NowPlayingReduceResult = Readonly<{
  state: NowPlayingUiState;
  play: PlayQueueItemArgs | null;
}>;

export type NowPlayingCommandConsumption = Readonly<{
  consumedCommand: NowPlayingUiCommand | null;
  result: NowPlayingReduceResult;
}>;

export type NowPlayingViewModel = Readonly<{
  clock: string;
  stale: boolean;
  connectionLabel: string;
  track: Readonly<{
    title: string;
    artist: string;
    album: string;
    artSource: string | null;
    elapsed: string;
    duration: string;
    progressPercent: number;
  }>;
  queue: readonly Readonly<{
    id: string;
    index: number;
    title: string;
    artist: string;
    selected: boolean;
  }>[];
  queueRemainder: number;
  queuePosition: string;
}>;

const clamp = (value: number, minimum: number, maximum: number): number =>
  Math.min(Math.max(Number.isFinite(value) ? value : minimum, minimum), maximum);

export const formatMillis = (milliseconds: number): string => {
  const seconds = Math.floor(Math.max(Number.isFinite(milliseconds) ? milliseconds : 0, 0) / 1_000);
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
};

export const formatSnapshotClock = (asOf: string): string => {
  const date = new Date(asOf);
  if (Number.isNaN(date.getTime())) return "--:--";
  return `${String(date.getUTCHours()).padStart(2, "0")}:${String(date.getUTCMinutes()).padStart(2, "0")}`;
};

export const artSource = (value: string | null): string | null => {
  if (value === null || value.trim() === "") return null;
  const normalized = value.trim();
  return /^(data:|https?:|\/|\.\/|\.\.\/)/.test(normalized)
    ? normalized
    : pbmBase64ToDataUrl(normalized);
};

export const initialNowPlayingUiState = (
  snapshot: NowPlayingSnapshotV1,
  selectedIndex = 0,
): NowPlayingUiState =>
  Object.freeze({
    selectedIndex: clamp(
      selectedIndex,
      0,
      Math.max(0, snapshot.queue.length - 1),
    ),
  });

export const reconcileNowPlayingUiState = (
  state: NowPlayingUiState,
  snapshot: NowPlayingSnapshotV1,
): NowPlayingUiState => {
  const selectedIndex = clamp(
    state.selectedIndex,
    0,
    Math.max(0, snapshot.queue.length - 1),
  );
  return selectedIndex === state.selectedIndex
    ? state
    : Object.freeze({ selectedIndex });
};

export const reduceNowPlayingUi = (
  state: NowPlayingUiState,
  command: NowPlayingUiCommand,
  snapshot: NowPlayingSnapshotV1,
): NowPlayingReduceResult => {
  const current = reconcileNowPlayingUiState(state, snapshot);
  const count = snapshot.queue.length;

  if (command.type === "move-queue-selection") {
    if (command.delta === 0 || count === 0) {
      return Object.freeze({ state: current, play: null });
    }
    const selectedIndex = clamp(
      current.selectedIndex + command.delta,
      0,
      count - 1,
    );
    return Object.freeze({
      state:
        selectedIndex === current.selectedIndex
          ? current
          : Object.freeze({ selectedIndex }),
      play: null,
    });
  }

  const item = snapshot.queue[current.selectedIndex];
  return Object.freeze({
    state: current,
    play: item ? Object.freeze({ id: item.id }) : null,
  });
};

export const consumeNowPlayingCommand = (
  consumedCommand: NowPlayingUiCommand | null,
  command: NowPlayingUiCommand | null,
  state: NowPlayingUiState,
  snapshot: NowPlayingSnapshotV1,
): NowPlayingCommandConsumption => {
  const current = reconcileNowPlayingUiState(state, snapshot);
  if (command === null || command === consumedCommand) {
    return Object.freeze({
      consumedCommand,
      result: Object.freeze({ state: current, play: null }),
    });
  }
  return Object.freeze({
    consumedCommand: command,
    result: reduceNowPlayingUi(current, command, snapshot),
  });
};

export const visibleQueueIndices = (
  queueLength: number,
  selectedIndex: number,
  windowSize = NOW_PLAYING_QUEUE_WINDOW,
): readonly number[] => {
  if (queueLength <= 0 || windowSize <= 0) return [];
  const size = Math.min(queueLength, windowSize);
  const safeSelection = clamp(selectedIndex, 0, queueLength - 1);
  const start = clamp(
    safeSelection - Math.floor(size / 2),
    0,
    queueLength - size,
  );
  return Array.from({ length: size }, (_value, index) => start + index);
};

export const buildNowPlayingViewModel = (
  snapshot: NowPlayingSnapshotV1,
  selectedIndex = 0,
): NowPlayingViewModel => {
  const durationMs = Math.max(snapshot.track?.duration_ms ?? 0, 0);
  const progressMs = clamp(snapshot.track?.progress_ms ?? 0, 0, durationMs);
  const indices = visibleQueueIndices(snapshot.queue.length, selectedIndex);
  const safeSelection = clamp(
    selectedIndex,
    0,
    Math.max(0, snapshot.queue.length - 1),
  );
  const lastVisible = indices.at(-1);

  return {
    clock: formatSnapshotClock(snapshot.as_of),
    stale: snapshot.stale,
    connectionLabel: snapshot.stale ? "spotify:stale" : "spotify:connect",
    track: {
      title: snapshot.track?.title || "Nothing playing",
      artist: snapshot.track?.artist || "Waiting for Spotify",
      album: snapshot.track?.album || "Queue ready",
      artSource: artSource(snapshot.track?.art_pbm_base64 ?? null),
      elapsed: formatMillis(progressMs),
      duration: formatMillis(durationMs),
      progressPercent: durationMs === 0 ? 0 : Math.round((progressMs / durationMs) * 100),
    },
    queue: indices.flatMap((index) => {
      const item = snapshot.queue[index];
      return item
        ? [{ ...item, index, selected: index === safeSelection }]
        : [];
    }),
    queueRemainder:
      lastVisible === undefined
        ? 0
        : Math.max(snapshot.queue.length - 1 - lastVisible, 0),
    queuePosition:
      snapshot.queue.length === 0
        ? "0 / 0"
        : `${safeSelection + 1} / ${snapshot.queue.length}`,
  };
};
