import { describe, expect, it } from "vitest";

import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import { nowPlayingFixtureSnapshot } from "./fixture";
import {
  artSource,
  buildNowPlayingViewModel,
  consumeNowPlayingCommand,
  formatMillis,
  formatSnapshotClock,
  initialNowPlayingUiState,
  reconcileNowPlayingUiState,
  reduceNowPlayingUi,
  visibleQueueIndices,
} from "./model";

describe("now-playing view model", () => {
  it("formats duration and snapshot clock deterministically", () => {
    expect(formatMillis(82_999)).toBe("1:22");
    expect(formatMillis(-50)).toBe("0:00");
    expect(formatSnapshotClock("2026-07-16T14:32:00Z")).toBe("14:32");
    expect(formatSnapshotClock("invalid")).toBe("--:--");
  });

  it("clamps progress and renders the first interactive queue window", () => {
    const snapshot: NowPlayingSnapshotV1 = {
      ...nowPlayingFixtureSnapshot,
      track: nowPlayingFixtureSnapshot.track
        ? { ...nowPlayingFixtureSnapshot.track, progress_ms: 999_000 }
        : null,
    };

    const view = buildNowPlayingViewModel(snapshot);

    expect(view.track.progressPercent).toBe(100);
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
    });

    expect(view.connectionLabel).toBe("spotify:stale");
    expect(view.track.title).toBe("Nothing playing");
    expect(view.track.progressPercent).toBe(0);
    expect(view.queueRemainder).toBe(0);
    expect(view.queuePosition).toBe("0 / 0");
  });

  it("accepts URLs and converts host PBM base64 for Chromium", () => {
    expect(artSource(null)).toBeNull();
    expect(artSource("/art/current.pbm")).toBe("/art/current.pbm");
    expect(artSource("UDQKMSAxCoA=")).toMatch(/^data:image\/bmp;base64,/);
    expect(artSource("!!!")).toBeNull();
  });
});

describe("now-playing queue UI reducer", () => {
  it("starts at zero and applies full positive/negative deltas", () => {
    const initial = initialNowPlayingUiState(nowPlayingFixtureSnapshot);
    expect(initial).toEqual({ selectedIndex: 0 });

    const forward = reduceNowPlayingUi(
      initial,
      { type: "move-queue-selection", delta: 6 },
      nowPlayingFixtureSnapshot,
    );
    expect(forward.state).toEqual({ selectedIndex: 6 });

    const back = reduceNowPlayingUi(
      forward.state,
      { type: "move-queue-selection", delta: -4 },
      nowPlayingFixtureSnapshot,
    );
    expect(back.state).toEqual({ selectedIndex: 2 });
  });

  it("clamps at both boundaries and preserves zero-delta state", () => {
    const start = initialNowPlayingUiState(nowPlayingFixtureSnapshot, 2);
    expect(
      reduceNowPlayingUi(
        start,
        { type: "move-queue-selection", delta: -99 },
        nowPlayingFixtureSnapshot,
      ).state,
    ).toEqual({ selectedIndex: 0 });
    expect(
      reduceNowPlayingUi(
        start,
        { type: "move-queue-selection", delta: 99 },
        nowPlayingFixtureSnapshot,
      ).state,
    ).toEqual({ selectedIndex: nowPlayingFixtureSnapshot.queue.length - 1 });
    expect(
      reduceNowPlayingUi(
        start,
        { type: "move-queue-selection", delta: 0 },
        nowPlayingFixtureSnapshot,
      ).state,
    ).toBe(start);
  });

  it("returns no play for empty queue and resolves the selected id", () => {
    const selected = initialNowPlayingUiState(nowPlayingFixtureSnapshot, 5);
    expect(
      reduceNowPlayingUi(
        selected,
        { type: "play-selected-queue-item" },
        nowPlayingFixtureSnapshot,
      ).play,
    ).toEqual({ id: nowPlayingFixtureSnapshot.queue[5]?.id });

    const empty = { ...nowPlayingFixtureSnapshot, queue: [] };
    expect(
      reduceNowPlayingUi(
        selected,
        { type: "play-selected-queue-item" },
        empty,
      ),
    ).toEqual({ state: { selectedIndex: 0 }, play: null });
  });

  it("clamps a positional selection when a refreshed queue becomes shorter", () => {
    const state = initialNowPlayingUiState(nowPlayingFixtureSnapshot, 9);
    const shorter = {
      ...nowPlayingFixtureSnapshot,
      queue: nowPlayingFixtureSnapshot.queue.slice(0, 3),
    };
    expect(reconcileNowPlayingUiState(state, shorter)).toEqual({
      selectedIndex: 2,
    });
  });

  it("returns centered four-row windows at start, middle, and end", () => {
    expect(visibleQueueIndices(13, 0)).toEqual([0, 1, 2, 3]);
    expect(visibleQueueIndices(13, 6)).toEqual([4, 5, 6, 7]);
    expect(visibleQueueIndices(13, 12)).toEqual([9, 10, 11, 12]);
  });

  it("consumes a retained play command once across snapshot rerenders", () => {
    const command = { type: "play-selected-queue-item" } as const;
    const state = initialNowPlayingUiState(nowPlayingFixtureSnapshot, 3);
    const first = consumeNowPlayingCommand(
      null,
      command,
      state,
      nowPlayingFixtureSnapshot,
    );
    expect(first.result.play).toEqual({
      id: nowPlayingFixtureSnapshot.queue[3]?.id,
    });

    const refreshed = { ...nowPlayingFixtureSnapshot, stale: true };
    const replay = consumeNowPlayingCommand(
      first.consumedCommand,
      command,
      first.result.state,
      refreshed,
    );
    expect(replay.result.play).toBeNull();
  });
});
