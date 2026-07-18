/**
 * Stable E2 seam API for the W3-D ShellApp wire-up: screen component,
 * fixture snapshot, and the pure state machine + selectors.
 */
export { etymologyFixtureSnapshot } from "./fixture";
export { EtymologyScreen } from "./EtymologyScreen";
export type { EtymologyScreenProps } from "./EtymologyScreen";
export {
  breadcrumb,
  componentsGloss,
  componentsLine,
  depthLabel,
  focusedIndex,
  focusedStage,
  initialEtymologyUiState,
  ladderOf,
  reduceEtymologyUi,
  topbarPath,
  uiDepth,
  viewMode,
} from "./model";
export type {
  EtymologyUiCommand,
  EtymologyUiState,
  EtymologyViewMode,
} from "./model";
