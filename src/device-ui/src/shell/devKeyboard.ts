import type { KonamiKey, Preset, ShellInput } from "./model";

/**
 * Host/dev keyboard map (workflow-v1):
 * - wheel = ArrowUp / ArrowDown (delta ±1)
 * - left/right = konami only (no volume)
 * - press = Enter
 * - presets = 1–4
 * - hold = H
 * - back = Escape
 * - konami: arrows + KeyB / KeyA
 *
 * Vertical arrows emit *both* konami-key and wheel-turn so the secret sequence
 * can complete while the router still delivers volume/scroll intents. Wheel
 * turns do not reset konamiIndex (see router).
 */
export type DevKeyboardResult =
  | { readonly inputs: readonly ShellInput[] }
  | null;

const presetFromDigit = (key: string): Preset | null => {
  if (key === "1" || key === "2" || key === "3" || key === "4") {
    return Number(key) as Preset;
  }
  return null;
};

const konamiFromCode = (code: string): KonamiKey | null => {
  switch (code) {
    case "ArrowUp":
      return "up";
    case "ArrowDown":
      return "down";
    case "ArrowLeft":
      return "left";
    case "ArrowRight":
      return "right";
    case "KeyB":
      return "b";
    case "KeyA":
      return "a";
    default:
      return null;
  }
};

export const mapDevKeyboardEvent = (event: {
  readonly key: string;
  readonly code: string;
  readonly repeat?: boolean;
}): DevKeyboardResult => {
  if (event.repeat) {
    return null;
  }

  const preset = presetFromDigit(event.key);
  if (preset !== null) {
    return { inputs: [{ type: "preset", preset }] };
  }

  if (event.key === "h" || event.key === "H") {
    return { inputs: [{ type: "hold" }] };
  }

  if (event.key === "Escape") {
    return { inputs: [{ type: "back" }] };
  }

  if (event.key === "Enter") {
    return { inputs: [{ type: "wheel-press" }] };
  }

  const konami = konamiFromCode(event.code);
  if (konami === null) {
    return null;
  }

  if (konami === "up") {
    return {
      inputs: [
        { type: "konami-key", key: "up" },
        { type: "wheel-turn", delta: 1 },
      ],
    };
  }

  if (konami === "down") {
    return {
      inputs: [
        { type: "konami-key", key: "down" },
        { type: "wheel-turn", delta: -1 },
      ],
    };
  }

  // left / right / b / a — konami only
  return { inputs: [{ type: "konami-key", key: konami }] };
};
