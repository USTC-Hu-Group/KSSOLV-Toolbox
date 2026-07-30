import { ref } from 'vue';

import type { VolumeChannelSpec } from '@kssolv/volume-scene';

import type { VolumeRendererApi } from '../renderer/VolumeRendererApi';
import type { VolumeOptions } from './volumeStore';

export interface AcceptanceSoakProgress {
  running: boolean;
  done: boolean;
  iterations: number;
  contextCycles: number;
  elapsedMs: number;
  startHeap: number;
  currentHeap: number;
  geometries: number;
  textures: number;
  programs: number;
  frames: number;
  averageFps: number;
  minimumFps: number;
  errors: string[];
}

export interface AcceptanceSoakOptions {
  enabled: boolean;
  getRenderer: () => VolumeRendererApi | undefined;
  getChannel: () => VolumeChannelSpec | undefined;
  volumeOptions: VolumeOptions;
  reportError: (message: string) => void;
}

interface ChromiumPerformance extends Performance {
  memory?: { usedJSHeapSize: number };
}

const heapSize = (): number =>
  (performance as ChromiumPerformance).memory?.usedJSHeapSize ?? 0;

const initialProgress = (): AcceptanceSoakProgress => ({
  running: false,
  done: false,
  iterations: 0,
  contextCycles: 0,
  elapsedMs: 0,
  startHeap: 0,
  currentHeap: 0,
  geometries: 0,
  textures: 0,
  programs: 0,
  frames: 0,
  averageFps: 0,
  minimumFps: 0,
  errors: [],
});

export const useAcceptanceSoak = (options: AcceptanceSoakOptions) => {
  const progress = ref(initialProgress());
  let timer: number | undefined;
  let restoreTimer: number | undefined;
  let animationFrame: number | undefined;

  const loseContext = (): void => {
    if (!options.getRenderer()?.loseContextForAcceptance()) {
      options.reportError('WEBGL_lose_context is unavailable on this GPU.');
    }
  };

  const restoreContext = (): void => {
    if (!options.getRenderer()?.restoreContextForAcceptance()) {
      options.reportError('No test context is waiting to be restored.');
    }
  };

  const recordError = (event: ErrorEvent | PromiseRejectionEvent): void => {
    if (!options.enabled) return;
    const value =
      'reason' in event ? event.reason : event.error ?? event.message;
    progress.value.errors.push(
      value instanceof Error ? value.message : String(value),
    );
  };

  const stop = (): void => {
    if (timer !== undefined) window.clearInterval(timer);
    if (restoreTimer !== undefined) window.clearTimeout(restoreTimer);
    if (animationFrame !== undefined) window.cancelAnimationFrame(animationFrame);
    timer = undefined;
    restoreTimer = undefined;
    animationFrame = undefined;
    progress.value.running = false;
    progress.value.done = true;
  };

  const start = (): void => {
    const renderer = options.getRenderer();
    if (!renderer || progress.value.running) return;
    const query = new URLSearchParams(window.location.search);
    const requested = Number(query.get('kssolvSoakMs') ?? 30 * 60 * 1000);
    const duration = Number.isFinite(requested)
      ? Math.max(10_000, Math.min(requested, 60 * 60 * 1000))
      : 30 * 60 * 1000;
    const started = performance.now();
    let frameWindowStarted = started;
    let frameWindowCount = 0;
    let minimumFps = Number.POSITIVE_INFINITY;
    progress.value = {
      ...initialProgress(),
      running: true,
      startHeap: heapSize(),
      currentHeap: heapSize(),
    };
    const animateOrbit = (now: number): void => {
      if (!progress.value.running) return;
      progress.value.frames += 1;
      frameWindowCount += 1;
      options.getRenderer()?.orbitForAcceptance(0.0015);
      const totalSeconds = Math.max((now - started) / 1_000, 1e-6);
      progress.value.averageFps = progress.value.frames / totalSeconds;
      const windowSeconds = (now - frameWindowStarted) / 1_000;
      if (windowSeconds >= 1) {
        const fps = frameWindowCount / windowSeconds;
        minimumFps = Math.min(minimumFps, fps);
        progress.value.minimumFps = minimumFps;
        frameWindowStarted = now;
        frameWindowCount = 0;
      }
      animationFrame = window.requestAnimationFrame(animateOrbit);
    };
    animationFrame = window.requestAnimationFrame(animateOrbit);
    timer = window.setInterval(() => {
      const activeRenderer = options.getRenderer();
      if (!activeRenderer) {
        progress.value.errors.push('Renderer disappeared during soak.');
        stop();
        return;
      }
      const state = progress.value;
      state.iterations += 1;
      state.elapsedMs = performance.now() - started;
      state.currentHeap = heapSize();
      const diagnostics = activeRenderer.diagnostics();
      state.geometries = diagnostics.geometries;
      state.textures = diagnostics.textures;
      state.programs = diagnostics.programs;
      const channel = options.getChannel();
      if (channel) {
        const fraction = (state.iterations % 101) / 100;
        options.volumeOptions.positiveThreshold =
          Math.max(0, channel.minimum) +
          (channel.maximum - Math.max(0, channel.minimum)) *
            (0.08 + 0.72 * fraction);
      }
      if (state.iterations % 60 === 0) activeRenderer.resetView();
      if (
        state.iterations % 600 === 0 &&
        activeRenderer.loseContextForAcceptance()
      ) {
        state.contextCycles += 1;
        restoreTimer = window.setTimeout(() => {
          options.getRenderer()?.restoreContextForAcceptance();
          restoreTimer = undefined;
        }, 220);
      }
      if (state.elapsedMs >= duration) stop();
    }, 500);
  };

  return {
    progress,
    loseContext,
    restoreContext,
    recordError,
    start,
    stop,
  };
};
