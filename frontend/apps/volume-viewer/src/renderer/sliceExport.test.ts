import { describe, expect, it } from 'vitest';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import {
  encodeSliceCsv,
  extractMillerSlice,
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
  it('uses the complete Miller-index triplet to make one central plane', () => {
    const slice = extractMillerSlice(values, grid, [1, 1, 1]);
    expect(slice.millerIndices).toEqual([1, 1, 1]);
    expect(slice.polygonGridCoordinates.length / 3).toBeGreaterThanOrEqual(3);
    for (let offset = 0; offset < slice.polygonGridCoordinates.length; offset += 3) {
      const [i, j, k] = slice.polygonGridCoordinates.slice(offset, offset + 3);
      expect(i / 1 + j / 2 + k / 1).toBeCloseTo(1.5);
    }
  });

  it('exports fractional grid and non-orthogonal world coordinates', () => {
    const slice = extractMillerSlice(values, grid, [0, 0, 1]);
    const finiteSample = slice.values.findIndex(Number.isFinite);
    expect(finiteSample).toBeGreaterThanOrEqual(0);
    const base = finiteSample * 3;
    expect(slice.gridIndices[base + 2]).toBeCloseTo(0.5);
    expect(slice.worldCoordinates[base]).toBeCloseTo(
      10 + slice.gridIndices[base] * 2 + slice.gridIndices[base + 1] * 0.5,
    );
    expect(slice.worldCoordinates[base + 1]).toBeCloseTo(
      20 + slice.gridIndices[base + 1] * 3 + slice.gridIndices[base + 2] * 0.25,
    );
    expect(slice.worldCoordinates[base + 2]).toBeCloseTo(32);
    const csv = encodeSliceCsv(slice).trim().split('\n');
    expect(csv).toHaveLength(slice.values.length + 1);
    expect(csv[0]).toBe('i,j,k,x_angstrom,y_angstrom,z_angstrom,value');
  });

  it('maps finite values to opaque colors and masks non-finite samples', () => {
    const slice = extractMillerSlice(values, grid, [0, 1, 0]);
    const finiteIndex = slice.values.findIndex(Number.isFinite);
    expect(finiteIndex).toBeGreaterThanOrEqual(0);
    const maskedIndex = finiteIndex === 0 ? 1 : 0;
    slice.values[maskedIndex] = Number.NaN;
    const rgba = sliceRgba(slice, 0, 12, 'viridis');
    expect(rgba[finiteIndex * 4 + 3]).toBe(255);
    expect([...rgba.slice(maskedIndex * 4, maskedIndex * 4 + 4)]).toEqual([0, 0, 0, 0]);
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
    expect(() => extractMillerSlice(new Float32Array(2), grid, [0, 0, 1])).toThrow(
      /grid requires 12/,
    );
    expect(() => extractMillerSlice(values, grid, [0, 0, 0])).toThrow(/cannot all be zero/);
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
    const slice = extractMillerSlice(largeValues, largeGrid, [0, 0, 1]);
    const elapsed = performance.now() - started;
    expect(slice.values.length).toBeGreaterThanOrEqual(128 * 128);
    expect(slice.values.length).toBeLessThanOrEqual(512 * 512);
    expect(elapsed).toBeLessThan(100);
  });
});
