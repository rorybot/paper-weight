import { describe, expect, it } from "vitest";

import {
  defaultSettingsValues,
  editHint,
  fieldValueLabel,
  initialSettingsUiState,
  reduceSettingsUi,
  selectedField,
  SETTINGS_FIELDS,
} from "./model";

describe("reduceSettingsUi", () => {
  it("wheel moves field selection when not editing", () => {
    let s = initialSettingsUiState();
    expect(s.selectedIndex).toBe(0);
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: 1 });
    expect(s.selectedIndex).toBe(1);
    expect(selectedField(s)?.id).toBe("brightness");
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: 99 });
    expect(s.selectedIndex).toBe(SETTINGS_FIELDS.length - 1);
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: -99 });
    expect(s.selectedIndex).toBe(0);
  });

  it("press toggles edit mode", () => {
    let s = initialSettingsUiState();
    s = reduceSettingsUi(s, { type: "edit-settings-field" });
    expect(s.editing).toBe(true);
    s = reduceSettingsUi(s, { type: "edit-settings-field" });
    expect(s.editing).toBe(false);
  });

  it("wheel adjusts brightness while editing", () => {
    let s = initialSettingsUiState(defaultSettingsValues(), 1);
    s = reduceSettingsUi(s, { type: "edit-settings-field" });
    const before = s.values.brightness;
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: 1 });
    expect(s.values.brightness).toBe(before + 5);
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: -1 });
    expect(s.values.brightness).toBe(before);
  });

  it("wheel cycles wifi options while editing", () => {
    let s = initialSettingsUiState(defaultSettingsValues(), 0);
    s = reduceSettingsUi(s, { type: "edit-settings-field" });
    const start = s.values.wifi;
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: 1 });
    expect(s.values.wifi).not.toBe(start);
  });

  it("clamps hold threshold", () => {
    let s = initialSettingsUiState(
      { ...defaultSettingsValues(), hold_threshold_ms: 200 },
      4,
    );
    s = reduceSettingsUi(s, { type: "edit-settings-field" });
    s = reduceSettingsUi(s, { type: "move-settings-field", delta: -1 });
    expect(s.values.hold_threshold_ms).toBe(200);
  });
});

describe("labels", () => {
  it("formats field values and edit hint", () => {
    const v = defaultSettingsValues();
    expect(fieldValueLabel(v, "brightness")).toBe("70%");
    expect(fieldValueLabel(v, "hold_threshold_ms")).toBe("600 ms");
    expect(editHint(false)).toContain("press edit");
    expect(editHint(true)).toContain("press confirm");
    expect(SETTINGS_FIELDS.map((f) => f.id)).toEqual([
      "wifi",
      "brightness",
      "feed_handles",
      "photo_source",
      "hold_threshold_ms",
    ]);
  });
});
