import { describe, expect, it } from 'vitest';

import { decodeValues } from './gridMath';
import { marchingTetrahedra, wrapPeriodicGrid } from './isosurface';

describe('marching tetrahedra', () => {
  it('approximates an analytic sphere without degenerate triangles', () => {
    const dimensions = [25, 25, 25] as const;
    const values = new Float32Array(dimensions[0] * dimensions[1] * dimensions[2]);
    let offset = 0;
    for (let z = 0; z < dimensions[2]; z += 1)
      for (let y = 0; y < dimensions[1]; y += 1)
        for (let x = 0; x < dimensions[0]; x += 1) {
          values[offset] = Math.hypot(x - 12, y - 12, z - 12) - 7;
          offset += 1;
        }
    const result = marchingTetrahedra(values, dimensions, 0);
    expect(result.truncated).toBe(false);
    expect(result.positions.length).toBeGreaterThan(10_000);
    for (let index = 0; index < result.positions.length; index += 3) {
      const radius = Math.hypot(
        result.positions[index] - 12,
        result.positions[index + 1] - 12,
        result.positions[index + 2] - 12,
      );
      expect(Math.abs(radius - 7)).toBeLessThan(0.12);
    }
    let correctlyOriented = 0;
    const triangles = result.positions.length / 9;
    for (let offset = 0; offset < result.positions.length; offset += 9) {
      const a = result.positions.slice(offset, offset + 3);
      const ux = result.positions[offset + 3] - a[0];
      const uy = result.positions[offset + 4] - a[1];
      const uz = result.positions[offset + 5] - a[2];
      const vx = result.positions[offset + 6] - a[0];
      const vy = result.positions[offset + 7] - a[1];
      const vz = result.positions[offset + 8] - a[2];
      const normal = [uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx];
      const center = [
        (a[0] + result.positions[offset + 3] + result.positions[offset + 6]) / 3 - 12,
        (a[1] + result.positions[offset + 4] + result.positions[offset + 7]) / 3 - 12,
        (a[2] + result.positions[offset + 5] + result.positions[offset + 8]) / 3 - 12,
      ];
      if (normal[0] * center[0] + normal[1] * center[1] + normal[2] * center[2] > 0) {
        correctlyOriented += 1;
      }
    }
    expect(correctlyOriented / triangles).toBeGreaterThan(0.99);
  });

  it('returns an empty mesh when the threshold is outside the range', () => {
    const result = marchingTetrahedra(new Float32Array(27), [3, 3, 3], 1);
    expect(result.positions).toHaveLength(0);
  });

  it('places a linear-field plane at the analytic location', () => {
    const dimensions = [9, 8, 7] as const;
    const values = new Float32Array(dimensions[0] * dimensions[1] * dimensions[2]);
    let offset = 0;
    for (let z = 0; z < dimensions[2]; z += 1)
      for (let y = 0; y < dimensions[1]; y += 1)
        for (let x = 0; x < dimensions[0]; x += 1) {
          values[offset] = x + 2 * y + 3 * z;
          offset += 1;
        }
    const result = marchingTetrahedra(values, dimensions, 14.5);
    for (let index = 0; index < result.positions.length; index += 3) {
      const value =
        result.positions[index] +
        2 * result.positions[index + 1] +
        3 * result.positions[index + 2];
      expect(Math.abs(value - 14.5)).toBeLessThan(1e-5);
    }
  });

  it(
    'extracts a sparse 128 cubed analytic field within the desktop budget',
    () => {
      const dimensions = [128, 128, 128] as const;
      const values = new Float32Array(dimensions[0] * dimensions[1] * dimensions[2]);
      let offset = 0;
      for (let z = 0; z < dimensions[2]; z += 1)
        for (let y = 0; y < dimensions[1]; y += 1)
          for (let x = 0; x < dimensions[0]; x += 1) {
            values[offset] = Math.hypot(x - 63.5, y - 63.5, z - 63.5) - 28;
            offset += 1;
          }
      const started = performance.now();
      const decoded = decodeValues(values.buffer, 'float32-le');
      if (!(decoded instanceof Float32Array)) {
        throw new Error('Float32 transport decoded to the wrong array type.');
      }
      const result = marchingTetrahedra(decoded, dimensions, 0);
      const elapsed = performance.now() - started;
      expect(result.positions.length).toBeGreaterThan(100_000);
      expect(elapsed).toBeLessThan(2_000);
    },
    5_000,
  );

  it('adds one wrapped terminal sample only on periodic axes', () => {
    const values = new Float32Array([
      1, 2,
      3, 4,
      5, 6,
      7, 8,
    ]);
    const wrapped = wrapPeriodicGrid(values, [2, 2, 2], [true, false, true]);
    expect(wrapped.dimensions).toEqual([3, 2, 3]);
    const index = (x: number, y: number, z: number) =>
      x + wrapped.dimensions[0] * (y + wrapped.dimensions[1] * z);
    expect(wrapped.values[index(2, 1, 2)]).toBe(values[2]);
  });
});
