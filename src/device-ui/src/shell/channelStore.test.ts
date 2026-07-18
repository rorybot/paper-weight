import { describe, expect, it } from "vitest";

import type { EnvelopeV1 } from "../protocol/envelope";
import { feedFixtureSnapshot } from "../screens/feed";
import { playlistFixtureSnapshot } from "../screens/playlist";
import { weatherFixtureSnapshot } from "../screens/weather";
import {
  applyEnvelope,
  fixtureChannelStoreState,
  type ChannelStoreState,
} from "./channelStore";

const envelope = (
  overrides: Partial<EnvelopeV1> & Pick<EnvelopeV1, "channel" | "gen" | "payload">,
): EnvelopeV1 => ({
  v: 1,
  ts: 1721150000000,
  ...overrides,
});

describe("fixtureChannelStoreState", () => {
  it("seeds every managed channel at gen 0 from its fixture", () => {
    expect(fixtureChannelStoreState.snapshots.playlist).toBe(
      playlistFixtureSnapshot,
    );
    expect(fixtureChannelStoreState.snapshots.weather).toBe(
      weatherFixtureSnapshot,
    );
    expect(fixtureChannelStoreState.snapshots.feed).toBe(feedFixtureSnapshot);
    expect(fixtureChannelStoreState.gens).toEqual({
      now_playing: 0,
      weather: 0,
      feed: 0,
      photo: 0,
      playlist: 0,
    });
  });
});

describe("applyEnvelope", () => {
  it("replaces a channel's snapshot and bumps its generation", () => {
    const nextPlaylist = { ...playlistFixtureSnapshot, playlists: [] };
    const next = applyEnvelope(
      fixtureChannelStoreState,
      envelope({ channel: "playlist", gen: 1, payload: nextPlaylist }),
    );

    expect(next.snapshots.playlist).toBe(nextPlaylist);
    expect(next.gens.playlist).toBe(1);
    // Other channels are untouched.
    expect(next.snapshots.weather).toBe(weatherFixtureSnapshot);
    expect(next.gens.weather).toBe(0);
  });

  it("rejects a stale generation (<= current) and returns the same state", () => {
    const bumped = applyEnvelope(
      fixtureChannelStoreState,
      envelope({ channel: "weather", gen: 5, payload: weatherFixtureSnapshot }),
    );

    const staleEqual = applyEnvelope(
      bumped,
      envelope({ channel: "weather", gen: 5, payload: { stale: "ignored" } }),
    );
    const staleLower = applyEnvelope(
      bumped,
      envelope({ channel: "weather", gen: 3, payload: { stale: "ignored" } }),
    );

    expect(staleEqual).toBe(bumped);
    expect(staleLower).toBe(bumped);
    expect(staleEqual.snapshots.weather).toBe(weatherFixtureSnapshot);
  });

  it("ignores an unmanaged channel and returns the same state", () => {
    const state: ChannelStoreState = fixtureChannelStoreState;

    const afterSystem = applyEnvelope(
      state,
      envelope({ channel: "system", gen: 99, payload: { ok: true } }),
    );
    const afterEtymology = applyEnvelope(
      state,
      envelope({ channel: "etymology", gen: 99, payload: { word: "x" } }),
    );
    const afterBogus = applyEnvelope(
      state,
      envelope({
        // Simulates a wire message outside the ChannelV1 union.
        channel: "not-a-real-channel" as EnvelopeV1["channel"],
        gen: 99,
        payload: {},
      }),
    );

    expect(afterSystem).toBe(state);
    expect(afterEtymology).toBe(state);
    expect(afterBogus).toBe(state);
  });
});
