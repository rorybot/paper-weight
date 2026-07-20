import { describe, expect, it } from "vitest";

import {
  etymologyFixtureSnapshot,
  initialEtymologyUiState,
  ladderOf,
  reduceEtymologyUi,
  uiDepth,
  viewMode,
  type EtymologyUiCommand,
  type EtymologyUiState,
} from "../screens/etymology";
import {
  KONAMI_SEQUENCE,
  initialShellState,
  type ScreenId,
  type ShellCommand,
  type ShellInput,
  type ShellState,
  type ShellTransition,
} from "./model";
import { routeShellInput } from "./router";

const route = (state: ShellState, input: ShellInput): ShellTransition =>
  routeShellInput(state, input);

const stateAfter = (state: ShellState, input: ShellInput): ShellState =>
  route(state, input).state;

const commandsAfter = (
  state: ShellState,
  input: ShellInput,
): readonly ShellCommand[] => route(state, input).commands;

const layered = (
  screen: ScreenId,
  patch: Partial<ShellState> = {},
): ShellState => ({
  screen,
  history: patch.history ?? [],
  overlay: patch.overlay ?? null,
  konamiIndex: patch.konamiIndex ?? 0,
});

describe("shell navigation — presets / hold / back / konami", () => {
  it.each([
    [1, "now-playing"],
    [2, "weather"],
    [3, "feed"],
    [4, "etymology"],
  ] as const)(
    "preset %s hard-switches to %s (clears overlay + history)",
    (preset, screen) => {
      const state = layered("feed", {
        history: ["home"],
        overlay: "feed-detail",
        konamiIndex: 3,
      });

      expect(
        stateAfter(state, {
          type: "preset",
          preset,
        }),
      ).toEqual(initialShellState(screen));
    },
  );

  it("presets are inactive in settings", () => {
    const settings = initialShellState("settings");
    const next = route(settings, { type: "preset", preset: 1 });
    expect(next.state).toBe(settings);
    expect(next.commands).toEqual([]);
  });

  it.each<ScreenId>([
    "home",
    "now-playing",
    "weather",
    "playlist",
    "feed",
    "photo",
    "etymology",
    "settings",
  ])("hold returns home from %s", (screen) => {
    const state = layered(screen, {
      history: ["feed"],
      overlay: screen === "now-playing" ? "lyrics" : null,
      konamiIndex: 4,
    });

    expect(stateAfter(state, { type: "hold" })).toEqual(initialShellState());
  });

  it("back dismisses overlay before history (feed collapse)", () => {
    const withOverlay = layered("feed", {
      history: ["home"],
      overlay: "feed-detail",
    });

    const withoutOverlay = stateAfter(withOverlay, { type: "back" });
    expect(withoutOverlay).toEqual({
      ...withOverlay,
      overlay: null,
      konamiIndex: 0,
    });

    expect(stateAfter(withoutOverlay, { type: "back" })).toEqual(
      initialShellState("home"),
    );
  });

  it("back is a no-op on top-level now-playing (interaction map —)", () => {
    const nowPlaying = initialShellState("now-playing");
    const next = route(nowPlaying, { type: "back" });
    expect(next.state).toBe(nowPlaying);
    expect(next.commands).toEqual([]);
  });

  it("back exits settings to previous screen", () => {
    const settings = layered("settings", { history: ["weather"] });
    expect(stateAfter(settings, { type: "back" })).toEqual(
      layered("weather"),
    );
  });

  it("back from settings with empty history goes home", () => {
    expect(stateAfter(initialShellState("settings"), { type: "back" })).toEqual(
      initialShellState("home"),
    );
  });

  it("completed konami opens settings and pushes history", () => {
    let state = initialShellState("now-playing");
    for (const key of KONAMI_SEQUENCE) {
      state = stateAfter(state, { type: "konami-key", key });
    }

    expect(state).toEqual({
      screen: "settings",
      history: ["now-playing"],
      overlay: null,
      konamiIndex: 0,
    });
  });

  it("konami progress survives wheel-turn (volume does not wipe sequence)", () => {
    let state = initialShellState("now-playing");
    state = stateAfter(state, { type: "konami-key", key: "up" });
    state = stateAfter(state, { type: "konami-key", key: "up" });
    expect(state.konamiIndex).toBe(2);

    const afterWheel = route(state, { type: "wheel-turn", delta: 1 });
    expect(afterWheel.state.konamiIndex).toBe(2);
    expect(afterWheel.commands).toEqual([{ type: "adjust-volume", delta: 1 }]);
  });

  it("wrong konami key resets or restarts sequence", () => {
    let state = initialShellState("feed");
    state = stateAfter(state, { type: "konami-key", key: "up" });
    state = stateAfter(state, { type: "konami-key", key: "left" });
    expect(state.konamiIndex).toBe(0);

    state = stateAfter(state, { type: "konami-key", key: "up" });
    expect(state.konamiIndex).toBe(1);
  });
});

