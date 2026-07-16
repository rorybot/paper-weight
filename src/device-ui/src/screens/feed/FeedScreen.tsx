import type { JSX } from "preact";
import { useEffect, useMemo, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type { FeedPostV1, FeedSnapshotV1 } from "../../protocol/feed";
import {
  clockLabel,
  initialFeedUiState,
  positionLabel,
  railProgress,
  reduceFeedUi,
  visibleIndices,
  type FeedUiCommand,
  type FeedUiState,
} from "./model";
import "./feed.css";

export type FeedScreenProps = Readonly<{
  snapshot: FeedSnapshotV1;
  /** BERG is the mockup target for 4f. */
  theme?: ThemeName;
  /** Controlled UI; when set, component is controlled. */
  ui?: FeedUiState;
  initialSelectedIndex?: number;
  /**
   * Shell commands: `scroll-feed` (and optional local toggle for tests).
   * Wave 3 wires from ShellApp; tests pass one-shot commands.
   */
  command?: FeedUiCommand | null;
  /**
   * When shell owns `feed-detail` overlay, pass `enlarged` so the screen
   * reflects press/back without re-implementing overlay routing.
   */
  enlarged?: boolean;
  onUiChange?: (state: FeedUiState) => void;
}>;

const PostRow = ({
  post,
  selected,
  enlarged,
  position,
}: {
  readonly post: FeedPostV1;
  readonly selected: boolean;
  readonly enlarged: boolean;
  readonly position: string;
}): JSX.Element => (
  <article
    class={[
      "berg-card",
      "relative",
      "min-h-[13px]",
      "fd-post",
      selected ? "berg-card--paper" : "berg-card--dark",
      selected ? "berg-card--selected" : "fd-post--dim",
    ].join(" ")}
    data-selected={String(selected)}
    data-tone={selected ? "paper" : "dark"}
    data-post-id={post.id}
  >
    <p class="berg-card__eyebrow">
      <span class="fd-post__handle" style={{ color: post.accent }}>
        {post.handle}
      </span>
      {" · "}
      <span>{post.time_label}</span>
    </p>
    <div class="berg-card__body">
      {selected ? (
        <span class="fd-post__marker">
          {enlarged ? "READING NOW" : `READING ${position}`}
        </span>
      ) : null}
      <p class="fd-post__body">{post.body}</p>
    </div>
  </article>
);

export const FeedScreen = ({
  snapshot,
  theme = "berg",
  ui: controlledUi,
  initialSelectedIndex = 1,
  command = null,
  enlarged: enlargedProp,
  onUiChange,
}: FeedScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialFeedUiState(snapshot, initialSelectedIndex),
  );

  const base = controlledUi ?? internal;
  const enlarged = enlargedProp ?? base.enlarged;
  const state: FeedUiState = Object.freeze({
    selectedIndex: base.selectedIndex,
    enlarged,
  });

  useEffect(() => {
    if (!command) return;
    setInternal((prev) => {
      const start = controlledUi ?? prev;
      const next = reduceFeedUi(start, command, snapshot.posts.length);
      if (
        next.selectedIndex !== start.selectedIndex ||
        next.enlarged !== start.enlarged
      ) {
        onUiChange?.(next);
      }
      return next;
    });
  }, [command, snapshot.posts.length, controlledUi, onUiChange]);

  useEffect(() => {
    if (enlargedProp === undefined || controlledUi) return;
    setInternal((prev) =>
      prev.enlarged === enlargedProp
        ? prev
        : Object.freeze({ ...prev, enlarged: enlargedProp }),
    );
  }, [enlargedProp, controlledUi]);

  const indices = useMemo(
    () => visibleIndices(snapshot.posts.length, state.selectedIndex),
    [snapshot.posts.length, state.selectedIndex],
  );

  const pos = positionLabel(state.selectedIndex, snapshot.posts.length);
  const progress = railProgress(state.selectedIndex, snapshot.posts.length);
  const thumbTop = `${Math.round(progress * 100)}%`;
  const clock = clockLabel(snapshot.as_of);

  return (
    <main
      class={`${themeClassName(theme)} fd-screen`}
      data-theme={theme}
      data-screen="feed"
      data-enlarged={String(state.enlarged)}
      data-stale={String(snapshot.stale)}
      data-selected-index={String(state.selectedIndex)}
      data-post-count={String(snapshot.posts.length)}
      style={{ width: "800px", height: "480px" }}
    >
      <header class="fd-topbar">
        <span>[cthing]</span>
        <nav class="fd-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span>2:pl</span>
          <span>3:wx</span>
          <span data-active="true">4:fd*</span>
        </nav>
        <span class="fd-topbar__quote">
          the feed, printed for you
          {clock ? ` · ${clock}` : ""}
        </span>
      </header>

      <section class="fd-main" aria-label="Read-only feed snapshot">
        <div class="fd-main__rail" aria-hidden="true" />

        <div
          class="fd-posts"
          data-visible-count={String(indices.length)}
          role="listbox"
          aria-label="Feed posts"
        >
          {indices.map((index) => {
            const post = snapshot.posts[index];
            if (!post) return null;
            return (
              <PostRow
                key={post.id}
                post={post}
                selected={index === state.selectedIndex}
                enlarged={state.enlarged}
                position={pos}
              />
            );
          })}
        </div>

        <div
          class="fd-scroll"
          aria-label={`Post ${pos}`}
          data-progress={progress.toFixed(3)}
        >
          <div class="fd-scroll__track">
            <span
              class="fd-scroll__thumb"
              style={{ top: thumbTop }}
              aria-hidden="true"
            />
          </div>
          <span class="fd-scroll__label">{pos}</span>
        </div>
      </section>

      <footer class="fd-footer">
        <span>◉ turn to scroll</span>
        <span data-active={String(state.enlarged)}>
          {state.enlarged ? "press / back collapse" : "press to enlarge"}
        </span>
        <span>read-only snapshot</span>
      </footer>
    </main>
  );
};
