import type { ComponentChildren } from "preact";
import { useEffect, useRef, useState } from "preact/hooks";

import type { IntentV1 } from "../protocol/envelope";
import type { NowPlayingSnapshotV1 } from "../protocol/now_playing";
import { FeedScreen } from "../screens/feed";
import { HomeScreen, homeFixtureGlance } from "../screens/home";
import { LyricsOverlay, NowPlayingScreen } from "../screens/now-playing";
import { PhotoScreen } from "../screens/photo";
import { PlaylistScreen } from "../screens/playlist";
import { SettingsScreen } from "../screens/settings";
import {
  WeatherScreen,
  weatherFixtureSnapshot,
  type WeatherRange,
} from "../screens/weather";
import { bridgePayloadToShellInput } from "./bridge";
import {
  fixtureChannelStoreState,
  type ChannelStoreState,
} from "./channelStore";
import { mapDevKeyboardEvent } from "./devKeyboard";
import { commandsToIntentRequests } from "./intents";
import {
  initialShellState,
  type OverlayId,
  type ScreenId,
  type ShellCommand,
  type ShellInput,
  type ShellState,
} from "./model";
import { routeShellInput } from "./router";
import { ScreenShell } from "./ScreenShell";

const DEFAULT_BRIDGE_URL = "http://127.0.0.1:9137/v1/events";

const applyInputs = (
  state: ShellState,
  inputs: readonly ShellInput[],
): { state: ShellState; commands: readonly ShellCommand[] } => {
  let next = state;
  const commands: ShellCommand[] = [];
  for (const input of inputs) {
    const transition = routeShellInput(next, input);
    next = transition.state;
    commands.push(...transition.commands);
  }
  return { state: next, commands };
};

/** Pure: apply each `toggle-weather-range` command to local range state. */
export const applyWeatherRangeToggles = (
  range: WeatherRange,
  commands: readonly ShellCommand[],
): WeatherRange => {
  let next = range;
  for (const command of commands) {
    if (command.type === "toggle-weather-range") {
      next = next === "5d" ? "7d" : "5d";
    }
  }
  return next;
};

// Canonical command → intent mapping lives in `./intents` (W3-D);
// re-exported here so existing importers keep working.
export { commandsToIntentRequests } from "./intents";
export type { ShellIntentRequest } from "./intents";

const isFeedCommand = (
  command: ShellCommand,
): command is Extract<ShellCommand, { type: "scroll-feed" }> =>
  command.type === "scroll-feed";

const isPlaylistCommand = (
  command: ShellCommand,
): command is Extract<
  ShellCommand,
  { type: "move-playlist-selection" | "play-selected-playlist" }
> =>
  command.type === "move-playlist-selection" ||
  command.type === "play-selected-playlist";

const isPhotoCommand = (
  command: ShellCommand,
): command is Extract<
  ShellCommand,
  { type: "skip-photo" | "keep-photo-on-show" }
> => command.type === "skip-photo" || command.type === "keep-photo-on-show";

const isSettingsCommand = (
  command: ShellCommand,
): command is Extract<
  ShellCommand,
  { type: "move-settings-field" | "edit-settings-field" }
> =>
  command.type === "move-settings-field" ||
  command.type === "edit-settings-field";

/**
 * Pure: `lyrics` renders the real N3 overlay from the now-playing snapshot;
 * `feed-detail` has no separate chrome — `FeedScreen` reflects `enlarged`
 * itself, and `ScreenShell` already supplies the dim backdrop layer.
 */
export const renderShellOverlay = (
  overlay: OverlayId,
  nowPlayingSnapshot: NowPlayingSnapshotV1,
): ComponentChildren =>
  overlay === "lyrics" ? (
    <LyricsOverlay snapshot={nowPlayingSnapshot} />
  ) : null;

const Placeholder = ({
  label,
  detail,
}: {
  readonly label: string;
  readonly detail: string;
}) => (
  <div class="shell-placeholder" data-placeholder={label}>
    <p class="shell-placeholder__label">{label}</p>
    <p class="shell-placeholder__detail">{detail}</p>
  </div>
);

export interface ShellAppProps {
  readonly bridgeUrl?: string | null;
  /** W3-D gateway seam: live channel-store state; omit → static fixtures. */
  readonly channelState?: ChannelStoreState;
  readonly initialScreen?: ScreenId;
  /** Test / debug: observe commands without host services. */
  readonly onCommands?: (commands: readonly ShellCommand[]) => void;
  /** Device → host intents (`set_volume`, `play_playlist`). main.tsx wires the W3-D gateway here when `?gateway=` is present. */
  readonly onIntent?: (intent: IntentV1) => void;
  /** Override weather snapshot (defaults to the channel store's fixture). */
  readonly weatherSnapshot?: typeof weatherFixtureSnapshot;
}

