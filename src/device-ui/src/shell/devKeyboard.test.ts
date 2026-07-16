import { describe, expect, it } from "vitest";

import { mapDevKeyboardEvent } from "./devKeyboard";

describe("dev keyboard map", () => {
  it("maps presets, hold, back, press", () => {
    expect(mapDevKeyboardEvent({ key: "2", code: "Digit2" })).toEqual({
      inputs: [{ type: "preset", preset: 2 }],
    });
    expect(mapDevKeyboardEvent({ key: "3", code: "Digit3" })).toEqual({
      inputs: [{ type: "preset", preset: 3 }],
    });
    expect(mapDevKeyboardEvent({ key: "H", code: "KeyH" })).toEqual({
      inputs: [{ type: "hold" }],
    });
    expect(mapDevKeyboardEvent({ key: "Escape", code: "Escape" })).toEqual({
      inputs: [{ type: "back" }],
    });
    expect(mapDevKeyboardEvent({ key: "Enter", code: "Enter" })).toEqual({
      inputs: [{ type: "wheel-press" }],
    });
  });

  it("vertical arrows emit konami + wheel", () => {
    expect(mapDevKeyboardEvent({ key: "ArrowUp", code: "ArrowUp" })).toEqual({
      inputs: [
        { type: "konami-key", key: "up" },
        { type: "wheel-turn", delta: 1 },
      ],
    });
  });

  it("ignores key repeat", () => {
    expect(
      mapDevKeyboardEvent({ key: "1", code: "Digit1", repeat: true }),
    ).toBeNull();
  });
});
