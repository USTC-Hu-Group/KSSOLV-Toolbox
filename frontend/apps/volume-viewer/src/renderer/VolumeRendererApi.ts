import type { VolumeChannelSpec, VolumeSceneSpec } from '@kssolv/volume-scene';
import type { CrystalCameraAxis } from '@kssolv/three-scene';

import type { VolumeOptions } from '../state/volumeStore';

export interface VolumeProbe {
  world: [number, number, number];
  grid: [number, number, number];
  value: number;
}

export type IsosurfaceExportFormat = 'gltf' | 'glb' | 'ply' | 'stl';

export interface VolumeRendererDiagnostics {
  contextLost: boolean;
  geometries: number;
  textures: number;
  programs: number;
}

export interface VolumeRendererApi {
  readonly backend: 'webgl2' | 'canvas2d';
  setScene(
    scene: VolumeSceneSpec,
    channel: VolumeChannelSpec,
    buffer: ArrayBuffer,
    options: VolumeOptions,
    preserveCamera?: boolean,
  ): void;
  setOptions(options: VolumeOptions): void;
  centerView(): void;
  resetView(): void;
  setCameraAxis(axis: CrystalCameraAxis): void;
  screenshot(scale?: number): string;
  exportIsosurface(
    format: IsosurfaceExportFormat,
  ): Promise<{ data: ArrayBuffer | string; mime: string }>;
  exportSliceCsv(): string;
  exportSlicePng(): string;
  orbitForAcceptance(deltaRadians: number): void;
  loseContextForAcceptance(): boolean;
  restoreContextForAcceptance(): boolean;
  diagnostics(): VolumeRendererDiagnostics;
  dispose(): void;
}
