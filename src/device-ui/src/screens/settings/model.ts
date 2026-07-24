/**
 * Pure settings UI — shell emits move/edit; back exits (shell).
 * Fields are local device config (wave-3 may persist later).
 */

export type SettingsFieldId =
  | "wifi"
  | "brightness"
  | "photo_source"
  | "hold_threshold_ms";

export type SettingsValues = Readonly<{
  /** Display SSID or "off" / "connecting…" */
  wifi: string;
  /** 0–100 */
  brightness: number;
  /** Local library path / label */
  photo_source: string;
  /** Button-hold ms to home */
  hold_threshold_ms: number;
}>;

export type SettingsUiState = Readonly<{
  values: SettingsValues;
  /** Index into SETTINGS_FIELDS */
  selectedIndex: number;
  /** When true, wheel adjusts value; press commits. */
  editing: boolean;
}>;

/** Match shell `ShellCommand` names for wave-3 wire-up. */
export type SettingsUiCommand =
  | Readonly<{ type: "move-settings-field"; delta: number }>
  | Readonly<{ type: "edit-settings-field" }>;

export type SettingsFieldMeta = Readonly<{
  id: SettingsFieldId;
  label: string;
  hint: string;
  kind: "enum" | "number" | "text-cycle";
}>;

export const SETTINGS_FIELDS: readonly SettingsFieldMeta[] = Object.freeze([
  Object.freeze({
    id: "wifi" as const,
    label: "wifi",
    hint: "network join / off",
    kind: "enum" as const,
  }),
  Object.freeze({
    id: "brightness" as const,
    label: "brightness",
    hint: "panel 0–100",
    kind: "number" as const,
  }),
  Object.freeze({
    id: "photo_source" as const,
    label: "photo source",
    hint: "library folder",
    kind: "text-cycle" as const,
  }),
  Object.freeze({
    id: "hold_threshold_ms" as const,
    label: "hold → home",
    hint: "ms press duration",
    kind: "number" as const,
  }),
]);

const WIFI_OPTIONS = Object.freeze([
  "off",
  "carthing-lan",
  "home-mesh",
  "guest",
] as const);

const PHOTO_OPTIONS = Object.freeze([
  "local library",
  "/photos",
  "/media/reprints",
] as const);

const BRIGHTNESS_STEP = 5;
const HOLD_STEP_MS = 50;
const HOLD_MIN_MS = 200;
const HOLD_MAX_MS = 2000;

export const defaultSettingsValues = (): SettingsValues =>
  Object.freeze({
    wifi: "carthing-lan",
    brightness: 70,
    photo_source: PHOTO_OPTIONS[0]!,
    hold_threshold_ms: 600,
  });

export const initialSettingsUiState = (
  values: SettingsValues = defaultSettingsValues(),
  selectedIndex = 0,
): SettingsUiState =>
  Object.freeze({
    values: Object.freeze({ ...values }),
    selectedIndex: clamp(
      selectedIndex,
      0,
      Math.max(0, SETTINGS_FIELDS.length - 1),
    ),
    editing: false,
  });

export const reduceSettingsUi = (
  state: SettingsUiState,
  command: SettingsUiCommand,
): SettingsUiState => {
  switch (command.type) {
    case "move-settings-field": {
      if (command.delta === 0) return state;
      if (state.editing) {
        return Object.freeze({
          ...state,
          values: adjustSelectedValue(state.values, state.selectedIndex, command.delta),
        });
      }
      const next = clamp(
        state.selectedIndex + command.delta,
        0,
        SETTINGS_FIELDS.length - 1,
      );
      if (next === state.selectedIndex) return state;
      return Object.freeze({ ...state, selectedIndex: next });
    }
    case "edit-settings-field":
      return Object.freeze({ ...state, editing: !state.editing });
    default:
      return state;
  }
};

export const selectedField = (
  state: SettingsUiState,
): SettingsFieldMeta | null => SETTINGS_FIELDS[state.selectedIndex] ?? null;

export const fieldValueLabel = (
  values: SettingsValues,
  fieldId: SettingsFieldId,
): string => {
  switch (fieldId) {
    case "wifi":
      return values.wifi;
    case "brightness":
      return `${values.brightness}%`;
    case "photo_source":
      return values.photo_source;
    case "hold_threshold_ms":
      return `${values.hold_threshold_ms} ms`;
    default:
      return "";
  }
};

export const editHint = (editing: boolean): string =>
  editing ? "press confirm · wheel adjust" : "press edit · wheel move field";

const adjustSelectedValue = (
  values: SettingsValues,
  selectedIndex: number,
  delta: number,
): SettingsValues => {
  const field = SETTINGS_FIELDS[selectedIndex];
  if (!field) return values;
  // Wheel ticks: preserve magnitude (delta ±1, ±2, …).
  const steps = delta === 0 ? 0 : Math.trunc(delta);

  switch (field.id) {
    case "wifi":
      return Object.freeze({
        ...values,
        wifi: cycleOption(WIFI_OPTIONS, values.wifi, steps || Math.sign(delta)),
      });
    case "brightness":
      return Object.freeze({
        ...values,
        brightness: clamp(
          values.brightness + steps * BRIGHTNESS_STEP,
          0,
          100,
        ),
      });
    case "photo_source":
      return Object.freeze({
        ...values,
        photo_source: cycleOption(
          PHOTO_OPTIONS,
          values.photo_source,
          steps || Math.sign(delta),
        ),
      });
    case "hold_threshold_ms":
      return Object.freeze({
        ...values,
        hold_threshold_ms: clamp(
          values.hold_threshold_ms + steps * HOLD_STEP_MS,
          HOLD_MIN_MS,
          HOLD_MAX_MS,
        ),
      });
    default:
      return values;
  }
};

const cycleOption = (
  options: readonly string[],
  current: string,
  step: number,
): string => {
  const i = options.indexOf(current);
  const start = i < 0 ? 0 : i;
  const next = (start + step + options.length * 10) % options.length;
  return options[next]!;
};

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
