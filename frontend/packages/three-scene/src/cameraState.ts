import { Box3, OrthographicCamera, Vector3 } from 'three';

import type { CameraSnapshot, Vector3Tuple } from '@kssolv/atomic-scene';

export interface CompleteCameraSnapshot extends CameraSnapshot {
  quaternion: [number, number, number, number];
}

const tuple = (value: Vector3): Vector3Tuple => [value.x, value.y, value.z];

export const snapshotCamera = (
  camera: OrthographicCamera,
  target: Vector3,
): CompleteCameraSnapshot => ({
  position: tuple(camera.position),
  target: tuple(target),
  up: tuple(camera.up),
  zoom: camera.zoom,
  quaternion: [
    camera.quaternion.x,
    camera.quaternion.y,
    camera.quaternion.z,
    camera.quaternion.w,
  ],
});

export const restoreCamera = (
  camera: OrthographicCamera,
  target: Vector3,
  snapshot: CompleteCameraSnapshot,
): void => {
  camera.position.fromArray(snapshot.position);
  camera.up.fromArray(snapshot.up);
  camera.quaternion.fromArray(snapshot.quaternion);
  camera.zoom = snapshot.zoom;
  target.fromArray(snapshot.target);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld(true);
};

/**
 * Fit an orthographic camera without changing its orientation.
 *
 * The camera and target translate together, while only zoom changes. This is
 * the behavior bound to the Space shortcut in all KSSOLV 3-D viewers.
 */
export const fitOrthographicCamera = (
  camera: OrthographicCamera,
  target: Vector3,
  bounds: Box3,
  padding = 1.12,
): void => {
  if (bounds.isEmpty()) return;
  const center = bounds.getCenter(new Vector3());
  const corners = [
    new Vector3(bounds.min.x, bounds.min.y, bounds.min.z),
    new Vector3(bounds.max.x, bounds.min.y, bounds.min.z),
    new Vector3(bounds.min.x, bounds.max.y, bounds.min.z),
    new Vector3(bounds.min.x, bounds.min.y, bounds.max.z),
    new Vector3(bounds.max.x, bounds.max.y, bounds.min.z),
    new Vector3(bounds.max.x, bounds.min.y, bounds.max.z),
    new Vector3(bounds.min.x, bounds.max.y, bounds.max.z),
    new Vector3(bounds.max.x, bounds.max.y, bounds.max.z),
  ];
  const inverse = camera.quaternion.clone().invert();
  const projected = corners.map((corner) => corner.sub(center).applyQuaternion(inverse));
  const width = Math.max(...projected.map((point) => Math.abs(point.x))) * 2;
  const height = Math.max(...projected.map((point) => Math.abs(point.y))) * 2;
  const frustumWidth = camera.right - camera.left;
  const frustumHeight = camera.top - camera.bottom;
  camera.zoom = Math.min(
    frustumWidth / (Math.max(width, Number.EPSILON) * padding),
    frustumHeight / (Math.max(height, Number.EPSILON) * padding),
  );
  const translation = center.sub(target);
  target.add(translation);
  camera.position.add(translation);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld(true);
};
