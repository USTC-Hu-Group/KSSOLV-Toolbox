import { Vector3 } from 'three';
import { describe, expect, it } from 'vitest';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import {
  decodeValues,
  histogram,
  linearIndex,
  sampleTrilinear,
  worldToGrid,
} from './gridMath';

const grid: VolumeGridSpec = {
  dimensionality: 3,
  dimensions: [3, 3, 3],
  origin: [2, -1, 4],
  voxelVectors: [
    [1, 0, 0],
    [0.5, 2, 0],
    [0.2, 0.3, 3],
  ],
  periodic: [false, false, false],
  indexOrder: 'x-fastest',
  sampling: 'point-inclusive',
};

describe('volume grid math', () => {
  it('maps skew-grid world points back to exact voxel coordinates', () => {
    const point = worldToGrid(grid, new Vector3(4.4, 3.6, 10));
    expect(point.x).toBeCloseTo(1, 12);
    expect(point.y).toBeCloseTo(2, 12);
    expect(point.z).toBeCloseTo(2, 12);
  });

  it('interpolates a linear scalar field exactly', () => {
    const values = new Float32Array(27);
    for (let z = 0; z < 3; z += 1)
      for (let y = 0; y < 3; y += 1)
        for (let x = 0; x < 3; x += 1)
          values[linearIndex(grid.dimensions, x, y, z)] = x + 2 * y + 3 * z;
    expect(sampleTrilinear(values, grid.dimensions, new Vector3(0.25, 1.5, 0.75))).toBeCloseTo(
      5.5,
      12,
    );
  });

  it('builds a deterministic histogram including the maximum endpoint', () => {
    expect(Array.from(histogram(new Float32Array([0, 0.5, 1]), 0, 1, 2))).toEqual([1, 2]);
  });

  it('counts every finite voxel and ignores only the NaN mask', () => {
    const counts = histogram(new Float32Array([0, 0.2, Number.NaN, 0.8, 1]), 0, 1, 4);
    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(4);
  });

  it('decodes little-endian uint16 linear quantization within one step', () => {
    const buffer = new ArrayBuffer(6);
    const view = new DataView(buffer);
    view.setUint16(0, 0, true);
    view.setUint16(2, 32768, true);
    view.setUint16(4, 65535, true);
    const scale = 4 / 65535;
    const values = decodeValues(buffer, 'uint16-linear-le', scale, -2);

    expect(Array.from(values)).toEqual([
      -2,
      expect.closeTo(0.0000305, 6),
      2,
    ]);
  });
});
