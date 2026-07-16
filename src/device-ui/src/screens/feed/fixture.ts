import type { FeedSnapshotV1 } from "../../protocol/feed";

/**
 * Fixture shaped for `spec/feed-4f.png` (F2 UI).
 * Accents are host-style hex (deterministic palette tokens).
 */
export const feedFixtureSnapshot: FeedSnapshotV1 = Object.freeze({
  as_of: "2026-07-15T14:20:00Z",
  stale: false,
  posts: Object.freeze([
    Object.freeze({
      id: "p-nws",
      handle: "@NWSBoulder",
      body: "Severe t-storm watch for Douglas County until 9 PM. Hail possible south of Castle Rock.",
      time_label: "12m",
      accent: "#ff6b35",
    }),
    Object.freeze({
      id: "p-tenure",
      handle: "@tenureband",
      body: '"new song out of the basement friday. it\'s about a dog. sort of."',
      time_label: "41m",
      accent: "#a0533e",
    }),
    Object.freeze({
      id: "p-cth",
      handle: "@carthinghacks",
      body: "the wheel encoder is just evdev. everything is possible.",
      time_label: "1h",
      accent: "#f7c948",
    }),
    Object.freeze({
      id: "p-archive",
      handle: "@internetarchive",
      body: "Preserving useful knowledge, one snapshot at a time.",
      time_label: "2h",
      accent: "#4ecdc4",
    }),
    Object.freeze({
      id: "p-nasa",
      handle: "@nasa",
      body: "A new view of the night sky and the worlds beyond it.",
      time_label: "3h",
      accent: "#5b8def",
    }),
    Object.freeze({
      id: "p-pdr",
      handle: "@publicdomainrev",
      body: "Today in the archive: strange machines and careful diagrams.",
      time_label: "5h",
      accent: "#c77dff",
    }),
    Object.freeze({
      id: "p-extra",
      handle: "@paperweight",
      body: "read-only snapshot · no likes · no replies · just the ink.",
      time_label: "8h",
      accent: "#ff7aa2",
    }),
  ]),
});
