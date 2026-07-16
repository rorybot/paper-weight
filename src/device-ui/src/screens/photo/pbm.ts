/**
 * Host ships Atkinson bitmaps as binary P4 PBM (base64).
 * Decode pure; render as BMP data URL (browsers + SSR-friendly img src).
 */

export type PbmBitmap = Readonly<{
  width: number;
  height: number;
  /** row-major, 1 = black, 0 = white */
  bits: Uint8Array;
}>;

const textDecoder = new TextDecoder();

/** Decode base64 → raw bytes without Node Buffer. */
export const decodeBase64 = (b64: string): Uint8Array => {
  const binary = atob(b64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
};

/**
 * Parse binary P4 PBM (optional comments). Set bit = black.
 */
export const parsePbm = (bytes: Uint8Array): PbmBitmap => {
  let i = 0;
  const skipWs = () => {
    while (i < bytes.length) {
      const c = bytes[i]!;
      if (c === 0x23) {
        // comment to EOL
        while (i < bytes.length && bytes[i] !== 0x0a) i += 1;
        if (i < bytes.length) i += 1;
        continue;
      }
      if (c === 0x20 || c === 0x09 || c === 0x0a || c === 0x0d) {
        i += 1;
        continue;
      }
      break;
    }
  };

  const readToken = (): string => {
    skipWs();
    const start = i;
    while (i < bytes.length) {
      const c = bytes[i]!;
      if (c === 0x20 || c === 0x09 || c === 0x0a || c === 0x0d || c === 0x23) break;
      i += 1;
    }
    return textDecoder.decode(bytes.subarray(start, i));
  };

  const magic = readToken();
  if (magic !== "P4") {
    throw new Error(`unsupported PBM magic: ${magic}`);
  }
  const width = Number(readToken());
  const height = Number(readToken());
  if (!Number.isFinite(width) || !Number.isFinite(height) || width < 1 || height < 1) {
    throw new Error("invalid PBM dimensions");
  }
  // single whitespace after height header
  if (i < bytes.length && (bytes[i] === 0x0a || bytes[i] === 0x20 || bytes[i] === 0x0d)) {
    i += 1;
  }

  const rowBytes = Math.ceil(width / 8);
  const need = rowBytes * height;
  if (i + need > bytes.length) {
    throw new Error("truncated PBM raster");
  }

  const bits = new Uint8Array(width * height);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const byte = bytes[i + y * rowBytes + (x >> 3)]!;
      const bit = (byte >> (7 - (x & 7))) & 1;
      bits[y * width + x] = bit;
    }
  }

  return Object.freeze({ width, height, bits });
};

export const parsePbmBase64 = (b64: string): PbmBitmap =>
  parsePbm(decodeBase64(b64));

/** Encode 1-bit PBM as 24-bit BMP data URL (black/cream-friendly BGR). */
export const pbmToBmpDataUrl = (
  bitmap: PbmBitmap,
  options?: Readonly<{ black?: [number, number, number]; white?: [number, number, number] }>,
): string => {
  const black = options?.black ?? [32, 33, 29];
  const white = options?.white ?? [243, 236, 217];
  const { width, height, bits } = bitmap;

  const rowStride = width * 3;
  const pad = (4 - (rowStride % 4)) % 4;
  const pixelSize = (rowStride + pad) * height;
  const fileSize = 54 + pixelSize;
  const out = new Uint8Array(fileSize);
  const view = new DataView(out.buffer);

  // BITMAPFILEHEADER
  out[0] = 0x42;
  out[1] = 0x4d;
  view.setUint32(2, fileSize, true);
  view.setUint32(10, 54, true);
  // BITMAPINFOHEADER
  view.setUint32(14, 40, true);
  view.setInt32(18, width, true);
  view.setInt32(22, height, true); // bottom-up
  view.setUint16(26, 1, true);
  view.setUint16(28, 24, true);
  view.setUint32(34, pixelSize, true);

  let o = 54;
  for (let y = height - 1; y >= 0; y -= 1) {
    for (let x = 0; x < width; x += 1) {
      const ink = bits[y * width + x] === 1 ? black : white;
      out[o++] = ink[2]!; // B
      out[o++] = ink[1]!; // G
      out[o++] = ink[0]!; // R
    }
    for (let p = 0; p < pad; p += 1) out[o++] = 0;
  }

  return `data:image/bmp;base64,${encodeBase64(out)}`;
};

export const pbmBase64ToDataUrl = (b64: string | null): string | null => {
  if (!b64) return null;
  try {
    return pbmToBmpDataUrl(parsePbmBase64(b64));
  } catch {
    return null;
  }
};

const encodeBase64 = (bytes: Uint8Array): string => {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
};
