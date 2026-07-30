import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import type { VolumeChannelSpec } from '@kssolv/volume-scene';

import type { VolumeRendererApi } from '../renderer/VolumeRendererApi';
import type { VolumeOptions } from './volumeStore';
import { useAcceptanceSoak } from './useAcceptanceSoak';

const channel: VolumeChannelSpec = {
  id: 'rho',
  label: 'Density',
  units: 'e/Å³',
  signed: false,
  minimum: 0,
  maximum: 1,
  mean: 0.5,
  standardDeviation: 0.2,
  integral: 1,
  transport: {
    transferId: 'rho-transfer',
    valueEncoding: 'float32-le',
    elementCount: 8,
    byteLength: 32,
    crc32: 0,
  },
};

const volumeOptions = {
  positiveThreshold: 0.2,
} as VolumeOptions;

describe('acceptance soak driver', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    window.history.replaceState({}, '', '/?kssolvTest=1&kssolvSoakMs=10000');
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('records bounded production interactions and reaches a terminal state', async () => {
    const renderer = {
      diagnostics: () => ({
        contextLost: false,
        geometries: 7,
        textures: 2,
        programs: 3,
      }),
      resetView: vi.fn(),
      orbitForAcceptance: vi.fn(),
      loseContextForAcceptance: vi.fn(() => true),
      restoreContextForAcceptance: vi.fn(() => true),
    } as unknown as VolumeRendererApi;
    const soak = useAcceptanceSoak({
      enabled: true,
      getRenderer: () => renderer,
      getChannel: () => channel,
      volumeOptions,
      reportError: vi.fn(),
    });

    soak.start();
    await vi.advanceTimersByTimeAsync(10_500);
    expect(soak.progress.value.done).toBe(true);
    expect(soak.progress.value.iterations).toBe(20);
    expect(soak.progress.value.geometries).toBe(7);
    expect(soak.progress.value.textures).toBe(2);
    expect(soak.progress.value.frames).toBeGreaterThan(500);
    expect(soak.progress.value.averageFps).toBeGreaterThan(30);
    expect(renderer.orbitForAcceptance).toHaveBeenCalled();
    expect(soak.progress.value.errors).toEqual([]);
  });

  it('executes real context-loss hooks and records asynchronous failures', async () => {
    window.history.replaceState(
      {},
      '',
      '/?kssolvTest=1&kssolvSoakMs=301000',
    );
    const lose = vi.fn(() => true);
    const restore = vi.fn(() => true);
    const renderer = {
      diagnostics: () => ({
        contextLost: false,
        geometries: 1,
        textures: 1,
        programs: 1,
      }),
      resetView: vi.fn(),
      orbitForAcceptance: vi.fn(),
      loseContextForAcceptance: lose,
      restoreContextForAcceptance: restore,
    } as unknown as VolumeRendererApi;
    const soak = useAcceptanceSoak({
      enabled: true,
      getRenderer: () => renderer,
      getChannel: () => channel,
      volumeOptions,
      reportError: vi.fn(),
    });
    soak.start();
    await vi.advanceTimersByTimeAsync(300_500);
    expect(lose).toHaveBeenCalledTimes(1);
    expect(restore).toHaveBeenCalledTimes(1);
    expect(soak.progress.value.contextCycles).toBe(1);

    soak.recordError(
      { reason: new Error('injected failure') } as PromiseRejectionEvent,
    );
    expect(soak.progress.value.errors).toEqual(['injected failure']);
    soak.stop();
  });
});
