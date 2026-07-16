import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { feedFixtureSnapshot } from "./fixture";
import { FeedScreen } from "./FeedScreen";
import {
  initialFeedUiState,
  reduceFeedUi,
  type FeedUiState,
} from "./model";

const snap = feedFixtureSnapshot;

describe("FeedScreen", () => {
  it("renders 800×480 BERG layout matching feed-4f intent", () => {
    const html = render(
      <FeedScreen snapshot={snap} theme="berg" initialSelectedIndex={1} />,
    );

    expect(html).toContain("fd-screen");
    expect(html).toContain('data-theme="berg"');
    expect(html).toContain('data-screen="feed"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("3:fd*");
    expect(html).toContain("the feed, printed for you");
    expect(html).toContain("14:20");
    expect(html).toContain("@NWSBoulder");
    expect(html).toContain("@tenureband");
    expect(html).toContain("@carthinghacks");
    expect(html).toContain("basement friday");
    expect(html).toContain("berg-card--paper");
    expect(html).toContain("berg-card--selected");
    expect(html).toContain("READING");
    expect(html).toContain("turn to scroll");
    expect(html).toContain("press to enlarge");
    expect(html).toContain("read-only snapshot");
    expect(html).toContain('data-visible-count="3"');
    expect(html).toContain("2/7");
  });

  it("shows ≥3 posts in fixture snapshot", () => {
    expect(snap.posts.length).toBeGreaterThanOrEqual(3);
    const html = render(<FeedScreen snapshot={snap} />);
    expect(html).toContain('data-post-count="7"');
  });

  it("wheel scroll moves selection (controlled ui)", () => {
    let ui = initialFeedUiState(snap, 1);
    ui = reduceFeedUi(ui, { type: "scroll-feed", delta: 1 }, snap.posts.length);
    const html = render(<FeedScreen snapshot={snap} ui={ui} />);
    expect(html).toContain('data-selected-index="2"');
    expect(html).toContain("@carthinghacks");
    expect(html).toContain('data-selected="true"');
  });

  it("press enlarge + back collapse", () => {
    let ui: FeedUiState = initialFeedUiState(snap, 1);
    ui = reduceFeedUi(ui, { type: "toggle-feed-detail" }, snap.posts.length);
    let html = render(<FeedScreen snapshot={snap} ui={ui} />);
    expect(html).toContain('data-enlarged="true"');
    expect(html).toContain("READING NOW");
    expect(html).toContain("collapse");

    ui = reduceFeedUi(ui, { type: "set-feed-enlarged", enlarged: false }, snap.posts.length);
    html = render(<FeedScreen snapshot={snap} ui={ui} />);
    expect(html).toContain('data-enlarged="false"');
    expect(html).toContain("press to enlarge");
  });

  it("respects external enlarged prop from shell overlay", () => {
    const html = render(
      <FeedScreen snapshot={snap} enlarged={true} initialSelectedIndex={1} />,
    );
    expect(html).toContain('data-enlarged="true"');
  });

  it("marks stale snapshots", () => {
    const html = render(
      <FeedScreen snapshot={{ ...snap, stale: true }} />,
    );
    expect(html).toContain('data-stale="true"');
  });
});
