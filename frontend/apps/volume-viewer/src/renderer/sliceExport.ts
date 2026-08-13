import { Matrix3, Vector3 } from 'three';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import type { VolumeOptions } from '../state/volumeStore';
import { gridMatrix, linearIndex, sampleTrilinear } from './gridMath';

export type MillerIndices = [number, number, number];

export interface ScalarSlice {
  millerIndices: MillerIndices;
  width: number;
  height: number;
  gridIndices: Float64Array;
  worldCoordinates: Float64Array;
  values: Float32Array;
  polygonGridCoordinates: Float32Array;
  polygonUvs: Float32Array;
}

const boxEdges = [
  [0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3],
  [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7],
] as const;

const clampSampleCount = (span: number, spacing: number): number =>
  Math.min(512, Math.max(2, Math.ceil(span / Math.max(spacing, 1e-12)) + 1));

const addUniquePoint = (points: Vector3[], candidate: Vector3, tolerance: number): void => {
  if (!points.some((point) => point.distanceToSquared(candidate) <= tolerance ** 2)) {
    points.push(candidate);
  }
};

/**
 * Extract the single central plane described by one Miller-index triplet.
 * The plane equation is h(u - 1/2) + k(v - 1/2) + l(w - 1/2) = 0, where
 * u/v/w are fractional coordinates across the sampled volume. This keeps the
 * chosen member of the Miller family visible while preserving its reciprocal-
 * lattice orientation for skew cells.
 */
