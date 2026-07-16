import { describe, expect, it } from "vitest";

import { feedFixtureSnapshot } from "./fixture";
import {
  clockLabel,
  FEED_WINDOW,
  initialFeedUiState,
  positionLabel,
  railProgress,
  reduceFeedUi,
  selectedPost,
  visibleIndices,
} from "./model";

const snap = feedFixtureSnapshot;

describe("reduceFeedUi", () => {
  it("scrolls selection and clamps", () => {
    let s = initialFeedUiState(snap, 1);
    s = reduceFeedUi(s, { type: "scroll-feed", delta: 1 }, snap.posts.length);
    expect(s.selectedIndex).toBe(2);
    s = reduceFeedUi(s, { type: "scroll-feed", delta: 99 }, snap.posts.length);
    expect(s.selectedIndex).toBe(snap.posts.length - 1);
    s = reduceFeedUi(s, { type: "scroll-feed", delta: -99 }, snap.posts.length);
    expect(s.selectedIndex).toBe(0);
  });

  it("toggles enlarge / collapse (press + back path)", () => {
    let s = initialFeedUiState(snap, 1);
    s = reduceFeedUi(s, { type: "toggle-feed-detail" }, snap.posts.length);
    expect(s.enlarged).toBe(true);
    s = reduceFeedUi(s, { type: "toggle-feed-detail" }, snap.posts.length);
    expect(s.enlarged).toBe(false);
    s = reduceFeedUi(
      s,
      { type: "set-feed-enlarged", enlarged: true },
      snap.posts.length,
    );
    expect(s.enlarged).toBe(true);
    s = reduceFeedUi(
      s,
      { type: "set-feed-enlarged", enlarged: false },
      snap.posts.length,
    );
    expect(s.enlarged).toBe(false);
  });

  it("scrolls while enlarged (shell keeps list under overlay)", () => {
    let s = initialFeedUiState(snap, 1);
    s = reduceFeedUi(s, { type: "toggle-feed-detail" }, snap.posts.length);
    s = reduceFeedUi(s, { type: "scroll-feed", delta: 1 }, snap.posts.length);
    expect(s.enlarged).toBe(true);
    expect(s.selectedIndex).toBe(2);
  });
});

describe("visibleIndices", () => {
  it("returns up to FEED_WINDOW posts with selection visible", () => {
    expect(visibleIndices(3, 1)).toEqual([0, 1, 2]);
    expect(visibleIndices(snap.posts.length, 1).length).toBe(FEED_WINDOW);
    expect(visibleIndices(snap.posts.length, 1)).toContain(1);
    expect(visibleIndices(snap.posts.length, 0)).toEqual([0, 1, 2]);
    const nearEnd = visibleIndices(snap.posts.length, snap.posts.length - 1);
    expect(nearEnd).toContain(snap.posts.length - 1);
    expect(nearEnd.length).toBe(FEED_WINDOW);
  });
});

describe("labels / rail", () => {
  it("formats clock, position, progress", () => {
    expect(clockLabel("2026-07-15T14:20:00Z")).toBe("14:20");
    expect(positionLabel(1, 7)).toBe("2/7");
    expect(railProgress(0, 7)).toBe(0);
    expect(railProgress(6, 7)).toBe(1);
  });

  it("selectedPost follows index", () => {
    const s = initialFeedUiState(snap, 1);
    expect(selectedPost(snap, s)?.handle).toBe("@tenureband");
  });
});
