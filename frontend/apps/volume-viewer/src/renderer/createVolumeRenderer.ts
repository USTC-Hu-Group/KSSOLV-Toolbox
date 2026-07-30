import { CanvasVolumeFallback } from './CanvasVolumeFallback';
import { VolumeRenderer } from './VolumeRenderer';
import type {
  VolumeProbe,
  VolumeRendererApi,
} from './VolumeRendererApi';

export const createVolumeRenderer = (
  container: HTMLElement,
  onProbe: (probe?: VolumeProbe) => void,
  onStatus: (
    phase: 'ready' | 'building' | 'error',
    message: string,
  ) => void,
): VolumeRendererApi => {
  const query = new URLSearchParams(window.location.search);
  const forceCanvasFallback =
    query.has('kssolvTest') && query.has('kssolvForceCanvas');
  if (forceCanvasFallback) {
    return new CanvasVolumeFallback(
      container,
      onStatus,
      'Canvas2D fallback forced by the acceptance harness.',
    );
  }
  const probe = document.createElement('canvas');
  const probeContext = probe.getContext('webgl2');
  if (!probeContext) {
    return new CanvasVolumeFallback(
      container,
      onStatus,
      'WebGL2 is unavailable.',
    );
  }
  probeContext.getExtension('WEBGL_lose_context')?.loseContext();
  try {
    return new VolumeRenderer(container, onProbe, onStatus);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return new CanvasVolumeFallback(
      container,
      onStatus,
      `WebGL renderer creation failed: ${detail}.`,
    );
  }
};
