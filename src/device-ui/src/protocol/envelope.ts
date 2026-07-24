/**
 * Frozen host↔device envelope v1.
 * Domain lanes own only `src/device-ui/src/protocol/<channel>.ts` payloads.
 * @see docs/architecture/host-device-protocol-v1.md
 */

export type ChannelV1 =
  | "now_playing"
  | "weather"
  | "photo"
  | "etymology"
  | "playlist"
  | "system";

export type EnvelopeV1<TPayload = unknown> = {
  readonly v: 1;
  readonly ts: number;
  readonly channel: ChannelV1;
  readonly gen: number;
  readonly payload: TPayload;
};

export type IntentV1 = {
  readonly v: 1;
  readonly ts: number;
  readonly type: "intent";
  readonly name: "set_volume" | "play_playlist" | "refresh_channel";
  readonly args?: Readonly<Record<string, unknown>>;
};
