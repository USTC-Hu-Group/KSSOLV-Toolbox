import { Vector3 } from 'three';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import type { SliceAxis, VolumeOptions } from '../state/volumeStore';
import { gridMatrix, linearIndex } from './gridMath';

export interface ScalarSlice {
  axis: SliceAxis;
  index: number;
  width: number;
  height: number;
  gridIndices: Uint32Array;
  worldCoordinates: Float64Array;
  values: Float32Array;
}

const selectedIndex = (
  dimensions: [number, number, number],
  axis: SliceAxis,
  requested: number,
): number => {
  const maximum = dimensions[axis === 'i' ? 0 : axis === 'j' ? 1 : 2] - 1;
  return Math.min(maximum, Math.max(0, Math.round(requested)));
};

/**
 * Extract a lattice-aligned scalar slice without changing the x-fastest
 * storage convention. Rows and columns match the displayed slice texture:
 * I -> columns J, rows K; J -> columns I, rows K; K -> columns I, rows J.
 */
export const extractScalarSlice = (
  values: Float32Array | Float64Array,
  grid: VolumeGridSpec,
  axis: SliceAxis,
  requestedIndex: number,
): ScalarSlice => {
  const dimensions = grid.dimensions;
  const expected = dimensions[0] * dimensions[1] * dimensions[2];
  if (values.length !== expected) {
    throw new Error(
      `Slice source has ${values.length} values; grid requires ${expected}.`,
    );
  }
  const index = selectedIndex(dimensions, axis, requestedIndex);
  const width = axis === 'i' ? dimensions[1] : dimensions[0];
  const height = axis === 'k' ? dimensions[1] : dimensions[2];
  const count = width * height;
  const gridIndices = new Uint32Array(count * 3);
  const worldCoordinates = new Float64Array(count * 3);
  const output = new Float32Array(count);
  const transform = gridMatrix(grid);
  const point = new Vector3();
  let offset = 0;
  for (let row = 0; row < height; row += 1) {
    for (let column = 0; column < width; column += 1) {
      const i = axis === 'i' ? index : column;
      const j = axis === 'i' ? column : axis === 'j' ? index : row;
      const k = axis === 'k' ? index : row;
      const base = offset * 3;
      gridIndices.set([i, j, k], base);
      point.set(i, j, k).applyMatrix4(transform);
      worldCoordinates.set([point.x, point.y, point.z], base);
      output[offset] = values[linearIndex(dimensions, i, j, k)];
      offset += 1;
    }
  }
  return {
    axis,
    index,
    width,
    height,
    gridIndices,
    worldCoordinates,
    values: output,
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
