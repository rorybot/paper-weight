import { describe, expect, it } from "vitest";

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
    [2, "playlist"],
    [3, "weather"],
    [4, "feed"],
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
});