export const extractMillerSlice = (
  values: Float32Array | Float64Array,
  grid: VolumeGridSpec,
  requestedMillerIndices: readonly number[],
  interpolation: VolumeOptions['interpolation'] = 'linear',
): ScalarSlice => {
  const dimensions = grid.dimensions;
  const expected = dimensions[0] * dimensions[1] * dimensions[2];
  if (values.length !== expected) {
    throw new Error(
      `Slice source has ${values.length} values; grid requires ${expected}.`,
    );
  }
  if (requestedMillerIndices.length !== 3) {
    throw new Error('A Miller plane requires exactly three indices.');
  }
  const millerIndices = requestedMillerIndices.map((value) => Math.round(value)) as MillerIndices;
  if (!millerIndices.every(Number.isFinite) || millerIndices.every((value) => value === 0)) {
    throw new Error('Miller indices must be finite integers and cannot all be zero.');
  }

  const maximum = dimensions.map((dimension) => Math.max(0, dimension - 1)) as MillerIndices;
  const center = new Vector3(maximum[0] / 2, maximum[1] / 2, maximum[2] / 2);
  const normalGrid = new Vector3(
    millerIndices[0] / Math.max(1, maximum[0]),
    millerIndices[1] / Math.max(1, maximum[1]),
    millerIndices[2] / Math.max(1, maximum[2]),
  );
  const corners: Vector3[] = [];
  for (let bits = 0; bits < 8; bits += 1) {
    corners.push(new Vector3(
      bits & 1 ? maximum[0] : 0,
      bits & 2 ? maximum[1] : 0,
      bits & 4 ? maximum[2] : 0,
    ));
  }
  const tolerance = Math.max(...maximum, 1) * 1e-9;
  const points: Vector3[] = [];
  for (const [firstIndex, secondIndex] of boxEdges) {
    const first = corners[firstIndex];
    const second = corners[secondIndex];
    const firstDistance = normalGrid.dot(first.clone().sub(center));
    const secondDistance = normalGrid.dot(second.clone().sub(center));
    if (Math.abs(firstDistance) <= tolerance) addUniquePoint(points, first, tolerance);
    if (Math.abs(secondDistance) <= tolerance) addUniquePoint(points, second, tolerance);
    if (firstDistance * secondDistance < 0) {
      addUniquePoint(
        points,
        first.clone().lerp(second, firstDistance / (firstDistance - secondDistance)),
        tolerance,
      );
    }
  }
  if (points.length < 3) {
    throw new Error(`Miller plane (${millerIndices.join(' ')}) does not form a slice.`);
  }

  const transform = gridMatrix(grid);
  const inverseTransform = transform.clone().invert();
  const normalWorld = normalGrid
    .clone()
    .applyMatrix3(new Matrix3().setFromMatrix4(transform).invert().transpose())
    .normalize();
  const reference = Math.abs(normalWorld.x) < 0.8
    ? new Vector3(1, 0, 0)
    : new Vector3(0, 1, 0);
  const horizontal = new Vector3().crossVectors(normalWorld, reference).normalize();
  const vertical = new Vector3().crossVectors(normalWorld, horizontal).normalize();
  const worldPoints = points.map((point) => point.clone().applyMatrix4(transform));
  const centroid = worldPoints
    .reduce((sum, point) => sum.add(point), new Vector3())
    .multiplyScalar(1 / worldPoints.length);
  const ordered = worldPoints
    .map((world, index) => ({
      grid: points[index],
      world,
      angle: Math.atan2(
        world.clone().sub(centroid).dot(vertical),
        world.clone().sub(centroid).dot(horizontal),
      ),
    }))
    .sort((left, right) => left.angle - right.angle);
  const horizontalCoordinates = ordered.map(({ world }) => world.dot(horizontal));
  const verticalCoordinates = ordered.map(({ world }) => world.dot(vertical));
  const minimumHorizontal = Math.min(...horizontalCoordinates);
  const maximumHorizontal = Math.max(...horizontalCoordinates);
  const minimumVertical = Math.min(...verticalCoordinates);
  const maximumVertical = Math.max(...verticalCoordinates);
  const horizontalSpan = maximumHorizontal - minimumHorizontal;
  const verticalSpan = maximumVertical - minimumVertical;
  const voxelSpacing = Math.min(
    ...grid.voxelVectors
      .map((vector) => new Vector3(...vector).length())
      .filter((length) => length > 1e-12),
  );
  const width = clampSampleCount(horizontalSpan, voxelSpacing);
  const height = clampSampleCount(verticalSpan, voxelSpacing);
  const count = width * height;
  const gridIndices = new Float64Array(count * 3);
  const worldCoordinates = new Float64Array(count * 3);
  const output = new Float32Array(count);
  const planeDistance = centroid.dot(normalWorld);
  const world = new Vector3();
  const gridPoint = new Vector3();
  let offset = 0;
  for (let row = 0; row < height; row += 1) {
    for (let column = 0; column < width; column += 1) {
      const horizontalCoordinate = minimumHorizontal + horizontalSpan * column / (width - 1);
      const verticalCoordinate = minimumVertical + verticalSpan * row / (height - 1);
      world
        .copy(horizontal)
        .multiplyScalar(horizontalCoordinate)
        .addScaledVector(vertical, verticalCoordinate)
        .addScaledVector(normalWorld, planeDistance);
      gridPoint.copy(world).applyMatrix4(inverseTransform);
      const base = offset * 3;
      gridIndices.set([gridPoint.x, gridPoint.y, gridPoint.z], base);
      worldCoordinates.set([world.x, world.y, world.z], base);
      const inside = [gridPoint.x, gridPoint.y, gridPoint.z].every(
        (coordinate, axis) => coordinate >= -tolerance && coordinate <= maximum[axis] + tolerance,
      );
      if (!inside) {
        output[offset] = Number.NaN;
      } else if (interpolation === 'nearest') {
        const [i, j, k] = [gridPoint.x, gridPoint.y, gridPoint.z].map(
          (coordinate, axis) => Math.min(maximum[axis], Math.max(0, Math.round(coordinate))),
        );
        output[offset] = values[linearIndex(dimensions, i, j, k)];
      } else {
        output[offset] = sampleTrilinear(values, dimensions, gridPoint);
      }
      offset += 1;
    }
  }

  const polygonGridCoordinates = new Float32Array(ordered.length * 3);
  const polygonUvs = new Float32Array(ordered.length * 2);
  ordered.forEach(({ grid: point, world: worldPoint }, index) => {
    polygonGridCoordinates.set([point.x, point.y, point.z], index * 3);
    polygonUvs.set([
      (worldPoint.dot(horizontal) - minimumHorizontal) / horizontalSpan,
      (worldPoint.dot(vertical) - minimumVertical) / verticalSpan,
    ], index * 2);
  });
  return {
    millerIndices,
    width,
    height,
    gridIndices,
    worldCoordinates,
    values: output,
    polygonGridCoordinates,
    polygonUvs,
  };
};

