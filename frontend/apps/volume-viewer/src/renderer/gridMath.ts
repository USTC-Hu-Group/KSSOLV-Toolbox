import { Box3, Matrix4, Vector3 } from 'three';

import type {
  VolumeGridSpec,
  VolumeValueEncoding,
} from '@kssolv/volume-scene';

export const gridMatrix = (grid: VolumeGridSpec): Matrix4 => {
  const [a, b, c] = grid.voxelVectors;
  const [x, y, z] = grid.origin;
  return new Matrix4().set(
    a[0],
    b[0],
    c[0],
    x,
    a[1],
    b[1],
    c[1],
    y,
    a[2],
    b[2],
    c[2],
    z,
    0,
    0,
    0,
    1,
  );
};

export const gridBounds = (grid: VolumeGridSpec): Box3 => {
  const matrix = gridMatrix(grid);
  const [nx, ny, nz] = grid.dimensions;
  const bounds = new Box3();
  for (const x of [-0.5, nx - 0.5]) {
    for (const y of [-0.5, ny - 0.5]) {
      for (const z of [-0.5, nz - 0.5]) {
        bounds.expandByPoint(new Vector3(x, y, z).applyMatrix4(matrix));
      }
    }
  }
  return bounds;
};

export const worldToGrid = (grid: VolumeGridSpec, world: Vector3): Vector3 =>
  world.clone().applyMatrix4(gridMatrix(grid).invert());

export const linearIndex = (
  dimensions: readonly number[],
  x: number,
  y: number,
  z: number,
): number => x + dimensions[0] * (y + dimensions[1] * z);

export const sampleTrilinear = (
  values: Float32Array | Float64Array,
  dimensions: readonly number[],
  point: Vector3,
): number => {
  const [nx, ny, nz] = dimensions;
  const x = Math.min(nx - 1, Math.max(0, point.x));
  const y = Math.min(ny - 1, Math.max(0, point.y));
  const z = Math.min(nz - 1, Math.max(0, point.z));
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const z0 = Math.floor(z);
  const x1 = Math.min(nx - 1, x0 + 1);
  const y1 = Math.min(ny - 1, y0 + 1);
  const z1 = Math.min(nz - 1, z0 + 1);
  const tx = x - x0;
  const ty = y - y0;
  const tz = z - z0;
  const value = (ix: number, iy: number, iz: number) =>
    values[linearIndex(dimensions, ix, iy, iz)];
  const c00 = value(x0, y0, z0) * (1 - tx) + value(x1, y0, z0) * tx;
  const c10 = value(x0, y1, z0) * (1 - tx) + value(x1, y1, z0) * tx;
  const c01 = value(x0, y0, z1) * (1 - tx) + value(x1, y0, z1) * tx;
  const c11 = value(x0, y1, z1) * (1 - tx) + value(x1, y1, z1) * tx;
  const c0 = c00 * (1 - ty) + c10 * ty;
  const c1 = c01 * (1 - ty) + c11 * ty;
  return c0 * (1 - tz) + c1 * tz;
};

export const histogram = (
  values: Float32Array | Float64Array,
  minimum: number,
  maximum: number,
  bins = 80,
): Uint32Array => {
  const counts = new Uint32Array(bins);
  const span = Math.max(maximum - minimum, Number.EPSILON);
  for (let sample = 0; sample < values.length; sample += 1) {
    const value = values[sample];
    if (!Number.isFinite(value)) continue;
    const index = Math.min(bins - 1, Math.max(0, Math.floor(((value - minimum) / span) * bins)));
    counts[index] += 1;
  }
  return counts;
};

export const decodeValues = (
  buffer: ArrayBuffer,
  encoding: VolumeValueEncoding,
  scale = 1,
  offset = 0,
): Float32Array | Float64Array => {
  if (encoding === 'float32-le') return new Float32Array(buffer);
  if (encoding === 'float64-le') return new Float64Array(buffer);
  const source = new DataView(buffer);
  const values = new Float32Array(buffer.byteLength / 2);
  for (let index = 0; index < values.length; index += 1) {
    values[index] = source.getUint16(index * 2, true) * scale + offset;
  }
  return values;
};
