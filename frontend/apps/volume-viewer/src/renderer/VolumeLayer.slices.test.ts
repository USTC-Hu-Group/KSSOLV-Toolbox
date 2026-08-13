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
  millerIndices: [0, 0, 1],
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
  depthCueing: false,
  showBoundaryAtoms: false,
  showBondedOutside: false,
  hideIncompleteBonds: true,
  showMagmoms: false,
  showStatistics: false,
};

describe('Miller slice layer', () => {
  it('creates one plane from the complete Miller-index triplet', () => {
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

    expect(planes).toHaveLength(1);
    expect(new Set(Array.from(planes[0].geometry.getAttribute('position').array).filter((_, index) => index % 3 === 2))).toEqual(new Set([2.5]));
    expect(status).toHaveBeenLastCalledWith('ready', 'Miller plane (0 0 1) ready');

    layer.dispose();
  });

  it('uses all three indices to orient an oblique plane', () => {
    const status = vi.fn();
    const layer = new VolumeLayer(
      grid,
      channel,
      new Float32Array(120),
      { ...options, millerIndices: [1, 1, 1] },
      status,
    );

    const plane = layer.children.find((child) => child !== layer.probeMesh) as Mesh;
    const positions = Array.from(plane.geometry.getAttribute('position').array);
    for (let offset = 0; offset < positions.length; offset += 3) {
      expect(
        positions[offset] / 3 + positions[offset + 1] / 4 + positions[offset + 2] / 5,
      ).toBeCloseTo(1.5);
    }
    expect(layer.children.filter((child) => child !== layer.probeMesh)).toHaveLength(1);
    expect(status).toHaveBeenLastCalledWith('ready', 'Miller plane (1 1 1) ready');

    layer.dispose();
  });
});