export const encodeSliceCsv = (slice: ScalarSlice): string => {
  const rows = ['i,j,k,x_angstrom,y_angstrom,z_angstrom,value'];
  for (let offset = 0; offset < slice.values.length; offset += 1) {
    const base = offset * 3;
    rows.push(
      [
        slice.gridIndices[base],
        slice.gridIndices[base + 1],
        slice.gridIndices[base + 2],
        slice.worldCoordinates[base],
        slice.worldCoordinates[base + 1],
        slice.worldCoordinates[base + 2],
        slice.values[offset],
      ].join(','),
    );
  }
  return `${rows.join('\n')}\n`;
};

const palettes: Record<VolumeOptions['colormap'], number[][]> = {
  viridis: [
    [68, 1, 84],
    [33, 145, 140],
    [253, 231, 37],
  ],
  coolwarm: [
    [59, 76, 192],
    [245, 245, 245],
    [180, 4, 38],
  ],
  density: [
    [4, 12, 35],
    [52, 130, 164],
    [255, 224, 54],
  ],
};

const paletteColor = (
  fraction: number,
  colormap: VolumeOptions['colormap'],
): [number, number, number] => {
  const stops = palettes[colormap];
  const scaled = Math.min(1, Math.max(0, fraction)) * (stops.length - 1);
  const lower = Math.min(stops.length - 2, Math.floor(scaled));
  const local = scaled - lower;
  return [0, 1, 2].map((component) =>
    Math.round(
      stops[lower][component] * (1 - local) +
        stops[lower + 1][component] * local,
    ),
  ) as [number, number, number];
};

export const sliceRgba = (
  slice: ScalarSlice,
  minimum: number,
  maximum: number,
  colormap: VolumeOptions['colormap'],
): Uint8ClampedArray => {
  if (!Number.isFinite(minimum) || !Number.isFinite(maximum) || minimum >= maximum) {
    throw new Error('Slice PNG range must contain two finite increasing values.');
  }
  const rgba = new Uint8ClampedArray(slice.values.length * 4);
  const range = maximum - minimum;
  for (let index = 0; index < slice.values.length; index += 1) {
    const value = slice.values[index];
    const base = index * 4;
    if (!Number.isFinite(value)) {
      rgba[base + 3] = 0;
      continue;
    }
    const color = paletteColor((value - minimum) / range, colormap);
    rgba.set([...color, 255], base);
  }
  return rgba;
};

const minimumSlicePngLongEdge = 512;

export const slicePngDimensions = (
  slice: Pick<ScalarSlice, 'width' | 'height'>,
  scale: 1 | 1.5 | 2,
): { width: number; height: number } => {
  const sourceLongEdge = Math.max(slice.width, slice.height, 1);
  const outputLongEdge =
    Math.max(sourceLongEdge, minimumSlicePngLongEdge) * scale;
  return {
    width: Math.max(
      1,
      Math.round((slice.width / sourceLongEdge) * outputLongEdge),
    ),
    height: Math.max(
      1,
      Math.round((slice.height / sourceLongEdge) * outputLongEdge),
    ),
  };
};

export const encodeSlicePng = (
  slice: ScalarSlice,
  minimum: number,
  maximum: number,
  colormap: VolumeOptions['colormap'],
  scale: 1 | 1.5 | 2,
): string => {
  const source = document.createElement('canvas');
  source.width = slice.width;
  source.height = slice.height;
  const sourceContext = source.getContext('2d');
  if (!sourceContext) throw new Error('Canvas 2D is unavailable for slice PNG export.');
  const image = sourceContext.createImageData(slice.width, slice.height);
  image.data.set(sliceRgba(slice, minimum, maximum, colormap));
  sourceContext.putImageData(image, 0, 0);

  const output = document.createElement('canvas');
  const dimensions = slicePngDimensions(slice, scale);
  output.width = dimensions.width;
  output.height = dimensions.height;
  const outputContext = output.getContext('2d');
  if (!outputContext) throw new Error('Canvas 2D is unavailable for slice PNG export.');
  outputContext.imageSmoothingEnabled = false;
  outputContext.drawImage(source, 0, 0, output.width, output.height);
  return output.toDataURL('image/png');
};
