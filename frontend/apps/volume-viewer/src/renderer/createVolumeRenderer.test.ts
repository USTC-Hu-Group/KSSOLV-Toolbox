import { afterEach, describe, expect, it, vi } from 'vitest';

import { createVolumeRenderer } from './createVolumeRenderer';
import { createDebugVolume } from '../state/debugVolume';
import { defaultVolumeAppearance, type VolumeOptions } from '../state/volumeStore';

const options: VolumeOptions = {
  ...defaultVolumeAppearance(),
  mode: 'isosurface',
  isovalueMode: 'absolute',
  channelId: 'density',
  positiveThreshold: 0.2,
  negativeThreshold: -0.2,
  showPositive: true,
  showNegative: true,
  smoothIsosurface: true,
  periodicWrap: false,
  opacity: 0.7,
  colormap: 'coolwarm',
  rangeMinimum: -1,
  rangeMaximum: 1,
  sliceAxis: 'k',
  sliceIndex: 2,
  sliceIndices: [2, 2, 2],
  sliceVisibility: [true, true, true],
  interpolation: 'nearest',
  volumeQuality: 'balanced',
  gradientOpacity: 0.3,
  clipMinimum: [0, 0, 0],
  clipMaximum: [1, 1, 1],
  pngScale: 1,
  showAtoms: true,
  showBonds: true,
  showCell: true,
  showPolyhedra: true,
  showAxes: true,
};

afterEach(() => {
  vi.restoreAllMocks();
  window.history.replaceState({}, '', '/');
});

describe('volume renderer capability fallback', () => {
  it('keeps slices and exports available without WebGL2', async () => {
    const context = {
      clearRect: vi.fn(),
      createImageData: (width: number, height: number) =>
        ({
          data: new Uint8ClampedArray(width * height * 4),
          width,
          height,
        }) as ImageData,
      drawImage: vi.fn(),
      putImageData: vi.fn(),
      imageSmoothingEnabled: false,
    } as unknown as CanvasRenderingContext2D;
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(
      ((type: string) => (type === '2d' ? context : null)) as typeof HTMLCanvasElement.prototype.getContext,
    );
    vi.spyOn(HTMLCanvasElement.prototype, 'toDataURL').mockReturnValue(
      'data:image/png;base64,fallback',
    );
    const statuses: string[] = [];
    const renderer = createVolumeRenderer(
      document.createElement('div'),
      vi.fn(),
      (_phase, message) => statuses.push(message),
    );
    expect(renderer.backend).toBe('canvas2d');

    const { scene, buffer } = createDebugVolume();
    renderer.setScene(scene, scene.channels[0], buffer, options);
    expect(renderer.exportSliceCsv()).toMatch(
      /^i,j,k,x_angstrom,y_angstrom,z_angstrom,value/m,
    );
    expect(renderer.exportSlicePng()).toBe(
      'data:image/png;base64,fallback',
    );
    expect(statuses[statuses.length - 1]).toContain('CPU lattice slice ready');
    await expect(renderer.exportIsosurface('ply')).rejects.toThrow(
      /requires WebGL2/,
    );
    renderer.dispose();
  });

  it('allows the production acceptance harness to force Canvas2D', () => {
    window.history.replaceState(
      {},
      '',
      '/?kssolvTest=1&kssolvForceCanvas=1',
    );
    const context = {
      clearRect: vi.fn(),
      createImageData: (width: number, height: number) =>
        ({
          data: new Uint8ClampedArray(width * height * 4),
          width,
          height,
        }) as ImageData,
      drawImage: vi.fn(),
      putImageData: vi.fn(),
      imageSmoothingEnabled: false,
    } as unknown as CanvasRenderingContext2D;
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockImplementation(
      (() => context) as unknown as typeof HTMLCanvasElement.prototype.getContext,
    );
    const renderer = createVolumeRenderer(
      document.createElement('div'),
      vi.fn(),
      vi.fn(),
    );
    expect(renderer.backend).toBe('canvas2d');
    renderer.dispose();
  });
});
