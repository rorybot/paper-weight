import type { PhotoSnapshotV1 } from "../../protocol/photo";
import artPbmBase64 from "./fixture-art.b64.txt?raw";
import {
  initialPhotoLocalState,
  localToSnapshot,
  type PhotoEntryV1,
} from "./model";

const art = artPbmBase64.trim();

/** Three-entry demo library for H2 UI tests (Atkinson PBM from host P5). */
export const photoFixtureEntries: readonly PhotoEntryV1[] = Object.freeze([
  Object.freeze({
    id: "porch-light",
    caption: "porch light, tuesday",
    path: "/library/porch-light.jpg",
    art_pbm_base64: art,
  }),
  Object.freeze({
    id: "river-fog",
    caption: "river fog before work",
    path: "/library/river-fog.jpg",
    art_pbm_base64: art,
  }),
  Object.freeze({
    id: "desk-notes",
    caption: "desk notes · soft pencil",
    path: "/library/desk-notes.jpg",
    art_pbm_base64: art,
  }),
]);

export const photoFixtureLocal = initialPhotoLocalState(photoFixtureEntries, {
  index: 0,
  reprints_in_min: 4,
  reprint_interval_min: 5,
  as_of: "2026-07-16T15:00:00Z",
  source: "local library",
});

/** Snapshot shaped for screen 4g (H2). */
export const photoFixtureSnapshot: PhotoSnapshotV1 = localToSnapshot(
  photoFixtureLocal,
);
