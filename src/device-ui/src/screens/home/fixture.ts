import type { HomeGlanceV1 } from "./model";

/** Placeholder glance data until a host aggregate snapshot exists. */
export const homeFixtureGlance: HomeGlanceV1 = {
  clockLabel: "thu 09:14",
  nowPlaying: {
    kind: "now-playing",
    title: "sundara",
    artist: "alina baraz",
    progressMs: 134_000,
    durationMs: 220_000,
    volumeLevel: 62,
  },
  weather: {
    kind: "weather",
    tempF: 72,
    condition: "clear",
    walkNote: "good walk window",
    uvIndex: 2,
    uvGrade: "low",
  },
  feed: {
    kind: "feed",
    quote: "dithered desk setup",
    handle: "@sundaybest",
    newCount: 3,
  },
  etymology: {
    kind: "etymology",
    chain: "travailler → trepālium",
    depth: 2,
    maxDepth: 3,
  },
  photo: {
    kind: "photo",
    index: 3,
    total: 48,
    reprintRatio: 0.4,
    reprintLabel: "6m",
  },
};
