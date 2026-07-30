import { MOUSE } from 'three';
import { describe, expect, it } from 'vitest';

import {
  configureViewerInteraction,
  viewerInteractionProfile,
} from './interaction';

describe('shared viewer interaction', () => {
  it('configures matching rotate, zoom, and right-button pan controls', () => {
    const controls = {
      rotateSpeed: 0,
      zoomSpeed: 0,
      panSpeed: 0,
      staticMoving: false,
      minZoom: 0,
      maxZoom: 0,
      mouseButtons: {
        LEFT: MOUSE.PAN,
        MIDDLE: MOUSE.ROTATE,
        RIGHT: MOUSE.DOLLY,
      },
    };

    configureViewerInteraction(controls);

    expect(controls).toMatchObject({
      rotateSpeed: viewerInteractionProfile.rotateSpeed,
      zoomSpeed: viewerInteractionProfile.zoomSpeed,
      panSpeed: viewerInteractionProfile.panSpeed,
      staticMoving: true,
      minZoom: viewerInteractionProfile.minZoom,
      maxZoom: viewerInteractionProfile.maxZoom,
      mouseButtons: {
        LEFT: MOUSE.ROTATE,
        MIDDLE: MOUSE.DOLLY,
        RIGHT: MOUSE.PAN,
      },
    });
  });

  it('allows one viewer to increase zoom and pan without changing shared defaults', () => {
    const controls = {
      rotateSpeed: 0,
      zoomSpeed: 0,
      panSpeed: 0,
      staticMoving: false,
      minZoom: 0,
      maxZoom: 0,
      mouseButtons: {},
    };

    configureViewerInteraction(controls, { zoomSpeed: 2.2, panSpeed: 1.4 });

    expect(controls.zoomSpeed).toBe(2.2);
    expect(controls.rotateSpeed).toBe(viewerInteractionProfile.rotateSpeed);
    expect(controls.panSpeed).toBe(1.4);
    expect(viewerInteractionProfile.zoomSpeed).toBe(1.15);
    expect(viewerInteractionProfile.panSpeed).toBe(0.9);
  });
});
