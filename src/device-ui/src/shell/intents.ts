import type { ChannelV1, IntentV1 } from "../protocol/envelope";
import type { ShellCommand } from "./model";

/** Device → host intent request; the dispatch edge attaches `v`/`ts`. */
export type ShellIntentRequest = Pick<IntentV1, "name" | "args">;

/** Protocol v1.1 outbound intents. Transport control (play/pause) does not exist. */
export const INTENT_NAMES: readonly IntentV1["name"][] = Object.freeze([
  "set_volume",
  "play_playlist",
  "refresh_channel",
]);

export const setVolumeRequest = (delta: number): ShellIntentRequest => ({
  name: "set_volume",
  args: { delta },
});

export const playPlaylistRequest = (id: string): ShellIntentRequest => ({
  name: "play_playlist",
  args: { id },
});

export const refreshChannelRequest = (
  channel: ChannelV1,
): ShellIntentRequest => ({
  name: "refresh_channel",
  args: { channel },
});

/**
 * Pure: one shell command → its host intent request, or null for
 * device-local commands. No `ShellCommand` maps to an intent today
 * (`play-selected-playlist` resolves at the screen edge via
 * `playPlaylistRequest`; wheel volume was dropped in P10) — this stays the
 * one seam future commands plug into.
 */
export const commandToIntentRequest = (
  _command: ShellCommand,
): ShellIntentRequest | null => null;

/** Pure: map just-emitted shell commands to host intent requests, in order. */
export const commandsToIntentRequests = (
  commands: readonly ShellCommand[],
): readonly ShellIntentRequest[] =>
  commands
    .map(commandToIntentRequest)
    .filter((request): request is ShellIntentRequest => request !== null);

/** Attach the frozen envelope fields at the dispatch edge. */
export const buildIntent = (
  request: ShellIntentRequest,
  ts: number,
): IntentV1 => ({
  v: 1,
  ts,
  type: "intent",
  ...request,
});

/** One outbound WS text frame per intent. */
export const encodeIntentFrame = (intent: IntentV1): string =>
  JSON.stringify(intent);
