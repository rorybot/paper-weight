import { describe, expect, it } from "vitest";

import { photoFixtureEntries, photoFixtureLocal } from "./fixture";
import {
  initialPhotoLocalState,
  keepLabel,
  localToSnapshot,
  reducePhotoLocal,
  statusLine,
} from "./model";

describe("photo model", () => {
  it("statusLine formats photo N/M · reprints in X min", () => {
    const snap = localToSnapshot(photoFixtureLocal);
    expect(statusLine(snap)).toBe("photo 1/3 · reprints in 4 min");
  });

  it("skip advances, wraps, clears keep, resets countdown", () => {
    let state = initialPhotoLocalState(photoFixtureEntries, {
      reprints_in_min: 2,
      reprint_interval_min: 5,
    });
    state = reducePhotoLocal(state, { type: "keep-photo-on-show" });
    expect(state.kept).toBe(true);

    state = reducePhotoLocal(state, { type: "skip-photo", delta: 1 });
    expect(state.kept).toBe(false);
    expect(state.index).toBe(1);
    expect(state.reprints_in_min).toBe(5);

    const snap = localToSnapshot(state);
    expect(snap.index).toBe(2);
    expect(snap.total).toBe(3);
    expect(snap.id).toBe("river-fog");
    expect(statusLine(snap)).toBe("photo 2/3 · reprints in 5 min");

    state = reducePhotoLocal(state, { type: "skip-photo", delta: 1 });
    state = reducePhotoLocal(state, { type: "skip-photo", delta: 1 });
    expect(state.index).toBe(0);
    expect(localToSnapshot(state).id).toBe("porch-light");
  });

  it("keep toggles pin label", () => {
    let state = photoFixtureLocal;
    expect(keepLabel(state.kept)).toBe("press keep");
    state = reducePhotoLocal(state, { type: "keep-photo-on-show" });
    expect(state.kept).toBe(true);
    expect(keepLabel(state.kept)).toBe("kept on show");
    expect(localToSnapshot(state).kept).toBe(true);
  });

  it("empty library snapshot", () => {
    const snap = localToSnapshot(initialPhotoLocalState([]));
    expect(snap.empty).toBe(true);
    expect(snap.index).toBe(0);
    expect(snap.total).toBe(0);
    expect(statusLine(snap)).toBe("photo 0/0 · no reprints");
  });
});
