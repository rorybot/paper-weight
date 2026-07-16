import { describe, expect, it } from "vitest";

import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import { nowPlayingFixtureSnapshot } from "./fixture";
import {
  artSource,
  buildNowPlayingViewModel,
  formatMillis,
  formatSnapshotClock,
} from "./model";

describe("now-playing view model", () => {
  it("formats duration and snapshot clock deterministically", () => {
    expect(formatMillis(82_999)).toBe("1:22");
    expect(formatMillis(-50)).toBe("0:00");
    expect(formatSnapshotClock("2026-07-16T14:32:00Z")).toBe("14:32");
    expect(formatSnapshotClock("invalid")).toBe("--:--");
  });

  it("clamps progress and volume while keeping the queue display-only shape", () => {
    const snapshot: NowPlayingSnapshotV1 = {
      ...nowPlayingFixtureSnapshot,
      track: nowPlayingFixtureSnapshot.track
        ? { ...nowPlayingFixtureSnapshot.track, progress_ms: 999_000 }
        : null,
      volume: { level: 140 },
    };

    const view = buildNowPlayingViewModel(snapshot);

    expect(view.track.progressPercent).toBe(100);
    expect(view.volume.level).toBe(100);
    expect(view.volume.segments).toEqual(Array(10).fill(true));
    expect(view.queue).toHaveLength(4);
    expect(view.queue[0]?.selected).toBe(true);
    expect(view.queueRemainder).toBe(9);
  });

  it("builds safe empty and stale states", () => {
    const view = buildNowPlayingViewModel({
      ...nowPlayingFixtureSnapshot,
      stale: true,
      track: null,
      queue: [],
      volume: { level: -1 },
    });

    expect(view.connectionLabel).toBe("spotify:stale");
    expect(view.track.title).toBe("Nothing playing");
    expect(view.track.progressPercent).toBe(0);
    expect(view.volume.level).toBe(0);
    expect(view.queueRemainder).toBe(0);
  });

  it("accepts URLs and converts host PBM base64 for Chromium", () => {
    expect(artSource(null)).toBeNull();
    expect(artSource("/art/current.pbm")).toBe("/art/current.pbm");
    expect(artSource("UDQKMSAxCoA=")).toMatch(/^data:image\/bmp;base64,/);
    expect(artSource("!!!")).toBeNull();
  });
});