/**
 * Shell harness: pure router + ScreenShell + wired screens + optional P2 SSE.
 * Screens render from `channelState` (fixture-seeded; the W3-D gateway feeds
 * live envelopes via main.tsx); Settings has no host channel.
 */
export const ShellApp = ({
  bridgeUrl = DEFAULT_BRIDGE_URL,
  channelState,
  initialScreen = "home",
  onCommands,
  onIntent,
  weatherSnapshot,
}: ShellAppProps) => {
  const [state, setState] = useState<ShellState>(() =>
    initialShellState(initialScreen),
  );
  const stateRef = useRef(state);
  stateRef.current = state;

  const channelStore = channelState ?? fixtureChannelStoreState;
  const resolvedWeatherSnapshot = weatherSnapshot ?? channelStore.snapshots.weather;

  const [lastCommands, setLastCommands] = useState<readonly ShellCommand[]>(
    [],
  );
  const [weatherRange, setWeatherRange] = useState<WeatherRange>("5d");
  const weatherRangeRef = useRef(weatherRange);
  weatherRangeRef.current = weatherRange;

  const dispatch = (inputs: readonly ShellInput[]) => {
    if (inputs.length === 0) {
      return;
    }

    const result = applyInputs(stateRef.current, inputs);
    stateRef.current = result.state;
    setState(result.state);
    setLastCommands(result.commands);
    onCommands?.(result.commands);

    for (const request of commandsToIntentRequests(result.commands)) {
      onIntent?.({ v: 1, ts: Date.now(), type: "intent", ...request });
    }

    const nextRange = applyWeatherRangeToggles(
      weatherRangeRef.current,
      result.commands,
    );
    if (nextRange !== weatherRangeRef.current) {
      weatherRangeRef.current = nextRange;
      setWeatherRange(nextRange);
    }
  };

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const mapped = mapDevKeyboardEvent(event);
      if (mapped === null) {
        return;
      }
      event.preventDefault();
      dispatch(mapped.inputs);
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onCommands]);

  useEffect(() => {
    if (bridgeUrl === null || typeof EventSource === "undefined") {
      return;
    }

    let source: EventSource;
    try {
      source = new EventSource(bridgeUrl);
    } catch {
      return;
    }

    source.onmessage = (message) => {
      const input = bridgePayloadToShellInput(message.data);
      if (input !== null) {
        dispatch([input]);
      }
    };

    return () => source.close();
  }, [bridgeUrl, onCommands]);

  const renderScreen = (screen: ScreenId) => {
    if (screen === "home") {
      return <HomeScreen glance={homeFixtureGlance} theme="gruvbox" />;
    }

    if (screen === "now-playing") {
      return <NowPlayingScreen snapshot={channelStore.snapshots.now_playing} />;
    }

    if (screen === "weather") {
      return (
        <WeatherScreen
          snapshot={resolvedWeatherSnapshot}
          range={weatherRange}
          theme="gruvbox"
        />
      );
    }

    if (screen === "playlist") {
      return (
        <PlaylistScreen
          snapshot={channelStore.snapshots.playlist}
          command={lastCommands.find(isPlaylistCommand) ?? null}
          onPlaySelected={(_item, args) =>
            onIntent?.({
              v: 1,
              ts: Date.now(),
              type: "intent",
              name: "play_playlist",
              args,
            })
          }
        />
      );
    }

    if (screen === "feed") {
      return (
        <FeedScreen
          snapshot={channelStore.snapshots.feed}
          command={lastCommands.find(isFeedCommand) ?? null}
          enlarged={state.overlay === "feed-detail"}
        />
      );
    }

    if (screen === "photo") {
      return (
        <PhotoScreen
          snapshot={channelStore.snapshots.photo}
          command={lastCommands.find(isPhotoCommand) ?? null}
        />
      );
    }

    if (screen === "settings") {
      return (
        <SettingsScreen command={lastCommands.find(isSettingsCommand) ?? null} />
      );
    }

    return (
      <Placeholder
        label={screen}
        detail="Screen UI ships on its feature card; shell owns navigation only."
      />
    );
  };

  return (
    <div class="shell-root" data-shell-root data-weather-range={weatherRange}>
      <ScreenShell
        state={state}
        renderScreen={renderScreen}
        renderOverlay={(overlay) =>
          renderShellOverlay(overlay, channelStore.snapshots.now_playing)
        }
      />
      <footer class="shell-hud" data-shell-hud>
        <span>
          {state.screen}
          {state.overlay ? ` · overlay:${state.overlay}` : ""}
          {state.screen === "weather" ? ` · range:${weatherRange}` : ""}
        </span>
        <span class="shell-hud__hint">
          1–4 presets · H hold · Esc back · ↑↓ wheel · Enter press · konami
          arrows+B+A
        </span>
        {lastCommands.length > 0 ? (
          <span class="shell-hud__cmd">
            {lastCommands.map((c) => c.type).join(", ")}
          </span>
        ) : null}
      </footer>
    </div>
  );
};
