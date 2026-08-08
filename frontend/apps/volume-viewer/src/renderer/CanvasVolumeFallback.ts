import type { VolumeChannelSpec, VolumeSceneSpec } from '@kssolv/volume-scene';
import type { CrystalCameraAxis } from '@kssolv/three-scene';

import type { VolumeOptions } from '../state/volumeStore';
import { appearanceScale } from '../themes';
import { decodeValues } from './gridMath';
import {
  encodeSliceCsv,
  encodeSlicePng,
  extractScalarSlice,
  sliceRgba,
} from './sliceExport';
import type {
  IsosurfaceExportFormat,
  VolumeRendererApi,
  VolumeRendererDiagnostics,
} from './VolumeRendererApi';

/**
 * Scientific 2D fallback for systems where WebGL2 cannot be created. It keeps
 * file inspection, lattice-aligned slices, CSV, and PNG usable instead of
 * leaving a blank uihtml document.
 */
export class CanvasVolumeFallback implements VolumeRendererApi {
  readonly backend = 'canvas2d' as const;
  private readonly canvas = document.createElement('canvas');
  private readonly context: CanvasRenderingContext2D;
  private readonly resizeObserver: ResizeObserver;
  private scene?: VolumeSceneSpec;
  private values?: Float32Array | Float64Array;
  private options?: VolumeOptions;

  constructor(
    private readonly container: HTMLElement,
    private readonly onStatus: (
      phase: 'ready' | 'building' | 'error',
      message: string,
    ) => void,
    reason: string,
  ) {
    const context = this.canvas.getContext('2d');
    if (!context) throw new Error('Neither WebGL2 nor Canvas2D is available.');
    this.context = context;
    this.canvas.className = 'volume-canvas-fallback';
    this.container.append(this.canvas);
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
    this.resize();
    this.onStatus(
      'ready',
      `${reason} Using the CPU lattice-slice fallback.`,
    );
  }

  setScene(
    scene: VolumeSceneSpec,
    channel: VolumeChannelSpec,
    buffer: ArrayBuffer,
    options: VolumeOptions,
  ): void {
    this.scene = scene;
    this.values = decodeValues(
      buffer,
      channel.transport.valueEncoding,
      channel.transport.scale,
      channel.transport.offset,
    );
    this.options = { ...options, mode: 'slices' };
    this.applyAppearance(options);
    this.render();
  }

  setOptions(options: VolumeOptions): void {
    this.options = { ...options, mode: 'slices' };
    this.applyAppearance(options);
    this.render();
  }

  centerView(): void {
    this.render();
  }

  resetView(): void {
    this.render();
  }

  setCameraAxis(_axis: CrystalCameraAxis): void {
    // A two-dimensional fallback has no orbiting camera.
  }

  screenshot(scale = 1.5): string {
    const output = document.createElement('canvas');
    output.width = Math.max(1, Math.round(this.canvas.width * scale));
    output.height = Math.max(1, Math.round(this.canvas.height * scale));
    const context = output.getContext('2d');
    if (!context) throw new Error('Canvas2D is unavailable for PNG export.');
    context.imageSmoothingEnabled = false;
    context.drawImage(this.canvas, 0, 0, output.width, output.height);
    return output.toDataURL('image/png');
  }

  async exportIsosurface(
    _format: IsosurfaceExportFormat,
  ): Promise<{ data: ArrayBuffer | string; mime: string }> {
    throw new Error(
      'Isosurface export requires WebGL2. Use slice PNG/CSV or a WebGL2-capable GPU.',
    );
  }

  exportSliceCsv(): string {
    return encodeSliceCsv(this.slice());
  }

  exportSlicePng(): string {
    const options = this.requiredOptions();
    return encodeSlicePng(
      this.slice(),
      options.rangeMinimum,
      options.rangeMaximum,
      options.colormap,
      options.pngScale,
    );
  }

  orbitForAcceptance(_deltaRadians: number): void {
    // A two-dimensional fallback has no orbiting camera.
  }

  loseContextForAcceptance(): boolean {
    return false;
  }

  restoreContextForAcceptance(): boolean {
    return false;
  }

  diagnostics(): VolumeRendererDiagnostics {
    return { contextLost: false, geometries: 0, textures: 0, programs: 0 };
  }

  dispose(): void {
    this.resizeObserver.disconnect();
    this.canvas.remove();
    this.scene = undefined;
    this.values = undefined;
    this.options = undefined;
  }

  private requiredOptions(): VolumeOptions {
    if (!this.options) throw new Error('No volume slice is available.');
    return this.options;
  }

  private applyAppearance(options: VolumeOptions): void {
    this.canvas.style.filter = `brightness(${appearanceScale(options.brightness)}) contrast(${appearanceScale(options.contrast)})`;
  }

  private slice() {
    if (!this.scene || !this.values || !this.options) {
      throw new Error('No volume slice is available.');
    }
    return extractScalarSlice(
      this.values,
      this.scene.grid,
      this.options.sliceAxis,
      this.options.sliceIndex,
    );
  }

  private resize(): void {
    this.canvas.width = Math.max(1, Math.round(this.container.clientWidth));
    this.canvas.height = Math.max(1, Math.round(this.container.clientHeight));
    this.render();
  }

  private render(): void {
    if (!this.scene || !this.values || !this.options) return;
    const slice = this.slice();
    const source = document.createElement('canvas');
    source.width = slice.width;
    source.height = slice.height;
    const context = source.getContext('2d');
    if (!context) throw new Error('Canvas2D is unavailable for slice rendering.');
    const image = context.createImageData(slice.width, slice.height);
    image.data.set(
      sliceRgba(
        slice,
        this.options.rangeMinimum,
        this.options.rangeMaximum,
        this.options.colormap,
      ),
    );
    context.putImageData(image, 0, 0);
    this.context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const scale = Math.min(
      this.canvas.width / slice.width,
      this.canvas.height / slice.height,
    );
    const width = Math.max(1, Math.round(slice.width * scale));
    const height = Math.max(1, Math.round(slice.height * scale));
    this.context.imageSmoothingEnabled = this.options.interpolation === 'linear';
    this.context.drawImage(
      source,
      Math.round((this.canvas.width - width) / 2),
      Math.round((this.canvas.height - height) / 2),
      width,
      height,
    );
    this.onStatus(
      'ready',
      'CPU lattice slice ready; WebGL2 representations are unavailable.',
    );
  }
}
