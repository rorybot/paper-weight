import type { ComponentChildren } from preact;

import type { OverlayId, ScreenId, ShellState } from ./model;

interface ScreenShellProps {
  readonly state: ShellState;
  readonly renderScreen: (screen: ScreenId) => ComponentChildren;
  readonly renderOverlay: (overlay: OverlayId) => ComponentChildren;
}

export const ScreenShell = ({
  state,
  renderScreen,
  renderOverlay,
}: ScreenShellProps) => (
  <main data-screen={state.screen} data-shell=screen>
    <section data-shell-layer=screen>{renderScreen(state.screen)}</section>
    {state.overlay === null ? null : (
      <section data-overlay={state.overlay} data-shell-layer=overlay>
        {renderOverlay(state.overlay)}
      </section>
    )}
  </main>
);
