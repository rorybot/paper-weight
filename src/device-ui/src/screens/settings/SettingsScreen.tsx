import type { JSX } from "preact";
import { useEffect, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import {
  editHint,
  fieldValueLabel,
  initialSettingsUiState,
  reduceSettingsUi,
  SETTINGS_FIELDS,
  type SettingsUiCommand,
  type SettingsUiState,
  type SettingsValues,
} from "./model";
import "./settings.css";

export type SettingsScreenProps = Readonly<{
  /** BERG is the design direction for D2 (hidden config). */
  theme?: ThemeName;
  values?: SettingsValues;
  ui?: SettingsUiState;
  /**
   * Shell: `move-settings-field` / `edit-settings-field`.
   * Wave 3 wires from ShellApp; tests pass one-shot commands.
   */
  command?: SettingsUiCommand | null;
  onUiChange?: (state: SettingsUiState) => void;
}>;

export const SettingsScreen = ({
  theme = "berg",
  values,
  ui: controlledUi,
  command = null,
  onUiChange,
}: SettingsScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialSettingsUiState(values),
  );

  const state = controlledUi ?? internal;

  useEffect(() => {
    if (!command) return;
    setInternal((prev) => {
      const start = controlledUi ?? prev;
      const next = reduceSettingsUi(start, command);
      if (
        next.selectedIndex !== start.selectedIndex ||
        next.editing !== start.editing ||
        next.values !== start.values
      ) {
        onUiChange?.(next);
      }
      return next;
    });
  }, [command, controlledUi, onUiChange]);

  const mode = editHint(state.editing);

  return (
    <main
      class={`${themeClassName(theme)} st-screen`}
      data-theme={theme}
      data-screen="settings"
      data-editing={String(state.editing)}
      data-selected-index={String(state.selectedIndex)}
      data-field-count={String(SETTINGS_FIELDS.length)}
      style={{ width: "800px", height: "480px" }}
    >
      <header class="st-topbar">
        <span>[cthing]</span>
        <span class="st-topbar__badge">hidden</span>
        <span class="st-topbar__title">settings</span>
        <span class="st-topbar__note">konami only · not on 1–4</span>
      </header>

      <section class="st-main" aria-label="Settings fields">
        <article class="st-card" data-tone="paper">
          <p class="st-card__eyebrow">device config</p>
          <ul class="st-fields" role="listbox" aria-label="Settings">
            {SETTINGS_FIELDS.map((field, index) => {
              const selected = index === state.selectedIndex;
              const editing = selected && state.editing;
              return (
                <li
                  key={field.id}
                  class="st-field"
                  role="option"
                  aria-selected={selected}
                  data-field-id={field.id}
                  data-selected={String(selected)}
                  data-editing={String(editing)}
                >
                  <p class="st-field__label">{field.label}</p>
                  <p class="st-field__value">
                    {fieldValueLabel(state.values, field.id)}
                  </p>
                  <p class="st-field__meta">
                    {editing ? "EDIT" : selected ? "▶" : field.hint}
                  </p>
                </li>
              );
            })}
          </ul>
        </article>
      </section>

      <footer class="st-footer">
        <span data-hint="wheel">◉ wheel</span>
        <span data-hint="press">
          <strong>press</strong> {state.editing ? "confirm" : "edit"}
        </span>
        <span data-hint="back">back exits</span>
        <span class="st-footer__mode" data-mode={state.editing ? "edit" : "nav"}>
          {mode}
        </span>
      </footer>
    </main>
  );
};
