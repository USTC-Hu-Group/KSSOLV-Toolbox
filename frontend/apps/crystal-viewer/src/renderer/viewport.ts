export interface ViewportLayout {
  main: { width: number; height: number };
  axes: { x: number; y: number; size: number };
}

/**
 * Build viewport dimensions in CSS pixels.
 *
 * Three.js applies WebGLRenderer.pixelRatio inside setViewport/setScissor.
 * These values must therefore never be derived from the physical
 * canvas.width/canvas.height drawing-buffer dimensions.
 */
export const viewportLayout = (width: number, height: number): ViewportLayout => ({
  main: { width, height },
  axes: {
    x: 18,
    y: 18,
    size: Math.min(118, height * 0.24),
  },
});
