export const PRESET_SCREENS = {
  1: "now-playing",
  2: "weather",
  3: "playlist",
  4: "feed",
} as const;

/** Konami entry to Settings (hidden; not on presets 1–4). */
export const KONAMI_SEQUENCE = [
  "up",
  "up",
  "down",
  "down",
  "left",
  "right",
  "left",
  "right",
  "b",
  "a",
] as const;

export type Preset = keyof typeof PRESET_SCREENS;
export type ScreenId =
  | "home"
  | "now-playing"
  | "weather"
  | "playlist"
  | "feed"
  | "photo"
  | "etymology"
  | "settings";
export type OverlayId = "lyrics" | "feed-detail";
export type KonamiKey = (typeof KONAMI_SEQUENCE)[number];

export interface ShellState {
  readonly screen: ScreenId;
  readonly history: readonly ScreenId[];
  readonly overlay: OverlayId | null;
  readonly konamiIndex: number;
}

export type ShellInput =
  | { readonly type: "preset"; readonly preset: Preset }
  | { readonly type: "hold" }
  | { readonly type: "back" }
  | { readonly type: "navigate"; readonly screen: Exclude<ScreenId, "settings"> }
  | { readonly type: "wheel-turn"; readonly delta: number }
  | { readonly type: "wheel-press" }
  | { readonly type: "konami-key"; readonly key: KonamiKey };

/**
 * Side-effect intents for the active screen. Shell never mutates screen data —
 * pure screens reduce these later. Router owns *when* they fire.
 */
export type ShellCommand =
  | { readonly type: "adjust-volume"; readonly delta: number }
  | { readonly type: "toggle-weather-range" }
  | { readonly type: "move-playlist-selection"; readonly delta: number }
  | { readonly type: "play-selected-playlist" }
  | { readonly type: "scroll-feed"; readonly delta: number }
  | { readonly type: "skip-photo"; readonly delta: number }
  | { readonly type: "keep-photo-on-show" }
  | { readonly type: "move-settings-field"; readonly delta: number }
  | { readonly type: "edit-settings-field" };

export interface ShellTransition {
  readonly state: ShellState;
  readonly commands: readonly ShellCommand[];
}

export const initialShellState = (screen: ScreenId = "home"): ShellState => ({
  screen,
  history: [],
  overlay: null,
  konamiIndex: 0,
});
