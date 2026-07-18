import { describe, expect, it } from "vitest";

import { etymologyFixtureSnapshot } from "./fixture";
import {
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
  type EtymologyUiState,
} from "./model";

const snap = etymologyFixtureSnapshot;
const ladder = ladderOf(snap.trace);

const scroll = (state: EtymologyUiState, delta: number) =>
  reduceEtymologyUi(state, { type: "scroll-etymology", delta }, ladder);
const dig = (state: EtymologyUiState) =>
  reduceEtymologyUi(state, { type: "dig-etymology" }, ladder);
const back = (state: EtymologyUiState) =>
  reduceEtymologyUi(state, { type: "back-etymology" }, ladder);

describe("ladderOf", () => {
  it("flattens the recursive spine newest → oldest", () => {
    expect(ladder.map((s) => s.form)).toEqual([
      "travel",
      "travailen",
      "travailler",
      "trepālium",
    ]);
    expect(ladder[3].root).toBe(true);
    expect(ladder[3].from).toBeNull();
  });
});

describe("wheel bounds (depth 0)", () => {
  it("clamps at the top of the trace ladder", () => {
    const state = initialEtymologyUiState(snap);
    expect(state.cursor).toBe(0);
    const same = scroll(state, -1);
    expect(same).toBe(state);
  });

  it("clamps at the bottom of the trace ladder", () => {
    let state = initialEtymologyUiState(snap, ladder.length - 1);
    expect(state.cursor).toBe(3);
    state = scroll(state, +5);
    expect(state.cursor).toBe(3);
  });

  it("moves one stage per detent and ignores zero deltas", () => {
    let state = initialEtymologyUiState(snap);
    state = scroll(state, +1);
    expect(state.cursor).toBe(1);
    state = scroll(state, +1);
    expect(state.cursor).toBe(2);
    expect(scroll(state, 0)).toBe(state);
  });

  it("clamps an out-of-range initial cursor", () => {
    expect(initialEtymologyUiState(snap, 99).cursor).toBe(3);
    expect(initialEtymologyUiState(snap, -4).cursor).toBe(0);
  });

  it("is a no-op once dug in (wheel picks stages only at depth 0)", () => {
    const dug = dig(scroll(initialEtymologyUiState(snap), +2));
    expect(scroll(dug, +1)).toBe(dug);
  });
});

describe("descend (press digs)", () => {
  it("depth 0 press digs into the highlighted stage", () => {
    let state = initialEtymologyUiState(snap);
    state = scroll(state, +2); // travailler
    state = dig(state);
    expect(uiDepth(state)).toBe(1);
    expect(viewMode(state, ladder)).toBe("stage");
    expect(focusedStage(state, ladder)?.form).toBe("travailler");
  });

  it("depth 1 press digs into the FROM stage", () => {
    let state = dig(scroll(initialEtymologyUiState(snap), +2));
    state = dig(state);
    expect(uiDepth(state)).toBe(2);
    expect(focusedStage(state, ladder)?.form).toBe("trepālium");
  });

  it("reaching the terminal root switches to the root reveal", () => {
    const state = dig(dig(scroll(initialEtymologyUiState(snap), +2)));
    expect(viewMode(state, ladder)).toBe("root");
    expect(focusedStage(state, ladder)?.root).toBe(true);
  });

  it("press at the terminal root is a no-op (nothing deeper)", () => {
    const atRoot = dig(dig(scroll(initialEtymologyUiState(snap), +2)));
    expect(dig(atRoot)).toBe(atRoot);
  });

  it("digging straight into the root stage from depth 0 reveals the root", () => {
    const state = dig(scroll(initialEtymologyUiState(snap), +3));
    expect(uiDepth(state)).toBe(1);
    expect(viewMode(state, ladder)).toBe("root");
  });
});

describe("breadcrumb", () => {
  it("grows with each dig, home crumb first", () => {
    let state = scroll(initialEtymologyUiState(snap), +2);
    expect(breadcrumb(state, snap, ladder)).toEqual(["travel"]);
    state = dig(state);
    expect(breadcrumb(state, snap, ladder)).toEqual(["travel", "travailler"]);
    state = dig(state);
    expect(breadcrumb(state, snap, ladder)).toEqual([
      "travel",
      "travailler",
      "trepālium",
    ]);
  });

  it("feeds the topbar path trail", () => {
    const home = initialEtymologyUiState(snap);
    expect(topbarPath(home, snap, ladder)).toEqual({
      trail: "~/",
      current: "travel",
    });
    const dug = dig(dig(scroll(home, +2)));
    expect(topbarPath(dug, snap, ladder)).toEqual({
      trail: "~/travel/travailler/",
      current: "trepālium",
    });
  });

  it("labels depth against the payload depth", () => {
    const home = initialEtymologyUiState(snap);
    expect(depthLabel(home, snap)).toBe("depth 0/3");
    expect(depthLabel(dig(scroll(home, +2)), snap)).toBe("depth 1/3");
  });
});

describe("back (walks the breadcrumb up)", () => {
  it("pops one level at a time and restores the depth-0 cursor", () => {
    let state = dig(dig(scroll(initialEtymologyUiState(snap), +2)));
    expect(uiDepth(state)).toBe(2);
    state = back(state);
    expect(uiDepth(state)).toBe(1);
    expect(focusedStage(state, ladder)?.form).toBe("travailler");
    state = back(state);
    expect(uiDepth(state)).toBe(0);
    expect(viewMode(state, ladder)).toBe("ladder");
    expect(state.cursor).toBe(2); // wheel selection survives the round trip
  });

  it("is a no-op at depth 0", () => {
    const home = scroll(initialEtymologyUiState(snap), +1);
    expect(back(home)).toBe(home);
  });
});

describe("purity", () => {
  it("returns frozen states and never mutates the payload", () => {
    const state = dig(scroll(initialEtymologyUiState(snap), +2));
    expect(Object.isFrozen(state)).toBe(true);
    expect(Object.isFrozen(state.path)).toBe(true);
    expect(Object.isFrozen(snap.trace)).toBe(true);
    expect(ladderOf(snap.trace).map((s) => s.form)).toEqual(
      ladder.map((s) => s.form),
    );
  });

  it("focusedIndex tracks cursor at depth 0 and path tip when dug", () => {
    const home = scroll(initialEtymologyUiState(snap), +2);
    expect(focusedIndex(home)).toBe(2);
    expect(focusedIndex(dig(dig(home)))).toBe(3);
  });
});

describe("root helpers", () => {
  it("renders the compound root line and gloss", () => {
    const root = ladder[3];
    expect(componentsLine(root)).toBe("trēs + pālus");
    expect(componentsGloss(root)).toBe('"three" + "stake"');
    expect(componentsLine(ladder[0])).toBeNull();
  });
});
