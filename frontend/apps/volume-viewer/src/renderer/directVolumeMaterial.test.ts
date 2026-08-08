import { Data3DTexture, DataTexture, RedFormat } from 'three';
import { describe, expect, it } from 'vitest';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import { defaultVolumeAppearance, type VolumeOptions } from '../state/volumeStore';
import {
  createDirectVolumeMaterial,
  updateDirectVolumeMaterial,
} from './directVolumeMaterial';

const grid: VolumeGridSpec = {
  dimensionality: 3,
  dimensions: [4, 5, 6],
  origin: [0, 0, 0],
  voxelVectors: [
    [1, 0, 0],
    [0.2, 1, 0],
    [0, 0.1, 1],
  ],
  periodic: [false, false, false],
  indexOrder: 'x-fastest',
  sampling: 'point-inclusive',
};

const options: VolumeOptions = {
  ...defaultVolumeAppearance(),
  mode: 'volume',
  isovalueMode: 'absolute',
  channelId: 'density',
  positiveThreshold: 0.2,
  negativeThreshold: -0.2,
  showPositive: true,
  showNegative: true,
  smoothIsosurface: true,
  periodicWrap: false,
  opacity: 0.65,
  colormap: 'coolwarm',
  rangeMinimum: -2,
  rangeMaximum: 3,
  sliceAxis: 'k',
  sliceIndex: 2,
  sliceIndices: [2, 2, 2],
  sliceVisibility: [true, true, true],
  interpolation: 'linear',
  volumeQuality: 'high',
  gradientOpacity: 0.4,
  clipMinimum: [0.1, 0.2, 0.3],
  clipMaximum: [0.9, 0.8, 0.7],
  pngScale: 1.5,
  showAtoms: true,
  showBonds: true,
  showCell: true,
  showPolyhedra: true,
  showAxes: true,
};

describe('direct volume material', () => {
  it('carries range, clipping, gradient opacity, and quality uniforms', () => {
    const texture = new Data3DTexture(new Float32Array(4 * 5 * 6), 4, 5, 6);
    texture.format = RedFormat;
    const colormap = new DataTexture(new Uint8Array(256 * 4), 256, 1);
    const material = createDirectVolumeMaterial(texture, colormap, grid, options);

    expect(material.uniforms.u_size.value.toArray()).toEqual([4, 5, 6]);
    expect(material.uniforms.u_range.value.toArray()).toEqual([-2, 3]);
    expect(material.uniforms.u_clip_min.value.toArray()).toEqual([0.1, 0.2, 0.3]);
    expect(material.uniforms.u_clip_max.value.toArray()).toEqual([0.9, 0.8, 0.7]);
    expect(material.uniforms.u_gradient_opacity.value).toBe(0.4);
    expect(material.uniforms.u_step_size.value).toBe(0.42);
    expect(material.fragmentShader).toContain('const int MIN_STEPS = 64;');
    expect(material.fragmentShader).toContain(
      'if (step_count < MIN_STEPS) step_count = MIN_STEPS;',
    );
    expect(material.fragmentShader).toContain(
      'if (step_count > MAX_STEPS) step_count = MAX_STEPS;',
    );
    expect(material.fragmentShader).toContain('0.5 * step_vector');
    expect(material.fragmentShader).not.toContain(
      'max(0.15, length(step_vector))',
    );

    const updated: VolumeOptions = {
      ...options,
      rangeMinimum: -1,
      rangeMaximum: 7,
      opacity: 0.3,
      gradientOpacity: 0.8,
      volumeQuality: 'fast',
      clipMinimum: [0, 0.1, 0.2],
      clipMaximum: [1, 0.9, 0.8],
    };
    updateDirectVolumeMaterial(material, updated);
    expect(material.uniforms.u_data.value).toBe(texture);
    expect(material.uniforms.u_range.value.toArray()).toEqual([-1, 7]);
    expect(material.uniforms.u_opacity.value).toBe(0.3);
    expect(material.uniforms.u_gradient_opacity.value).toBe(0.8);
    expect(material.uniforms.u_clip_min.value.toArray()).toEqual([0, 0.1, 0.2]);
    expect(material.uniforms.u_clip_max.value.toArray()).toEqual([1, 0.9, 0.8]);

    material.dispose();
    texture.dispose();
    colormap.dispose();
  });
});
