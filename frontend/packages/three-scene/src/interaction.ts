import { MOUSE } from 'three';

/** Shared camera interaction profile for atomic and volumetric 3-D viewers. */
export const viewerInteractionProfile = Object.freeze({
  rotateSpeed: 1.1,
  zoomSpeed: 6,
  panSpeed: 0.9,
  freeRotation: true,
  dragThresholdPixels: 4,
  minZoom: 0.08,
  maxZoom: 30,
});

interface ViewerInteractionControls {
  rotateSpeed: number;
  zoomSpeed: number;
  panSpeed: number;
  staticMoving: boolean;
  minZoom: number;
  maxZoom: number;
  mouseButtons: {
    LEFT?: MOUSE | null;
    MIDDLE?: MOUSE | null;
    RIGHT?: MOUSE | null;
  };
}

export interface ViewerInteractionOverrides {
  rotateSpeed?: number;
  zoomSpeed?: number;
  panSpeed?: number;
  minZoom?: number;
  maxZoom?: number;
}

/** Apply one interaction contract to every KSSOLV three-dimensional viewer. */
export const configureViewerInteraction = (
  controls: ViewerInteractionControls,
  overrides: ViewerInteractionOverrides = {},
): void => {
  controls.staticMoving = true;
  controls.rotateSpeed =
    overrides.rotateSpeed ?? viewerInteractionProfile.rotateSpeed;
  controls.zoomSpeed =
    overrides.zoomSpeed ?? viewerInteractionProfile.zoomSpeed;
  controls.panSpeed =
    overrides.panSpeed ?? viewerInteractionProfile.panSpeed;
  controls.minZoom = overrides.minZoom ?? viewerInteractionProfile.minZoom;
  controls.maxZoom = overrides.maxZoom ?? viewerInteractionProfile.maxZoom;
  controls.mouseButtons = {
    LEFT: MOUSE.ROTATE,
    MIDDLE: MOUSE.DOLLY,
    RIGHT: MOUSE.PAN,
  };
};

export const exceedsDragThreshold = (
  startX: number,
  startY: number,
  currentX: number,
  currentY: number,
  threshold = viewerInteractionProfile.dragThresholdPixels,
): boolean => Math.hypot(currentX - startX, currentY - startY) >= threshold;
