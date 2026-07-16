/** Pure feed screen UI state — shell emits `scroll-feed`; overlay owns enlarge. */

import type { FeedPostV1, FeedSnapshotV1 } from "../../protocol/feed";

/** Visible posts in the main column (mockup ~3). */
export const FEED_WINDOW = 3;

export type FeedUiState = Readonly<{
  selectedIndex: number;
  /** True when shell overlay is `feed-detail` (press enlarge). */
  enlarged: boolean;
}>;

export type FeedUiCommand =
  | Readonly<{ type: "scroll-feed"; delta: number }>
  | Readonly<{ type: "toggle-feed-detail" }>
  | Readonly<{ type: "set-feed-enlarged"; enlarged: boolean }>;

export const initialFeedUiState = (
  snapshot: FeedSnapshotV1,
  selectedIndex = 1,
): FeedUiState => {
  const max = Math.max(0, snapshot.posts.length - 1);
  return Object.freeze({
    selectedIndex: clamp(selectedIndex, 0, max),
    enlarged: false,
  });
};

export const reduceFeedUi = (
  state: FeedUiState,
  command: FeedUiCommand,
  postCount: number,
): FeedUiState => {
  switch (command.type) {
    case "scroll-feed": {
      if (command.delta === 0 || postCount <= 0) return state;
      // While enlarged, wheel still scrolls selection (shell comment).
      const next = clamp(
        state.selectedIndex + command.delta,
        0,
        postCount - 1,
      );
      if (next === state.selectedIndex) return state;
      return Object.freeze({ ...state, selectedIndex: next });
    }
    case "toggle-feed-detail":
      return Object.freeze({ ...state, enlarged: !state.enlarged });
    case "set-feed-enlarged":
      if (state.enlarged === command.enlarged) return state;
      return Object.freeze({ ...state, enlarged: command.enlarged });
    default:
      return state;
  }
};

/**
 * Window of up to `FEED_WINDOW` indices, keeping selection visible
 * (prefer centered when list is long enough).
 */
export const visibleIndices = (
  postCount: number,
  selectedIndex: number,
  windowSize: number = FEED_WINDOW,
): readonly number[] => {
  if (postCount <= 0) return [];
  if (postCount <= windowSize) {
    return Array.from({ length: postCount }, (_, i) => i);
  }
  let start = selectedIndex - Math.floor(windowSize / 2);
  start = clamp(start, 0, postCount - windowSize);
  return Array.from({ length: windowSize }, (_, i) => start + i);
};

export const selectedPost = (
  snapshot: FeedSnapshotV1,
  state: FeedUiState,
): FeedPostV1 | null => snapshot.posts[state.selectedIndex] ?? null;

/** "14:20" from ISO as_of for topbar chrome. */
export const clockLabel = (asOf: string): string => {
  const d = new Date(asOf);
  if (Number.isNaN(d.getTime())) return "";
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
};

/** Receipt-rail thumb position 0–1 along the track. */
export const railProgress = (
  selectedIndex: number,
  postCount: number,
): number => {
  if (postCount <= 1) return 0;
  return selectedIndex / (postCount - 1);
};

export const positionLabel = (
  selectedIndex: number,
  postCount: number,
): string => {
  if (postCount <= 0) return "0/0";
  return `${selectedIndex + 1}/${postCount}`;
};

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
