import { describe, expect, it } from "vitest";

import {
  bridgeEventToShellInput,
  bridgePayloadToShellInput,
  parseBridgeEvent,
} from "./bridge";

describe("P2 bridge → shell input", () => {
  it("parses wheel / press / preset / home / back", () => {
    expect(parseBridgeEvent('{"v":1,"type":"wheel","ticks":-2}')).toEqual({
      v: 1,
      type: "wheel",
      ticks: -2,
    });
    expect(parseBridgeEvent('{"v":1,"type":"wheel_press"}')).toEqual({
      v: 1,
      type: "wheel_press",
    });
    expect(parseBridgeEvent('{"v":1,"type":"preset","number":3}')).toEqual({
      v: 1,
      type: "preset",
      number: 3,
    });
    expect(parseBridgeEvent('{"v":1,"type":"home"}')).toEqual({
      v: 1,
      type: "home",
    });
    expect(parseBridgeEvent('{"v":1,"type":"back"}')).toEqual({
      v: 1,
      type: "back",
    });
  });

  it("rejects bad payloads", () => {
    expect(parseBridgeEvent("not-json")).toBeNull();
    expect(parseBridgeEvent('{"v":2,"type":"back"}')).toBeNull();
    expect(parseBridgeEvent('{"v":1,"type":"preset","number":9}')).toBeNull();
    expect(parseBridgeEvent('{"v":1,"type":"wheel"}')).toBeNull();
  });

  it("maps home → hold and wheel ticks → wheel-turn", () => {
    expect(
      bridgeEventToShellInput({ v: 1, type: "home" }),
    ).toEqual({ type: "hold" });
    expect(
      bridgeEventToShellInput({ v: 1, type: "wheel", ticks: 4 }),
    ).toEqual({ type: "wheel-turn", delta: 4 });
    expect(
      bridgeEventToShellInput({ v: 1, type: "wheel", ticks: 0 }),
    ).toBeNull();
    expect(
      bridgePayloadToShellInput('{"v":1,"type":"preset","number":1}'),
    ).toEqual({ type: "preset", preset: 1 });
  });
});
