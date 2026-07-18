/**
 * Etymology channel payload — owned by E1/E2. See features/etymology/spec.md
 *
 * Payload types only. `etymology` is NOT yet part of the ChannelV1 union
 * (envelope.ts stays frozen); a future protocol card wires the channel.
 */

/** A later word that branched off a stage ("SPLITS INTO", mockup 2b). */
export type EtymologyBranchV1 = {
  readonly form: string;
  readonly note: string | null; // e.g. "en", "en/fr"
};

/** Morphological piece of a compound root (e.g. trēs + pālus, mockup 2c). */
export type EtymologyComponentV1 = {
  readonly form: string;
  readonly gloss: string;
};

/**
 * One stage in a word's history. `from` links to the earlier stage it
 * descended from; `from === null` (and `root === true`) marks the terminal
 * root — bedrock, no earlier attested form. Newest → oldest.
 */
export type EtymologyOriginV1 = {
  readonly form: string;
  readonly language: string;
  readonly period: string | null; // "now", "c.1200", "latin"
  readonly gloss: string;
  readonly notes: string | null; // longer prose for the drill-down view
  readonly splits_into: readonly EtymologyBranchV1[];
  readonly components: readonly EtymologyComponentV1[];
  readonly root: boolean; // true when this is the terminal root
  readonly from: EtymologyOriginV1 | null; // recursive parent; null at root
};

/** Day's-word display metadata (left pane of mockup 2a). */
export type EtymologyWordV1 = {
  readonly headword: string;
  readonly language: string; // "modern english"
  readonly part_of_speech: string; // "verb"
  readonly gloss: string; // "to make a journey"
  readonly summary: string; // "its root means torture…"
  readonly cousins: readonly string[]; // ["travail", "travolator"]
};

/** Host → device payload for the (future) channel "etymology". */
export type EtymologySnapshotV1 = {
  readonly as_of: string; // ISO-8601 day, e.g. "2026-07-15"
  readonly date_label: string; // "wed jul 15"
  readonly stale: boolean;
  readonly source: string; // "etymonline snapshot"
  readonly word: EtymologyWordV1;
  /** Number of `from` hops from the trace top to the terminal root. */
  readonly depth: number;
  /** Recursive origin spine; walk `from` to climb to the root. */
  readonly trace: EtymologyOriginV1;
};
