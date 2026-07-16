import {
  KONAMI_SEQUENCE,
  PRESET_SCREENS,
  type KonamiKey,
  type OverlayId,
  type ScreenId,
  type ShellCommand,
  type ShellInput,
  type ShellState,
  type ShellTransition,
} from "./model";

const unchanged = (state: ShellState): ShellTransition => ({
  state,
  commands: [],
});

/** Hard switch: clear overlay, history, konami (presets / hold / navigate). */
const resetTo = (state: ShellState, screen: ScreenId): ShellTransition => ({
  state: {
    ...state,
    screen,
    history: [],
    overlay: null,
    konamiIndex: 0,
  },
  commands: [],
});

const toggleOverlay = (
  state: ShellState,
  overlay: OverlayId,
): ShellTransition => ({
  state: {
    ...state,
    overlay: state.overlay === overlay ? null : overlay,
  },
  commands: [],
});

/** Screen intents keep konami progress (wheel must not wipe the sequence). */
const emit = (state: ShellState, command: ShellCommand): ShellTransition => ({
  state,
  commands: [command],
});

const back = (state: ShellState): ShellTransition => {
  if (state.overlay !== null) {
    return {
      state: { ...state, overlay: null, konamiIndex: 0 },
      commands: [],
    };
  }

  // Settings exit (interaction map: back = exit).
  if (state.screen === "settings") {
    const previous = state.history.at(-1);
    if (previous === undefined) {
      return resetTo(state, "home");
    }
    return {
      state: {
        ...state,
        screen: previous,
        history: state.history.slice(0, -1),
        konamiIndex: 0,
      },
      commands: [],
    };
  }

  const previous = state.history.at(-1);
  if (previous === undefined) {
    // Top-level screens: back is a no-op (e.g. Now Playing "—").
    return unchanged(state);
  }

  return {
    state: {
      ...state,
      screen: previous,
      history: state.history.slice(0, -1),
      konamiIndex: 0,
    },
    commands: [],
  };
};

const nextKonamiIndex = (current: number, key: KonamiKey): number => {
  if (key === KONAMI_SEQUENCE[current]) {
    return current + 1;
  }
  return key === KONAMI_SEQUENCE[0] ? 1 : 0;
};

const acceptKonamiKey = (
  state: ShellState,
  key: KonamiKey,
): ShellTransition => {
  if (state.screen === "settings") {
    return unchanged(state);
  }

  const konamiIndex = nextKonamiIndex(state.konamiIndex, key);
  if (konamiIndex < KONAMI_SEQUENCE.length) {
    return { state: { ...state, konamiIndex }, commands: [] };
  }

  return {
    state: {
      ...state,
      screen: "settings",
      history: [...state.history, state.screen],
      overlay: null,
      konamiIndex: 0,
    },
    commands: [],
  };
};

/**
 * design spec §Interaction — wheel turn column.
 * home / etymology / unknown: no shell command.
 */
const turnWheel = (state: ShellState, delta: number): ShellTransition => {
  if (delta === 0) {
    return unchanged(state);
  }

  switch (state.screen) {
    case "now-playing":
      return emit(state, { type: "adjust-volume", delta });
    case "weather":
      return emit(state, { type: "toggle-weather-range" });
    case "playlist":
      return emit(state, { type: "move-playlist-selection", delta });
    case "feed":
      // Enlarge overlay: wheel still scrolls the list under it.
      return emit(state, { type: "scroll-feed", delta });
    case "photo":
      return emit(state, { type: "skip-photo", delta });
    case "settings":
      return emit(state, { type: "move-settings-field", delta });
    default:
      return unchanged(state);
  }
};

/** design spec §Interaction — wheel press column. */
const pressWheel = (state: ShellState): ShellTransition => {
  switch (state.screen) {
    case "now-playing":
      return toggleOverlay(state, "lyrics");
    case "playlist":
      return emit(state, { type: "play-selected-playlist" });
    case "feed":
      return toggleOverlay(state, "feed-detail");
    case "photo":
      return emit(state, { type: "keep-photo-on-show" });
    case "settings":
      return emit(state, { type: "edit-settings-field" });
    default:
      // Weather / home / etymology: press is "—".
      return unchanged(state);
  }
};

/**
 * Pure shell router. Owns all navigation / overlay / konami; screens stay
 * pure `state → view` and only receive ShellCommand intents.
 */
export const routeShellInput = (
  state: ShellState,
  input: ShellInput,
): ShellTransition => {
  switch (input.type) {
    case "preset":
      // Settings: presets inactive (interaction map "—").
      return state.screen === "settings"
        ? unchanged(state)
        : resetTo(state, PRESET_SCREENS[input.preset]);
    case "hold":
      return resetTo(state, "home");
    case "back":
      return back(state);
    case "navigate":
      return resetTo(state, input.screen);
    case "wheel-turn":
      return turnWheel(state, input.delta);
    case "wheel-press":
      return pressWheel(state);
    case "konami-key":
      return acceptKonamiKey(state, input.key);
  }
};
