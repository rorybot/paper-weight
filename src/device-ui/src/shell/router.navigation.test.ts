import { describe, expect, it } from vitest;

import {
  PRESET_SCREENS,
  initialShellState,
  type ScreenId,
  type ShellInput,
  type ShellState,
} from ./model;
import { routeShellInput } from ./router;

const stateAfter = (state: ShellState, input: ShellInput): ShellState =>
  routeShellInput(state, input).state;

// Navigation contract coverage.
