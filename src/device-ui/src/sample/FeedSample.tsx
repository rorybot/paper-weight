import type { JSX } from "preact";

import { Card, themeClassName, type ThemeName } from "../design";

type Post = Readonly<{
  body: string;
  handle: string;
  time: string;
  selected?: boolean;
}>;

const posts = Object.freeze<ReadonlyArray<Post>>([
  {
    handle: "@mattgolder",
    time: "3m",
    body: "Severe t-storm watch for Douglas County until 9 PM. Hail possible south of Castle Rock.",
  },
  {
    handle: "@stoneband",
    time: "41m",
    body: '“new song out of the basement Friday. it’s about a dog. sort of.”',
    selected: true,
  },
  {
    handle: "@carthinghacks",
    time: "1h",
    body: "the wheel encoder is just evdev. everything is possible.",
  },
]);

const PostCard = ({ body, handle, selected = false, time }: Post): JSX.Element => (
  <Card
    className="feed-post"
    eyebrow={`${handle} · ${time}`}
    footer={selected ? "↪ 11   ♡ 348" : undefined}
    selected={selected}
    tone={selected ? "paper" : "dark"}
  >
    <p>{body}</p>
    {selected ? <span class="feed-post__marker">READING 2/8</span> : null}
  </Card>
);

export const FeedSample = ({ theme = "berg" }: Readonly<{ theme?: ThemeName }>): JSX.Element => (
  <main class={`${themeClassName(theme)} sample-screen`} data-theme={theme}>
    <header class="sample-topbar">
      <span>[cthing]</span>
      <span>signal 3/3</span>
      <span class="sample-topbar__accent">4:feed</span>
      <span class="sample-topbar__quote">the feed, printed for you · 14:20</span>
    </header>

    <section aria-label="Read-only feed snapshot" class="sample-feed">
      <div class="sample-feed__rail" aria-hidden="true" />
      <div class="sample-feed__posts">
        {posts.map((post) => (
          <PostCard key={`${post.handle}-${post.time}`} {...post} />
        ))}
      </div>
      <div class="sample-scroll" aria-label="Post 2 of 8">
        <span class="sample-scroll__thumb" />
        <span>2/8</span>
      </div>
    </section>

    <footer class="sample-footer">
      <span>◉ turn to scroll</span>
      <span>press to enlarge</span>
      <span>read-only snapshot</span>
    </footer>
  </main>
);

