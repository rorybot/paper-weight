import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { etymologyFixtureSnapshot } from "./fixture";
import { EtymologyScreen } from "./EtymologyScreen";
import {
  initialEtymologyUiState,
  ladderOf,
  reduceEtymologyUi,
  type EtymologyUiState,
} from "./model";

const snap = etymologyFixtureSnapshot;
const ladder = ladderOf(snap.trace);

const dugInto = (cursor: number, digs: number): EtymologyUiState => {
  let ui = initialEtymologyUiState(snap, cursor);
  for (let i = 0; i < digs; i += 1) {
    ui = reduceEtymologyUi(ui, { type: "dig-etymology" }, ladder);
  }
  return ui;
};

describe("EtymologyScreen depth 0 (mockup 2a)", () => {
  it("renders the 800×480 root-of-day + trace ladder", () => {
    const html = render(
      <EtymologyScreen snapshot={snap} theme="gruvbox" initialCursor={2} />,
    );

    expect(html).toContain("et-screen");
    expect(html).toContain('data-theme="gruvbox"');
    expect(html).toContain('data-screen="etymology"');
    expect(html).toContain('data-mode="ladder"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);

    expect(html).toContain("[cthing]");
    expect(html).toContain("root of the day · wed jul 15 · depth 0/3");

    expect(html).toContain("modern english · verb");
    expect(html).toContain("travel");
    expect(html).toContain("to make a journey");
    expect(html).toContain("its root means torture");
    expect(html).toContain("cousins: travail, travolator");
    expect(html).toContain("src: etymonline snapshot");

    expect(html).toContain(
      "TRACE — oldest at the bottom · press to dig into a stage",
    );
    expect(html).toContain("travailen");
    expect(html).toContain("travailler");
    expect(html).toContain("trepālium");
    expect(html).toContain("trēs + pālus");
    expect(html).toContain("wheel pick a stage");
    expect(html).toContain("dig deeper");
  });

  it("highlights the wheel-selected stage", () => {
    let ui = initialEtymologyUiState(snap, 1);
    ui = reduceEtymologyUi(ui, { type: "scroll-etymology", delta: 1 }, ladder);
    const html = render(<EtymologyScreen snapshot={snap} ui={ui} />);
    expect(html).toContain('data-cursor="2"');
    expect(html).toContain('data-focus-form="travailler"');
    expect(html).toContain("et-row--selected");
  });
});

describe("EtymologyScreen depth 1 (mockup 2b)", () => {
  it("renders the dug stage with breadcrumb, splits and FROM", () => {
    const html = render(
      <EtymologyScreen snapshot={snap} ui={dugInto(2, 1)} />,
    );

    expect(html).toContain('data-mode="stage"');
    expect(html).toContain('data-depth="1"');
    expect(html).toContain("depth 1/3");
    expect(html).toContain("~/travel/");
    expect(html).toContain('data-focus-form="travailler"');
    expect(html).toContain("old french · c.1200");
    expect(html).toContain("to toil, to labour, to suffer");
    expect(html).toContain("Borrowed into Middle English");
    expect(html).toContain("SPLITS INTO — wheel");
    expect(html).toContain("travail");
    expect(html).toContain("(en/fr)");
    expect(html).toContain("FROM — press to dig ↓");
    expect(html).toContain("dig into trepālium");
    expect(html).toContain("up one level");
  });
});

describe("EtymologyScreen depth 2 (mockup 2c)", () => {
  it("renders the terminal root reveal", () => {
    const html = render(
      <EtymologyScreen snapshot={snap} ui={dugInto(2, 2)} />,
    );

    expect(html).toContain('data-mode="root"');
    expect(html).toContain('data-depth="2"');
    expect(html).toContain("depth 2/3 · root");
    expect(html).toContain("~/travel/travailler/");
    expect(html).toContain("trepālium");
    expect(html).toContain("late latin · a frame of three stakes used for torture");
    expect(html).toContain("trēs + pālus");
    expect(html).toContain("&quot;three&quot; + &quot;stake&quot;");
    expect(html).toContain("you turned a wheel to reach a torture device");
    expect(html).toContain("bedrock · no earlier attested form");
    expect(html).toContain("press · nothing deeper");
    expect(html).toContain("climb out");
    expect(html).toContain("3 levels deep");
  });

  it("back from the root returns to the stage view", () => {
    const ui = reduceEtymologyUi(
      dugInto(2, 2),
      { type: "back-etymology" },
      ladder,
    );
    const html = render(<EtymologyScreen snapshot={snap} ui={ui} />);
    expect(html).toContain('data-mode="stage"');
    expect(html).toContain('data-focus-form="travailler"');
  });
});

describe("EtymologyScreen chrome", () => {
  it("marks stale snapshots", () => {
    const html = render(
      <EtymologyScreen snapshot={{ ...snap, stale: true }} />,
    );
    expect(html).toContain('data-stale="true"');
  });

  it("defaults to gruvbox (mockup palette)", () => {
    const html = render(<EtymologyScreen snapshot={snap} />);
    expect(html).toContain("theme-gruvbox");
  });
});
