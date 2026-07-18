import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { applyEnvelope, fixtureChannelStoreState } from "./channelStore";
import { ShellApp } from "./ShellApp";

const LIVE_TITLE = "Live From The Gateway";

const fixtureNowPlaying = fixtureChannelStoreState.snapshots.now_playing;

const liveState = applyEnvelope(fixtureChannelStoreState, {
  v: 1,
  ts: 1721150000000,
  channel: "now_playing",
  gen: 1,
  payload: {
    ...fixtureNowPlaying,
    track:
      fixtureNowPlaying.track === null
        ? null
        : { ...fixtureNowPlaying.track, title: LIVE_TITLE },
  },
});

describe("ShellApp channelState seam (W3-D)", () => {
  it("renders live channel-store state when provided", () => {
    const html = render(
      <ShellApp
        bridgeUrl={null}
        initialScreen="now-playing"
        channelState={liveState}
      />,
    );
    expect(html).toContain(LIVE_TITLE);
    expect(html).not.toContain("Galactic");
  });

  it("defaults to the fixture store when channelState is omitted", () => {
    const html = render(<ShellApp bridgeUrl={null} initialScreen="now-playing" />);
    expect(html).toContain("Galactic");
    expect(html).not.toContain(LIVE_TITLE);
  });
});