describe("interaction map — wheel / press per screen", () => {
  it("Now Playing: wheel = volume, press = toggle lyrics", () => {
    const base = initialShellState("now-playing");

    expect(commandsAfter(base, { type: "wheel-turn", delta: 3 })).toEqual([
      { type: "adjust-volume", delta: 3 },
    ]);
    expect(commandsAfter(base, { type: "wheel-turn", delta: -2 })).toEqual([
      { type: "adjust-volume", delta: -2 },
    ]);

    const open = stateAfter(base, { type: "wheel-press" });
    expect(open.overlay).toBe("lyrics");
    expect(stateAfter(open, { type: "wheel-press" }).overlay).toBeNull();
  });

  it("Weather: wheel = toggle range, press = —", () => {
    const base = initialShellState("weather");
    expect(commandsAfter(base, { type: "wheel-turn", delta: 1 })).toEqual([
      { type: "toggle-weather-range" },
    ]);
    expect(route(base, { type: "wheel-press" }).commands).toEqual([]);
    expect(stateAfter(base, { type: "wheel-press" })).toBe(base);
  });

  it("Playlist: wheel = move selection, press = play selected", () => {
    const base = initialShellState("playlist");
    expect(commandsAfter(base, { type: "wheel-turn", delta: -1 })).toEqual([
      { type: "move-playlist-selection", delta: -1 },
    ]);
    expect(commandsAfter(base, { type: "wheel-press" })).toEqual([
      { type: "play-selected-playlist" },
    ]);
  });

  it("Feed: wheel = scroll, press = enlarge (overlay), back = collapse", () => {
    const base = initialShellState("feed");
    expect(commandsAfter(base, { type: "wheel-turn", delta: 1 })).toEqual([
      { type: "scroll-feed", delta: 1 },
    ]);

    const enlarged = stateAfter(base, { type: "wheel-press" });
    expect(enlarged.overlay).toBe("feed-detail");
    expect(stateAfter(enlarged, { type: "back" }).overlay).toBeNull();
  });

  it("Photo: wheel = skip, press = keep on show", () => {
    const base = initialShellState("photo");
    expect(commandsAfter(base, { type: "wheel-turn", delta: 1 })).toEqual([
      { type: "skip-photo", delta: 1 },
    ]);
    expect(commandsAfter(base, { type: "wheel-press" })).toEqual([
      { type: "keep-photo-on-show" },
    ]);
  });

  it("Settings: wheel = move field, press = edit, presets inactive", () => {
    const base = layered("settings", { history: ["home"] });
    expect(commandsAfter(base, { type: "wheel-turn", delta: 1 })).toEqual([
      { type: "move-settings-field", delta: 1 },
    ]);
    expect(commandsAfter(base, { type: "wheel-press" })).toEqual([
      { type: "edit-settings-field" },
    ]);
    expect(stateAfter(base, { type: "preset", preset: 2 })).toEqual(base);
  });

  it("zero wheel delta is a no-op", () => {
    const base = initialShellState("now-playing");
    expect(route(base, { type: "wheel-turn", delta: 0 }).commands).toEqual([]);
  });

  it("Etymology: wheel = scroll, press = dig, back = surface (E3 #135)", () => {
    const base = initialShellState("etymology");

    expect(commandsAfter(base, { type: "wheel-turn", delta: 1 })).toEqual([
      { type: "scroll-etymology", delta: 1 },
    ]);
    expect(commandsAfter(base, { type: "wheel-press" })).toEqual([
      { type: "dig-etymology" },
    ]);
    expect(commandsAfter(base, { type: "back" })).toEqual([
      { type: "back-etymology" },
    ]);

    // Shell stays put — the screen's state machine owns the drill depth.
    expect(stateAfter(base, { type: "wheel-press" })).toBe(base);
    expect(stateAfter(base, { type: "back" })).toBe(base);
  });

  it("Etymology: konami progress survives wheel and press intents", () => {
    let state = initialShellState("etymology");
    state = stateAfter(state, { type: "konami-key", key: "up" });
    state = stateAfter(state, { type: "konami-key", key: "up" });
    expect(state.konamiIndex).toBe(2);

    expect(stateAfter(state, { type: "wheel-turn", delta: -1 }).konamiIndex).toBe(2);
    expect(stateAfter(state, { type: "wheel-press" }).konamiIndex).toBe(2);
    expect(stateAfter(state, { type: "back" }).konamiIndex).toBe(2);
  });
});

