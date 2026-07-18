import type { JSX } from "preact";
import { useEffect, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type {
  EtymologyOriginV1,
  EtymologySnapshotV1,
} from "../../protocol/etymology";
import {
  breadcrumb,
  componentsGloss,
  componentsLine,
  depthLabel,
  focusedStage,
  initialEtymologyUiState,
  ladderOf,
  reduceEtymologyUi,
  topbarPath,
  uiDepth,
  viewMode,
  type EtymologyUiCommand,
  type EtymologyUiState,
} from "./model";
import "./etymology.css";

export type EtymologyScreenProps = Readonly<{
  snapshot: EtymologySnapshotV1;
  /** Gruvbox is the mockup target for 2a/2b/2c. */
  theme?: ThemeName;
  /** Controlled UI; when set, component is controlled. */
  ui?: EtymologyUiState;
  initialCursor?: number;
  /**
   * Shell commands: wheel `scroll-etymology`, press `dig-etymology`,
   * back `back-etymology`. W3-D wires from ShellApp; tests pass one-shot
   * commands or controlled `ui`.
   */
  command?: EtymologyUiCommand | null;
  onUiChange?: (state: EtymologyUiState) => void;
}>;

const LadderRow = ({
  stage,
  index,
  selected,
}: {
  readonly stage: EtymologyOriginV1;
  readonly index: number;
  readonly selected: boolean;
}): JSX.Element => (
  <li
    class={["et-row", selected ? "et-row--selected" : ""].join(" ")}
    data-selected={String(selected)}
    data-stage-index={String(index)}
  >
    <span class="et-row__period">{stage.period ?? stage.language}</span>
    <span class="et-row__marker">{selected ? "▸" : "│"}</span>
    <span class="et-row__text">
      <strong class="et-row__form">{stage.form}</strong>{" "}
      <span class="et-row__gloss">
        {index === 0 ? stage.gloss : `${stage.language} · ${stage.gloss}`}
      </span>
    </span>
  </li>
);

const LadderView = ({
  snapshot,
  ladder,
  state,
}: {
  readonly snapshot: EtymologySnapshotV1;
  readonly ladder: readonly EtymologyOriginV1[];
  readonly state: EtymologyUiState;
}): JSX.Element => {
  const root = ladder[ladder.length - 1];
  const compound = root ? componentsLine(root) : null;
  return (
    <section class="et-ladder" aria-label="Word of the day and trace ladder">
      <div class="et-word">
        <p class="et-word__eyebrow">
          {snapshot.word.language} · {snapshot.word.part_of_speech}
        </p>
        <h1 class="et-word__headword">{snapshot.word.headword}</h1>
        <p class="et-word__gloss">{snapshot.word.gloss}</p>
        <p class="et-word__summary">{snapshot.word.summary}</p>
        <div class="et-word__meta">
          <p>cousins: {snapshot.word.cousins.join(", ")}</p>
          <p>src: {snapshot.source}</p>
        </div>
      </div>
      <div class="et-trace">
        <p class="et-trace__caption">
          TRACE — oldest at the bottom · press to dig into a stage
        </p>
        <ol class="et-trace__rows" role="listbox" aria-label="Origin stages">
          {ladder.map((stage, index) => (
            <LadderRow
              key={`${stage.form}-${index}`}
              stage={stage}
              index={index}
              selected={index === state.cursor}
            />
          ))}
          {root && compound ? (
            <li class="et-row et-row--components" data-selected="false">
              <span class="et-row__period" />
              <span class="et-row__marker">└</span>
              <span class="et-row__text">
                <strong class="et-row__compound">{compound}</strong>{" "}
                <span class="et-row__gloss">{componentsGloss(root)}</span>
              </span>
            </li>
          ) : null}
        </ol>
      </div>
    </section>
  );
};

const Crumbs = ({
  crumbs,
}: {
  readonly crumbs: readonly string[];
}): JSX.Element => (
  <p class="et-crumbs" aria-label="Breadcrumb">
    {crumbs.map((crumb, index) => (
      <span key={`${crumb}-${index}`}>
        {index > 0 ? <span class="et-crumbs__sep"> › </span> : null}
        <span
          class="et-crumbs__crumb"
          data-current={String(index === crumbs.length - 1)}
        >
          {crumb}
        </span>
      </span>
    ))}
  </p>
);

const StageView = ({
  stage,
  crumbs,
}: {
  readonly stage: EtymologyOriginV1;
  readonly crumbs: readonly string[];
}): JSX.Element => (
  <section class="et-stage" aria-label={`Origin stage ${stage.form}`}>
    <Crumbs crumbs={crumbs} />
    <h1 class="et-stage__form">
      {stage.form}
      <span class="et-stage__meta">
        {stage.language}
        {stage.period ? ` · ${stage.period}` : ""}
      </span>
    </h1>
    <p class="et-stage__gloss">"{stage.gloss}"</p>
    {stage.notes ? <p class="et-stage__notes">{stage.notes}</p> : null}
    <div class="et-stage__links">
      {stage.splits_into.length > 0 ? (
        <div class="et-splits" aria-label="Later words that branched off">
          <p class="et-links__caption">SPLITS INTO — wheel</p>
          <ul>
            {stage.splits_into.map((branch) => (
              <li key={branch.form}>
                <span class="et-splits__arrow">→ </span>
                <strong>{branch.form}</strong>
                {branch.note ? (
                  <span class="et-splits__note"> ({branch.note})</span>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
      {stage.from ? (
        <div class="et-from" aria-label="Earlier form">
          <p class="et-links__caption">FROM — press to dig ↓</p>
          <p>
            <span class="et-from__arrow">▸ </span>
            <strong>{stage.from.form}</strong>{" "}
            <span class="et-from__lang">{stage.from.language}</span>
          </p>
        </div>
      ) : null}
    </div>
  </section>
);

const RootView = ({
  stage,
  crumbs,
}: {
  readonly stage: EtymologyOriginV1;
  readonly crumbs: readonly string[];
}): JSX.Element => (
  <section class="et-root" aria-label={`Terminal root ${stage.form}`}>
    <Crumbs crumbs={crumbs} />
    <h1 class="et-root__form">{stage.form}</h1>
    <p class="et-root__gloss">
      {stage.language} · {stage.gloss}
    </p>
    {componentsLine(stage) ? (
      <div class="et-root__components">
        <p class="et-root__compound">{componentsLine(stage)}</p>
        <p class="et-root__component-gloss">
          {componentsGloss(stage)}
          {stage.notes ? ` → ${stage.notes}` : ""}
        </p>
      </div>
    ) : null}
    <p class="et-root__bedrock">--- bedrock · no earlier attested form ---</p>
  </section>
);

export const EtymologyScreen = ({
  snapshot,
  theme = "gruvbox",
  ui: controlledUi,
  initialCursor = 0,
  command = null,
  onUiChange,
}: EtymologyScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialEtymologyUiState(snapshot, initialCursor),
  );
  const state = controlledUi ?? internal;

  const ladder = ladderOf(snapshot.trace);

  useEffect(() => {
    if (!command) return;
    setInternal((prev) => {
      const start = controlledUi ?? prev;
      const next = reduceEtymologyUi(start, command, ladder);
      if (next !== start) onUiChange?.(next);
      return next;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [command, controlledUi, onUiChange, snapshot]);

  const mode = viewMode(state, ladder);
  const depth = uiDepth(state);
  const focus = focusedStage(state, ladder);
  const crumbs = breadcrumb(state, snapshot, ladder);
  const path = topbarPath(state, snapshot, ladder);

  return (
    <main
      class={`${themeClassName(theme)} et-screen`}
      data-theme={theme}
      data-screen="etymology"
      data-mode={mode}
      data-depth={String(depth)}
      data-cursor={String(state.cursor)}
      data-focus-form={focus?.form ?? ""}
      data-stale={String(snapshot.stale)}
      style={{ width: "800px", height: "480px" }}
    >
      <header class="et-topbar">
        <span class="et-topbar__brand">[cthing]</span>
        <span class="et-topbar__path">
          {path.trail} <strong>{path.current}</strong>
        </span>
        <span class="et-topbar__status">
          {mode === "ladder"
            ? `root of the day · ${snapshot.date_label} · ${depthLabel(state, snapshot)}`
            : mode === "root"
              ? `${depthLabel(state, snapshot)} · root`
              : depthLabel(state, snapshot)}
        </span>
      </header>

      {mode === "ladder" ? (
        <LadderView snapshot={snapshot} ladder={ladder} state={state} />
      ) : null}
      {mode === "stage" && focus ? (
        <StageView stage={focus} crumbs={crumbs} />
      ) : null}
      {mode === "root" && focus ? (
        <RootView stage={focus} crumbs={crumbs} />
      ) : null}

      <footer class="et-footer">
        {mode === "ladder" ? (
          <>
            <span>◉ wheel pick a stage</span>
            <span>
              <strong>press</strong> dig deeper ↓
            </span>
            <span>
              ◂ <strong>back</strong> home
            </span>
          </>
        ) : null}
        {mode === "stage" && focus?.from ? (
          <>
            <span>
              <strong>press</strong> dig into {focus.from.form} ↓
            </span>
            <span>
              ◂ <strong>back</strong> up one level
            </span>
          </>
        ) : null}
        {mode === "root" ? (
          <>
            <span>press · nothing deeper</span>
            <span>
              ◂ <strong>back</strong> climb out
            </span>
            <span class="et-footer__depth">{snapshot.depth} levels deep</span>
          </>
        ) : null}
      </footer>
    </main>
  );
};
