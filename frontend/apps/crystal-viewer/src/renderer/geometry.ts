import { BufferGeometry, Color, Matrix4, Quaternion, Vector3, type Object3D } from 'three';

import type { RgbTuple, ThemeId, Vector3Tuple } from '../scene/types';

const up = new Vector3(0, 1, 0);

export interface FitSphere {
  center: Vector3;
  radius: number;
}

export const vector = (value: Vector3Tuple): Vector3 => new Vector3(...value);

export const orthographicFitHeight = (radius: number, aspect: number, padding = 1.25): number =>
  (radius * 2 * padding) / Math.min(Math.max(aspect, 0.1), 1);

export const fittedViewHeight = (
  radius: number,
  aspect: number,
  verticalSize: number,
  theme: ThemeId,
): number => {
  const profile =
    theme === 'materials'
      ? { spherePadding: 1.06, verticalPadding: 1.08, minimum: 2.2 }
      : { spherePadding: 1.25, verticalPadding: 1.25, minimum: 3 };
  return Math.max(
    orthographicFitHeight(radius, aspect, profile.spherePadding),
    verticalSize * profile.verticalPadding,
    profile.minimum,
  );
};

export const projectedFitHeight = (
  spheres: FitSphere[],
  sceneCenter: Vector3,
  viewDirection: Vector3,
  cameraUp: Vector3,
  aspect: number,
  padding = 1.15,
  minimum = 2.2,
): number => {
  const forward = viewDirection.clone().normalize().negate();
  const normalizedUp = cameraUp.clone().normalize();
  const safeUp = Math.abs(forward.dot(normalizedUp)) > 0.98 ? new Vector3(0, 1, 0) : normalizedUp;
  const right = new Vector3().crossVectors(forward, safeUp).normalize();
  const screenUp = new Vector3().crossVectors(right, forward).normalize();
  let halfWidth = 0;
  let halfHeight = 0;
  for (const sphere of spheres) {
    const offset = sphere.center.clone().sub(sceneCenter);
    halfWidth = Math.max(halfWidth, Math.abs(offset.dot(right)) + sphere.radius);
    halfHeight = Math.max(halfHeight, Math.abs(offset.dot(screenUp)) + sphere.radius);
  }
  const safeAspect = Math.max(aspect, 0.1);
  return Math.max(2 * Math.max(halfHeight, halfWidth / safeAspect) * padding, minimum);
};

export const color = (value: RgbTuple): Color =>
  new Color(value[0] / 255, value[1] / 255, value[2] / 255);

export const cylinderMatrix = (
  startValue: Vector3Tuple,
  endValue: Vector3Tuple,
  radius: number,
): Matrix4 => {
  const start = vector(startValue);
  const end = vector(endValue);
  const direction = end.clone().sub(start);
  const length = Math.max(direction.length(), Number.EPSILON);
  const midpoint = start.clone().add(end).multiplyScalar(0.5);
  const rotation = new Quaternion().setFromUnitVectors(up, direction.normalize());
  return new Matrix4().compose(midpoint, rotation, new Vector3(radius, length, radius));
};

export const geometryCapacity = (geometries: Iterable<BufferGeometry>) => {
  let vertices = 0;
  let indices = 0;
  for (const geometry of geometries) {
    vertices += geometry.getAttribute('position')?.count ?? 0;
    indices += geometry.index?.count ?? 0;
  }
  return {
    vertices: Math.max(vertices, 1),
    indices: Math.max(indices, 1),
  };
};

export const disposeObject = (object: Object3D): void => {
  object.traverse((child) => {
    const mesh = child as Object3D & {
      geometry?: BufferGeometry;
      material?: { dispose?: () => void } | Array<{ dispose?: () => void }>;
      dispose?: () => void;
    };
    mesh.geometry?.dispose();
    if (Array.isArray(mesh.material)) {
      mesh.material.forEach((material) => material.dispose?.());
    } else {
      mesh.material?.dispose?.();
    }
    mesh.dispose?.();
  });
  object.removeFromParent();
};
