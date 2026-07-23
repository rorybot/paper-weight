import { describe, expect, it } from "vitest";

import {
  buildIntent,
  commandsToIntentRequests,
  commandToIntentRequest,
  encodeIntentFrame,
  INTENT_NAMES,
  playPlaylistRequest,
  refreshChannelRequest,
  setVolumeRequest,
} from "./intents";

describe("intent requests", () => {
  it("exposes exactly the three allowed intent names (no play/pause)", () => {
    expect(INTENT_NAMES).toEqual([
      "set_volume",
      "play_playlist",
      "refresh_channel",
    ]);
  });

  it("builds set_volume / play_playlist / refresh_channel requests", () => {
    expect(setVolumeRequest(-2)).toEqual({
      name: "set_volume",
      args: { delta: -2 },
    });
    expect(playPlaylistRequest("pl-1")).toEqual({
      name: "play_playlist",
      args: { id: "pl-1" },
    });
    expect(refreshChannelRequest("weather")).toEqual({
      name: "refresh_channel",
      args: { channel: "weather" },
    });
  });
});

describe("commandToIntentRequest", () => {
  it("returns null for device-local commands (playlist id resolves at the screen edge)", () => {
    expect(
      commandToIntentRequest({ type: "play-selected-playlist" }),
    ).toBeNull();
    expect(commandToIntentRequest({ type: "toggle-weather-range" })).toBeNull();
    expect(
      commandToIntentRequest({ type: "keep-photo-on-show" }),
    ).toBeNull();
  });
});

describe("commandsToIntentRequests", () => {
  it("maps no commands to an empty list", () => {
    expect(
      commandsToIntentRequests([
        { type: "move-settings-field", delta: 1 },
        { type: "edit-settings-field" },
      ]),
    ).toEqual([]);
  });
});

describe("intent frames", () => {
  it("buildIntent attaches the frozen envelope fields", () => {
    expect(buildIntent(setVolumeRequest(1), 1721150000000)).toEqual({
      v: 1,
      ts: 1721150000000,
      type: "intent",
      name: "set_volume",
      args: { delta: 1 },
    });
  });

  it("encodeIntentFrame produces the protocol wire shape", () => {
    const frame = encodeIntentFrame(buildIntent(refreshChannelRequest("photo"), 42));
    expect(JSON.parse(frame)).toEqual({
      v: 1,
      ts: 42,
      type: "intent",
      name: "refresh_channel",
      args: { channel: "photo" },
    });
  });
});
