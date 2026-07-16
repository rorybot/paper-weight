import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import { pbmBase64ToDataUrl } from "../photo/pbm";

const VISIBLE_QUEUE_ITEMS = 4;
const VOLUME_SEGMENTS = 10;

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
    title: string;
    artist: string;
    selected: boolean;
  }>[];
  queueRemainder: number;
  volume: Readonly<{
    level: number;
    segments: readonly boolean[];
  }>;
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

export const buildNowPlayingViewModel = (
  snapshot: NowPlayingSnapshotV1,
): NowPlayingViewModel => {
  const durationMs = Math.max(snapshot.track?.duration_ms ?? 0, 0);
  const progressMs = clamp(snapshot.track?.progress_ms ?? 0, 0, durationMs);
  const level = Math.round(clamp(snapshot.volume.level, 0, 100));
  const filledSegments = Math.round((level / 100) * VOLUME_SEGMENTS);

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
    queue: snapshot.queue.slice(0, VISIBLE_QUEUE_ITEMS).map((item, index) => ({
      title: item.title,
      artist: item.artist,
      selected: index === 0,
    })),
    queueRemainder: Math.max(snapshot.queue.length - VISIBLE_QUEUE_ITEMS, 0),
    volume: {
      level,
      segments: Array.from({ length: VOLUME_SEGMENTS }, (_value, index) => index < filledSegments),
    },
  };
};
