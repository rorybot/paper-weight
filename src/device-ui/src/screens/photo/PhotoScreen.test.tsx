import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import {
  photoFixtureLocal,
  photoFixtureSnapshot,
} from "./fixture";
import {
  localToSnapshot,
  reducePhotoLocal,
  statusLine,
} from "./model";
import { PhotoScreen } from "./PhotoScreen";

const snap = photoFixtureSnapshot;

describe("PhotoScreen", () => {
  it("renders 800×480 BERG cream frame matching 4g intent", () => {
    const html = render(<PhotoScreen snapshot={snap} theme="berg" />);

    expect(html).toContain("ph-screen");
    expect(html).toContain('data-theme="berg"');
    expect(html).toContain('data-screen="photo"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("reprints for the desk");
    expect(html).toContain("ph-frame");
    expect(html).toContain("porch light, tuesday");
    expect(html).toContain("photo 1/3 · reprints in 4 min");
    expect(html).toContain('data-art="true"');
    expect(html).toContain("data:image/bmp;base64,");
    expect(html).toContain("turn to skip");
    expect(html).toContain("press keep");
    expect(html).toContain("local library");
    expect(html).toContain('data-index="1"');
    expect(html).toContain('data-total="3"');
  });

  it("skip/keep update N/M and keep chrome via pure local reducer", () => {
    let local = photoFixtureLocal;
    local = reducePhotoLocal(local, { type: "skip-photo", delta: 1 });
    local = reducePhotoLocal(local, { type: "keep-photo-on-show" });
    const next = localToSnapshot(local);
    const html = render(<PhotoScreen snapshot={next} />);

    expect(statusLine(next)).toBe("photo 2/3 · reprints in 5 min");
    expect(html).toContain("river fog before work");
    expect(html).toContain("photo 2/3 · reprints in 5 min");
    expect(html).toContain('data-kept="true"');
    expect(html).toContain("kept on show");
    expect(html).toContain("ph-frame__pin");
  });

  it("empty library shows drop hint", () => {
    const empty: typeof snap = {
      ...snap,
      empty: true,
      index: 0,
      total: 0,
      caption: "",
      id: null,
      path: null,
      art_pbm_base64: null,
    };
    const html = render(<PhotoScreen snapshot={empty} />);
    expect(html).toContain('data-empty="true"');
    expect(html).toContain("drop photos into the library");
    expect(html).toContain("photo 0/0 · no reprints");
  });

  it("marks stale snapshots", () => {
    const html = render(
      <PhotoScreen snapshot={{ ...snap, stale: true }} />,
    );
    expect(html).toContain('data-stale="true"');
  });
});
