import {
  configureViewerInteraction,
  exceedsDragThreshold,
  viewerInteractionProfile,
} from '@kssolv/three-scene';
import { OrthographicCamera, Vector3 } from 'three';

export { configureViewerInteraction, exceedsDragThreshold, viewerInteractionProfile };

export const orthographicPanOffset = (
  camera: OrthographicCamera,
  viewportWidth: number,
  viewportHeight: number,
  deltaX: number,
  deltaY: number,
): Vector3 => {
  const worldPerPixelX = (camera.right - camera.left) / camera.zoom / Math.max(viewportWidth, 1);
  const worldPerPixelY = (camera.top - camera.bottom) / camera.zoom / Math.max(viewportHeight, 1);
  const cameraRight = new Vector3(1, 0, 0).applyQuaternion(camera.quaternion);
  const cameraUp = new Vector3(0, 1, 0).applyQuaternion(camera.quaternion);
  return cameraRight
    .multiplyScalar(-deltaX * worldPerPixelX)
    .add(cameraUp.multiplyScalar(deltaY * worldPerPixelY));
};

export const autoRotationAngle = (elapsedSeconds: number): number => elapsedSeconds * -0.45;