describe("etymology drill-down — router commands drive the E2 machine (E3 #135)", () => {
  const snapshot = etymologyFixtureSnapshot;
  const ladder = ladderOf(snapshot.trace);

  const isEtymologyCommand = (
    command: ShellCommand,
  ): command is EtymologyUiCommand =>
    command.type === "scroll-etymology" ||
    command.type === "dig-etymology" ||
    command.type === "back-etymology";

  /** ShellApp wiring in miniature: route the input, reduce emitted commands. */
  const drive = (
    shell: ShellState,
    ui: EtymologyUiState,
    input: ShellInput,
  ): { shell: ShellState; ui: EtymologyUiState } => {
    const transition = route(shell, input);
    let nextUi = ui;
    for (const command of transition.commands) {
      if (isEtymologyCommand(command)) {
        nextUi = reduceEtymologyUi(nextUi, command, ladder);
      }
    }
    return { shell: transition.state, ui: nextUi };
  };

  it("wheel + press walk down through ladder → stage → root, back walks up", () => {
    let step = {
      shell: initialShellState("etymology"),
      ui: initialEtymologyUiState(snapshot),
    };
    expect(viewMode(step.ui, ladder)).toBe("ladder");

    // Press digs into the selected stage (2a → 2b).
    step = drive(step.shell, step.ui, { type: "wheel-press" });
    expect(viewMode(step.ui, ladder)).toBe("stage");
    expect(uiDepth(step.ui)).toBe(1);

    // Keep digging along the FROM spine until the terminal root (2c).
    step = drive(step.shell, step.ui, { type: "wheel-press" });
    step = drive(step.shell, step.ui, { type: "wheel-press" });
    step = drive(step.shell, step.ui, { type: "wheel-press" });
    expect(viewMode(step.ui, ladder)).toBe("root");
    // First dig enters the selected stage itself, then one per FROM hop.
    expect(uiDepth(step.ui)).toBe(ladder.length);

    // Nothing deeper at bedrock.
    const atRoot = step.ui;
    step = drive(step.shell, step.ui, { type: "wheel-press" });
    expect(step.ui).toBe(atRoot);

    // Back surfaces one depth at a time, all the way to the ladder.
    while (uiDepth(step.ui) > 0) {
      const before = uiDepth(step.ui);
      step = drive(step.shell, step.ui, { type: "back" });
      expect(uiDepth(step.ui)).toBe(before - 1);
    }
    expect(viewMode(step.ui, ladder)).toBe("ladder");

    // Back at depth 0: screen machine no-ops, shell stays on etymology.
    const surfaced = step.ui;
    step = drive(step.shell, step.ui, { type: "back" });
    expect(step.ui).toBe(surfaced);
    expect(step.shell.screen).toBe("etymology");
  });

  it("wheel selects the root stage on the ladder; one press reveals 2c", () => {
    let step = {
      shell: initialShellState("etymology"),
      ui: initialEtymologyUiState(snapshot),
    };

    for (let i = 0; i < ladder.length - 1; i += 1) {
      step = drive(step.shell, step.ui, { type: "wheel-turn", delta: 1 });
    }
    expect(step.ui.cursor).toBe(ladder.length - 1);

    step = drive(step.shell, step.ui, { type: "wheel-press" });
    expect(viewMode(step.ui, ladder)).toBe("root");
    expect(uiDepth(step.ui)).toBe(1);
  });
});
