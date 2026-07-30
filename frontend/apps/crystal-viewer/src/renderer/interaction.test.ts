import { describe, expect, it } from 'vitest';

import { exceedsDragThreshold, viewerInteractionProfile } from './interaction';

describe('viewer interaction profile', () => {
  it('uses deliberate free-rotation mouse sensitivities', () => {
    expect(viewerInteractionProfile.rotateSpeed).toBeGreaterThan(1);
    expect(viewerInteractionProfile.rotateSpeed).toBeLessThan(2);
    expect(viewerInteractionProfile.zoomSpeed).toBeGreaterThan(1);
    expect(viewerInteractionProfile.zoomSpeed).toBeLessThan(1.5);
    expect(viewerInteractionProfile.freeRotation).toBe(true);
    expect(viewerInteractionProfile.minZoom).toBeGreaterThan(0);
    expect(viewerInteractionProfile.maxZoom).toBeGreaterThan(1);
  });

  it('distinguishes a click from an orbit or pan drag', () => {
    expect(exceedsDragThreshold(10, 10, 12, 12)).toBe(false);
    expect(exceedsDragThreshold(10, 10, 15, 10)).toBe(true);
  });
});
