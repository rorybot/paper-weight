/**
 * Pure etymology drill-down state machine — ONE machine for mockups 2a/2b/2c.
 *
 * State is a cursor over the flattened trace ladder plus a dig `path`
 * (breadcrumb of ladder indices). View depth = path length; the terminal-root
 * reveal (2c) is the same machine with a root-flagged stage in focus.
 */

import type {
  EtymologyOriginV1,
  EtymologySnapshotV1,
} from "../../protocol/etymology";

export type EtymologyUiState = Readonly<{
  /** Depth-0 wheel selection: index into the trace ladder. */
  cursor: number;
  /** Ladder indices dug into, oldest press last; [] = depth 0. */
  path: readonly number[];
}>;

export type EtymologyUiCommand =
  | Readonly<{ type: "scroll-etymology"; delta: number }>
  | Readonly<{ type: "dig-etymology" }>
  | Readonly<{ type: "back-etymology" }>;

export type EtymologyViewMode = "ladder" | "stage" | "root";

/** Flatten the recursive `from` spine, newest → oldest (device-side ladder). */
export const ladderOf = (
  trace: EtymologyOriginV1,
): readonly EtymologyOriginV1[] => {
  const out: EtymologyOriginV1[] = [];
  let node: EtymologyOriginV1 | null = trace;
  while (node) {
    out.push(node);
    node = node.from;
  }
  return Object.freeze(out);
};

export const initialEtymologyUiState = (
  snapshot: EtymologySnapshotV1,
  cursor = 0,
): EtymologyUiState => {
  const max = Math.max(0, ladderOf(snapshot.trace).length - 1);
  return Object.freeze({ cursor: clamp(cursor, 0, max), path: Object.freeze([]) });
};

/** UI depth shown in the topbar counter ("depth 1/3"). */
export const uiDepth = (state: EtymologyUiState): number => state.path.length;

/** Ladder index currently in focus: last dug stage, else the wheel cursor. */
export const focusedIndex = (state: EtymologyUiState): number =>
  state.path.length > 0 ? state.path[state.path.length - 1] : state.cursor;

export const focusedStage = (
  state: EtymologyUiState,
  ladder: readonly EtymologyOriginV1[],
): EtymologyOriginV1 | null => ladder[focusedIndex(state)] ?? null;

/** 2a while undug; 2b for a dug non-root stage; 2c once a root is in focus. */
export const viewMode = (
  state: EtymologyUiState,
  ladder: readonly EtymologyOriginV1[],
): EtymologyViewMode => {
  if (state.path.length === 0) return "ladder";
  return focusedStage(state, ladder)?.root ? "root" : "stage";
};

export const reduceEtymologyUi = (
  state: EtymologyUiState,
  command: EtymologyUiCommand,
  ladder: readonly EtymologyOriginV1[],
): EtymologyUiState => {
  switch (command.type) {
    case "scroll-etymology": {
      // Wheel picks a stage on the depth-0 ladder only.
      if (state.path.length > 0) return state;
      if (command.delta === 0 || ladder.length === 0) return state;
      const next = clamp(state.cursor + command.delta, 0, ladder.length - 1);
      if (next === state.cursor) return state;
      return Object.freeze({ ...state, cursor: next });
    }
    case "dig-etymology": {
      if (ladder.length === 0) return state;
      if (state.path.length === 0) {
        return Object.freeze({
          ...state,
          path: Object.freeze([state.cursor]),
        });
      }
      const focus = focusedStage(state, ladder);
      // Terminal root: nothing deeper (2c footer).
      if (!focus || focus.root || focus.from === null) return state;
      return Object.freeze({
        ...state,
        path: Object.freeze([...state.path, focusedIndex(state) + 1]),
      });
    }
    case "back-etymology": {
      // No-op at depth 0 (back is "home", handled by the shell).
      if (state.path.length === 0) return state;
      return Object.freeze({
        ...state,
        path: Object.freeze(state.path.slice(0, -1)),
      });
    }
    default:
      return state;
  }
};

/** Breadcrumb forms: headword home crumb + each dug stage ("travel › travailler"). */
export const breadcrumb = (
  state: EtymologyUiState,
  snapshot: EtymologySnapshotV1,
  ladder: readonly EtymologyOriginV1[] = ladderOf(snapshot.trace),
): readonly string[] =>
  Object.freeze([
    snapshot.word.headword,
    ...state.path.map((i) => ladder[i]?.form ?? "?"),
  ]);

/** Topbar path: trail ("~/travel/") + highlighted current segment. */
export const topbarPath = (
  state: EtymologyUiState,
  snapshot: EtymologySnapshotV1,
  ladder: readonly EtymologyOriginV1[] = ladderOf(snapshot.trace),
): Readonly<{ trail: string; current: string }> => {
  const crumbs = breadcrumb(state, snapshot, ladder);
  const trail = `~/${crumbs.slice(0, -1).join("/")}${crumbs.length > 1 ? "/" : ""}`;
  return Object.freeze({ trail, current: crumbs[crumbs.length - 1] });
};

export const depthLabel = (
  state: EtymologyUiState,
  snapshot: EtymologySnapshotV1,
): string => `depth ${uiDepth(state)}/${snapshot.depth}`;

/** "trēs + pālus" for a compound root; null when not compound. */
export const componentsLine = (
  stage: EtymologyOriginV1,
): string | null =>
  stage.components.length > 0
    ? stage.components.map((c) => c.form).join(" + ")
    : null;

/** '"three" + "stake"' gloss line under the components. */
export const componentsGloss = (
  stage: EtymologyOriginV1,
): string | null =>
  stage.components.length > 0
    ? stage.components.map((c) => `"${c.gloss}"`).join(" + ")
    : null;

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
