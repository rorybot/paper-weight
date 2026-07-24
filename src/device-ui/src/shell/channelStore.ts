import type { ChannelV1, EnvelopeV1 } from "../protocol/envelope";
import type { NowPlayingSnapshotV1 } from "../protocol/now_playing";
import type { PhotoSnapshotV1 } from "../protocol/photo";
import type { PlaylistSnapshotV1 } from "../protocol/playlist";
import type { WeatherSnapshotV1 } from "../protocol/weather";
import { nowPlayingFixtureSnapshot } from "../screens/now-playing";
import { photoFixtureSnapshot } from "../screens/photo";
import { playlistFixtureSnapshot } from "../screens/playlist";
import { weatherFixtureSnapshot } from "../screens/weather";

/**
 * Channels a real screen renders from. `etymology`/`system` are valid
 * `ChannelV1` members but have no wired screen yet — envelopes for them
 * are ignored here (etymology stays a shell placeholder until E2).
 */
export type ManagedChannel = "now_playing" | "weather" | "photo" | "playlist";

export type ChannelSnapshots = {
  readonly now_playing: NowPlayingSnapshotV1;
  readonly weather: WeatherSnapshotV1;
  readonly photo: PhotoSnapshotV1;
  readonly playlist: PlaylistSnapshotV1;
};

export type ChannelStoreState = {
  readonly snapshots: ChannelSnapshots;
  readonly gens: Readonly<Record<ManagedChannel, number>>;
};

/** Managed channels in wire order — the W3-D gateway's refresh-on-open list. */
export const MANAGED_CHANNEL_LIST: readonly ManagedChannel[] = Object.freeze([
  "now_playing",
  "weather",
  "photo",
  "playlist",
]);

const MANAGED_CHANNELS: ReadonlySet<ChannelV1> = new Set<ManagedChannel>(
  MANAGED_CHANNEL_LIST,
);

const isManagedChannel = (channel: ChannelV1): channel is ManagedChannel =>
  MANAGED_CHANNELS.has(channel);

/** Seed store: every managed channel starts at gen 0 with its fixture. */
export const fixtureChannelStoreState: ChannelStoreState = Object.freeze({
  snapshots: Object.freeze({
    now_playing: nowPlayingFixtureSnapshot,
    weather: weatherFixtureSnapshot,
    photo: photoFixtureSnapshot,
    playlist: playlistFixtureSnapshot,
  }),
  gens: Object.freeze({
    now_playing: 0,
    weather: 0,
    photo: 0,
    playlist: 0,
  }),
});

/**
 * Pure envelope reducer. Unmanaged channels are ignored; a `gen` at or
 * below the channel's stored generation is rejected as stale/out-of-order
 * (protocol v1.1: "device replaces whole store for that channel" on bump).
 */
export const applyEnvelope = (
  state: ChannelStoreState,
  envelope: EnvelopeV1,
): ChannelStoreState => {
  const { channel, gen, payload } = envelope;

  if (!isManagedChannel(channel)) {
    return state;
  }
  if (gen <= state.gens[channel]) {
    return state;
  }

  return {
    snapshots: { ...state.snapshots, [channel]: payload } as ChannelSnapshots,
    gens: { ...state.gens, [channel]: gen },
  };
};
