import { Mesh } from 'three';
import { describe, expect, it, vi } from 'vitest';

import type { VolumeChannelSpec, VolumeGridSpec } from '@kssolv/volume-scene';

import { defaultVolumeAppearance, type VolumeOptions } from '../state/volumeStore';
import { VolumeLayer } from './VolumeLayer';

const grid: VolumeGridSpec = {
  dimensionality: 3,
  dimensions: [4, 5, 6],
  origin: [0, 0, 0],
  voxelVectors: [
    [1, 0, 0],
    [0, 1, 0],
    [0, 0, 1],
  ],
  periodic: [false, false, false],
  indexOrder: 'x-fastest',
  sampling: 'point-inclusive',
};

const channel: VolumeChannelSpec = {
  id: 'density',
  label: 'Density',
  units: 'a.u.',
  signed: false,
  minimum: 0,
  maximum: 119,
  mean: 59.5,
  standardDeviation: 1,
  integral: null,
  transport: {
    transferId: 'density',
    valueEncoding: 'float32-le',
    elementCount: 120,
    byteLength: 480,
    crc32: 0,
  },
};

const options: VolumeOptions = {
  ...defaultVolumeAppearance(),
  mode: 'slices',
  isovalueMode: 'absolute',
  channelId: 'density',
  positiveThreshold: 1,
  negativeThreshold: -1,
  showPositive: true,
  showNegative: false,
  smoothIsosurface: true,
  periodicWrap: false,
  opacity: 1,
  colormap: 'viridis',
  rangeMinimum: 0,
  rangeMaximum: 119,
  sliceAxis: 'k',
  sliceIndex: 3,
  sliceIndices: [1, 2, 3],
  sliceVisibility: [true, true, true],
  interpolation: 'nearest',
  volumeQuality: 'balanced',
  gradientOpacity: 0,
  clipMinimum: [0, 0, 0],
  clipMaximum: [1, 1, 1],
  pngScale: 1,
  showAtoms: false,
  showBonds: false,
  showCell: false,
  showPolyhedra: false,
  showAxes: false,
};

describe('orthogonal slice layer', () => {
  it('creates independently positioned I, J, and K planes', () => {
    const status = vi.fn();
    const layer = new VolumeLayer(
      grid,
      channel,
      Float32Array.from({ length: 120 }, (_, index) => index),
      options,
      status,
    );
    const planes = layer.children.filter(
      (child): child is Mesh => child instanceof Mesh && child !== layer.probeMesh,
    );

    expect(planes).toHaveLength(3);
    expect(new Set(Array.from(planes[0].geometry.getAttribute('position').array).filter((_, index) => index % 3 === 0))).toEqual(new Set([1]));
    expect(new Set(Array.from(planes[1].geometry.getAttribute('position').array).filter((_, index) => index % 3 === 1))).toEqual(new Set([2]));
    expect(new Set(Array.from(planes[2].geometry.getAttribute('position').array).filter((_, index) => index % 3 === 2))).toEqual(new Set([3]));
    expect(status).toHaveBeenLastCalledWith('ready', '3 orthogonal slices ready');

    layer.dispose();
  });

  it('shows any requested combination of planes', () => {
    const status = vi.fn();
    const layer = new VolumeLayer(
      grid,
      channel,
      new Float32Array(120),
      { ...options, sliceVisibility: [true, false, true] },
      status,
    );

    expect(layer.children.filter((child) => child !== layer.probeMesh)).toHaveLength(2);
    expect(status).toHaveBeenLastCalledWith('ready', '2 orthogonal slices ready');

    layer.dispose();
  });
});
