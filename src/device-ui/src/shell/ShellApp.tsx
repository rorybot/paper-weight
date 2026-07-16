import { useEffect, useRef, useState } from "preact/hooks";

import { FeedSample } from "../sample/FeedSample";
import {
  WeatherScreen,
  weatherFixtureSnapshot,
  type WeatherRange,
} from "../screens/weather";
import { bridgePayloadToShellInput } from "./bridge";
import { mapDevKeyboardEvent } from "./devKeyboard";
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

const renderOverlay = (overlay: OverlayId) => (
  <div class="shell-overlay-chrome" data-overlay-panel={overlay}>
    <Placeholder
      label={overlay}
      detail={
        overlay === "lyrics"
          ? "Lyrics overlay (N3) — press again or Back to dismiss."
          : "Feed detail enlarge — Back collapses."
      }
    />
  </div>
);

export interface ShellAppProps {
  readonly bridgeUrl?: string | null;
  readonly initialScreen?: ScreenId;
  /** Test / debug: observe commands without host services. */
  readonly onCommands?: (commands: readonly ShellCommand[]) => void;
  /** Override weather snapshot (defaults to W2 fixture until host WS). */
  readonly weatherSnapshot?: typeof weatherFixtureSnapshot;
}

/**
 * Shell harness: pure router + ScreenShell + wired screens + optional P2 SSE.
 * Weather is wired: fixture snapshot + wheel toggles 5d ↔ 7d.
 */
export const ShellApp = ({
  bridgeUrl = DEFAULT_BRIDGE_URL,
  initialScreen = "home",
  onCommands,
  weatherSnapshot = weatherFixtureSnapshot,
}: ShellAppProps) => {
  const [state, setState] = useState<ShellState>(() =>
    initialShellState(initialScreen),
  );
  const stateRef = useRef(state);
  stateRef.current = state;

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
    if (screen === "feed") {
      return <FeedSample />;
    }

    if (screen === "weather") {
      return (
        <WeatherScreen
          snapshot={weatherSnapshot}
          range={weatherRange}
          theme="gruvbox"
        />
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
        renderOverlay={renderOverlay}
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
