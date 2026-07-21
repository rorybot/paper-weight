import type { Preset, ShellInput } from "./model";

/**
 * P2 input-bridge SSE JSON v1 (`src/input-bridge` event contract).
 * Endpoint: `http://127.0.0.1:9137/v1/events`
 */
export type BridgeEventV1 =
  | { readonly v: 1; readonly type: "wheel"; readonly ticks: number }
  | { readonly v: 1; readonly type: "wheel_press" }
  | { readonly v: 1; readonly type: "wheel_long_press" }
  | { readonly v: 1; readonly type: "preset"; readonly number: Preset }
  | { readonly v: 1; readonly type: "home" }
  | { readonly v: 1; readonly type: "back" };

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const isPresetNumber = (n: number): n is Preset =>
  n === 1 || n === 2 || n === 3 || n === 4;

/**
 * Parse one SSE `data:` payload. Unknown / wrong-version messages → null.
 */
export const parseBridgeEvent = (raw: string): BridgeEventV1 | null => {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    return null;
  }

  if (!isRecord(parsed) || parsed.v !== 1 || typeof parsed.type !== "string") {
    return null;
  }

  switch (parsed.type) {
    case "wheel":
      return typeof parsed.ticks === "number" && Number.isFinite(parsed.ticks)
        ? { v: 1, type: "wheel", ticks: parsed.ticks }
        : null;
    case "wheel_press":
      return { v: 1, type: "wheel_press" };
    case "wheel_long_press":
      return { v: 1, type: "wheel_long_press" };
    case "preset":
      return typeof parsed.number === "number" && isPresetNumber(parsed.number)
        ? { v: 1, type: "preset", number: parsed.number }
        : null;
    case "home":
      return { v: 1, type: "home" };
    case "back":
      return { v: 1, type: "back" };
    default:
      return null;
  }
};

/** Map bridge event → shell input (home hold → hold). */
export const bridgeEventToShellInput = (
  event: BridgeEventV1,
): ShellInput | null => {
  switch (event.type) {
    case "wheel":
      return event.ticks === 0
        ? null
        : { type: "wheel-turn", delta: event.ticks };
    case "wheel_press":
      return { type: "wheel-press" };
    case "wheel_long_press":
      return { type: "wheel-long-press" };
    case "preset":
      return { type: "preset", preset: event.number };
    case "home":
      return { type: "hold" };
    case "back":
      return { type: "back" };
  }
};

export const bridgePayloadToShellInput = (raw: string): ShellInput | null => {
  const event = parseBridgeEvent(raw);
  return event === null ? null : bridgeEventToShellInput(event);
};
