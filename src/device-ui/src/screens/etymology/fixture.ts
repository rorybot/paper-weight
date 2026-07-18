import type {
  EtymologyOriginV1,
  EtymologySnapshotV1,
} from "../../protocol/etymology";

/**
 * `travel` fixture shaped for the three mockups
 * (`spec/etymology-2a-depth0.png` … `2c-depth2.png`) and the E1 corpus spine:
 * travel → travailen → travailler → trepālium (terminal root, trēs + pālus).
 */

const trepalium: EtymologyOriginV1 = Object.freeze({
  form: "trepālium",
  language: "late latin",
  period: "c.400",
  gloss: "a frame of three stakes used for torture",
  notes: "you turned a wheel to reach a torture device",
  splits_into: Object.freeze([]),
  components: Object.freeze([
    Object.freeze({ form: "trēs", gloss: "three" }),
    Object.freeze({ form: "pālus", gloss: "stake" }),
  ]),
  root: true,
  from: null,
});

const travailler: EtymologyOriginV1 = Object.freeze({
  form: "travailler",
  language: "old french",
  period: "c.1200",
  gloss: "to toil, to labour, to suffer",
  notes:
    'Borrowed into Middle English as travailen. Because medieval journeys were long and dangerous, "to labour/suffer" drifted into "to journey" — and English kept travail (hardship) and travel (the trip) as two words from this one.',
  splits_into: Object.freeze([
    Object.freeze({ form: "travel", note: "en" }),
    Object.freeze({ form: "travail", note: "en/fr" }),
  ]),
  components: Object.freeze([]),
  root: false,
  from: trepalium,
});

const travailen: EtymologyOriginV1 = Object.freeze({
  form: "travailen",
  language: "middle english",
  period: "c.1375",
  gloss: "to toil, to journey",
  notes: null,
  splits_into: Object.freeze([]),
  components: Object.freeze([]),
  root: false,
  from: travailler,
});

const travel: EtymologyOriginV1 = Object.freeze({
  form: "travel",
  language: "modern english",
  period: "now",
  gloss: "to journey",
  notes: null,
  splits_into: Object.freeze([]),
  components: Object.freeze([]),
  root: false,
  from: travailen,
});

export const etymologyFixtureSnapshot: EtymologySnapshotV1 = Object.freeze({
  as_of: "2026-07-15",
  date_label: "wed jul 15",
  stale: false,
  source: "etymonline snapshot",
  word: Object.freeze({
    headword: "travel",
    language: "modern english",
    part_of_speech: "verb",
    gloss: "to make a journey",
    summary:
      "its root means torture. journeys used to be agony — the word never forgot.",
    cousins: Object.freeze(["travail", "travolator"]),
  }),
  depth: 3,
  trace: travel,
});
