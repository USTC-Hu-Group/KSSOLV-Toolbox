import { describe, expect, it } from 'vitest';

import { OrthographicCamera } from 'three';

import {
  autoRotationAngle,
  exceedsDragThreshold,
  orthographicPanOffset,
  viewerInteractionProfile,
} from './interaction';

describe('viewer interaction profile', () => {
  it('uses deliberate free-rotation mouse sensitivities', () => {
    expect(viewerInteractionProfile.rotateSpeed).toBeGreaterThan(1);
    expect(viewerInteractionProfile.rotateSpeed).toBeLessThan(2);
    expect(viewerInteractionProfile.zoomSpeed).toBe(6);
    expect(viewerInteractionProfile.freeRotation).toBe(true);
    expect(viewerInteractionProfile.minZoom).toBeGreaterThan(0);
    expect(viewerInteractionProfile.maxZoom).toBeGreaterThan(1);
  });

  it('maps right-button pan deltas to the same number of screen pixels', () => {
    const camera = new OrthographicCamera(-5, 5, 5, -5, 0.1, 100);
    camera.position.set(0, 0, 10);
    camera.lookAt(0, 0, 0);
    camera.updateMatrixWorld(true);

    expect(orthographicPanOffset(camera, 1000, 500, 100, 50).toArray()).toEqual([-1, 1, 0]);
    camera.zoom = 2;
    expect(orthographicPanOffset(camera, 1000, 500, 100, 50).toArray()).toEqual([-0.5, 0.5, 0]);
  });

  it('distinguishes a click from an orbit or pan drag', () => {
    expect(exceedsDragThreshold(10, 10, 12, 12)).toBe(false);
    expect(exceedsDragThreshold(10, 10, 15, 10)).toBe(true);
  });

  it('auto-rotates in the reversed direction', () => {
    expect(autoRotationAngle(1)).toBe(-0.45);
    expect(autoRotationAngle(0)).toBe(-0);
  });
});
