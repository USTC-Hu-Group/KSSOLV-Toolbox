import { describe, expect, it } from 'vitest';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import {
  encodeSliceCsv,
  extractScalarSlice,
  slicePngDimensions,
  sliceRgba,
} from './sliceExport';

const grid: VolumeGridSpec = {
  dimensionality: 3,
  dimensions: [2, 3, 2],
  origin: [10, 20, 30],
  voxelVectors: [
    [2, 0, 0],
    [0.5, 3, 0],
    [0, 0.25, 4],
  ],
  periodic: [false, false, false],
  indexOrder: 'x-fastest',
  sampling: 'point-inclusive',
};
const values = Float32Array.from({ length: 12 }, (_, index) => index);

describe('scientific slice export', () => {
  it('preserves x-fastest order for every lattice axis', () => {
    expect([...extractScalarSlice(values, grid, 'i', 1).values]).toEqual([
      1, 3, 5, 7, 9, 11,
    ]);
    expect([...extractScalarSlice(values, grid, 'j', 1).values]).toEqual([
      2, 3, 8, 9,
    ]);
    expect([...extractScalarSlice(values, grid, 'k', 1).values]).toEqual([
      6, 7, 8, 9, 10, 11,
    ]);
  });

  it('exports non-orthogonal world coordinates and clamps the requested index', () => {
    const slice = extractScalarSlice(values, grid, 'k', 99);
    expect(slice.index).toBe(1);
    expect(slice.width).toBe(2);
    expect(slice.height).toBe(3);
    expect([...slice.worldCoordinates.slice(0, 6)]).toEqual([
      10, 20.25, 34, 12, 20.25, 34,
    ]);
    const csv = encodeSliceCsv(slice).trim().split('\n');
    expect(csv).toHaveLength(7);
    expect(csv[1]).toBe('0,0,1,10,20.25,34,6');
    expect(csv[6]).toBe('1,2,1,13,26.25,34,11');
  });

  it('maps finite values to opaque colors and masks non-finite samples', () => {
    const slice = extractScalarSlice(values, grid, 'j', 1);
    slice.values[1] = Number.NaN;
    const rgba = sliceRgba(slice, 0, 12, 'viridis');
    expect([...rgba.slice(0, 4)]).toEqual([56, 49, 103, 255]);
    expect([...rgba.slice(4, 8)]).toEqual([0, 0, 0, 0]);
    expect(() => sliceRgba(slice, 1, 1, 'density')).toThrow(/increasing/);
  });

  it('exports small slices at a useful resolution without changing aspect ratio', () => {
    expect(slicePngDimensions({ width: 2, height: 2 }, 1.5)).toEqual({
      width: 768,
      height: 768,
    });
    expect(slicePngDimensions({ width: 2, height: 3 }, 1)).toEqual({
      width: 341,
      height: 512,
    });
    expect(slicePngDimensions({ width: 1024, height: 512 }, 2)).toEqual({
      width: 2048,
      height: 1024,
    });
  });

  it('rejects sample arrays that do not match the grid dimensions', () => {
    expect(() => extractScalarSlice(new Float32Array(2), grid, 'k', 0)).toThrow(
      /grid requires 12/,
    );
  });

  it('extracts a 128 cubed interactive slice within 100 ms', () => {
    const dimensions = [128, 128, 128] as const;
    const largeGrid: VolumeGridSpec = {
      ...grid,
      dimensions: [...dimensions],
    };
    const largeValues = new Float32Array(
      dimensions[0] * dimensions[1] * dimensions[2],
    );
    const started = performance.now();
    const slice = extractScalarSlice(largeValues, largeGrid, 'k', 64);
    const elapsed = performance.now() - started;
    expect(slice.values).toHaveLength(128 * 128);
    expect(elapsed).toBeLessThan(100);
  });
});
