import { describe, expect, it } from "vitest";

import { photoFixtureSnapshot } from "./fixture";
import {
  parsePbmBase64,
  pbmBase64ToDataUrl,
  pbmToBmpDataUrl,
} from "./pbm";

describe("pbm", () => {
  it("parses host P4 base64 and builds a bmp data url", () => {
    const b64 = photoFixtureSnapshot.art_pbm_base64;
    expect(b64).toBeTruthy();
    const bmp = parsePbmBase64(b64!);
    expect(bmp.width).toBe(200);
    expect(bmp.height).toBe(150);
    expect(bmp.bits.length).toBe(200 * 150);
    // gradient dither should use both black and white
    const blacks = bmp.bits.reduce((n, b) => n + b, 0);
    expect(blacks).toBeGreaterThan(100);
    expect(blacks).toBeLessThan(200 * 150 - 100);

    const url = pbmToBmpDataUrl(bmp);
    expect(url.startsWith("data:image/bmp;base64,")).toBe(true);
    expect(pbmBase64ToDataUrl(b64)).toBe(url);
  });

  it("null / invalid art yields null data url", () => {
    expect(pbmBase64ToDataUrl(null)).toBeNull();
    expect(pbmBase64ToDataUrl("!!!")).toBeNull();
  });
});
