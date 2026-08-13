import { describe, expect, it } from 'vitest';

import {
  flipRgbaRows,
  imageExportExtension,
  rgbaToTiffBlob,
} from './imageExport';

describe('volume image export', () => {
  it('uses the same user-facing image extensions as structure rendering', () => {
    expect(
      ['png', 'jpeg', 'tiff', 'svg', 'pdf-vector', 'pdf-raster'].map((format) =>
        imageExportExtension(
          format as Parameters<typeof imageExportExtension>[0],
        ),
      ),
    ).toEqual(['png', 'jpg', 'tif', 'svg', 'pdf', 'pdf']);
  });

  it('flips WebGL pixels before producing a TIFF', () => {
    const rgba = new Uint8Array([
      1, 2, 3, 255,
      4, 5, 6, 255,
    ]);
    const flipped = flipRgbaRows(rgba, 1, 2);
    expect([...flipped]).toEqual([
      4, 5, 6, 255,
      1, 2, 3, 255,
    ]);
    expect(rgbaToTiffBlob(flipped, 1, 2).type).toBe('image/tiff');
  });
});
