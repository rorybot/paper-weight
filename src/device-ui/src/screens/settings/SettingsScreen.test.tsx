import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import {
  defaultSettingsValues,
  initialSettingsUiState,
  reduceSettingsUi,
} from "./model";
import { SettingsScreen } from "./SettingsScreen";

describe("SettingsScreen", () => {
  it("renders 800×480 BERG settings layout with all five fields", () => {
    const html = render(<SettingsScreen theme="berg" />);

    expect(html).toContain("st-screen");
    expect(html).toContain('data-theme="berg"');
    expect(html).toContain('data-screen="settings"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("hidden");
    expect(html).toContain("settings");
    expect(html).toContain("konami only");
    expect(html).toContain('data-field-count="5"');
    expect(html).toContain('data-field-id="wifi"');
    expect(html).toContain('data-field-id="brightness"');
    expect(html).toContain('data-field-id="feed_handles"');
    expect(html).toContain('data-field-id="photo_source"');
    expect(html).toContain('data-field-id="hold_threshold_ms"');
    expect(html).toContain("carthing-lan");
    expect(html).toContain("70%");
    expect(html).toContain("back exits");
    expect(html).toContain("press");
  });

  it("highlights selected field and edit mode from controlled ui", () => {
    let ui = initialSettingsUiState(defaultSettingsValues(), 1);
    ui = reduceSettingsUi(ui, { type: "edit-settings-field" });
    const html = render(<SettingsScreen ui={ui} />);

    expect(html).toContain('data-selected-index="1"');
    expect(html).toContain('data-editing="true"');
    expect(html).toContain("EDIT");
    expect(html).toContain("press confirm");
  });

  it("shows adjusted brightness after edit + wheel reduce", () => {
    let ui = initialSettingsUiState(defaultSettingsValues(), 1);
    ui = reduceSettingsUi(ui, { type: "edit-settings-field" });
    ui = reduceSettingsUi(ui, { type: "move-settings-field", delta: 2 });
    const html = render(<SettingsScreen ui={ui} />);
    expect(html).toContain("80%");
  });
});
