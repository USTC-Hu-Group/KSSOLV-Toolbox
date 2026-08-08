import { Vector3 } from 'three';

import type { AtomicSceneSpec, Matrix3Tuple } from '@kssolv/atomic-scene';

export type DirectCrystalCameraAxis = 'a' | 'b' | 'c';
export type ReciprocalCrystalCameraAxis = 'a*' | 'b*' | 'c*';
export type CrystalCameraAxis = DirectCrystalCameraAxis | ReciprocalCrystalCameraAxis;

export interface CameraAxisFrame {
  direction: Vector3;
  up: Vector3;
}

const cartesianAxes = [new Vector3(1, 0, 0), new Vector3(0, 1, 0), new Vector3(0, 0, 1)] as const;

const cartesianAxisDirections = (): [Vector3, Vector3, Vector3] => [
  cartesianAxes[0].clone(),
  cartesianAxes[1].clone(),
  cartesianAxes[2].clone(),
];

const axisIndex = (axis: CrystalCameraAxis): number =>
  axis.startsWith('a') ? 0 : axis.startsWith('b') ? 1 : 2;

/** Standard isometric direction used by the Reset camera command. */
export const defaultCameraDirection = (): Vector3 => new Vector3(1, 1, 1).normalize();

/**
 * Compose the conventional oblique slab view while keeping the exact
 * surface normal vertical on screen. Slab cells use a and b as their
 * in-plane vectors, so a x b is the physical surface normal even when
 * the direct c vector is skewed.
 */
export const slabCameraFrame = (scene: AtomicSceneSpec): CameraAxisFrame => {
  const direction = defaultCameraDirection();
  if (scene.kind === 'molecule') {
    return { direction, up: new Vector3(0, 0, 1) };
  }

  const normal = new Vector3(...scene.structure.lattice[0])
    .cross(new Vector3(...scene.structure.lattice[1]))
    .normalize();
  let up = normal.clone().addScaledVector(direction, -normal.dot(direction));
  if (up.lengthSq() <= Number.EPSILON) {
    const inPlane = latticeAxisDirections(scene)[0];
    direction.copy(inPlane).addScaledVector(normal, 0.7).normalize();
    up = normal.clone().addScaledVector(direction, -normal.dot(direction));
  }
  return { direction, up: up.normalize() };
};

export const latticeAxisDirectionsFromVectors = (
  lattice: Matrix3Tuple,
): [Vector3, Vector3, Vector3] => [
  new Vector3(...lattice[0]).normalize(),
  new Vector3(...lattice[1]).normalize(),
  new Vector3(...lattice[2]).normalize(),
];

export const reciprocalAxisDirectionsFromVectors = (
  lattice: Matrix3Tuple,
): [Vector3, Vector3, Vector3] => {
  const a = new Vector3(...lattice[0]);
  const b = new Vector3(...lattice[1]);
  const c = new Vector3(...lattice[2]);
  const signedVolume = a.dot(b.clone().cross(c));
  if (Math.abs(signedVolume) <= Number.EPSILON) {
    return cartesianAxisDirections();
  }

  // The conventional 2π factor does not affect view direction. Dividing by
  // signed volume preserves a·a*, b·b*, c·c* > 0 for either handedness.
  return [
    b.clone().cross(c).divideScalar(signedVolume).normalize(),
    c.clone().cross(a).divideScalar(signedVolume).normalize(),
    a.clone().cross(b).divideScalar(signedVolume).normalize(),
  ];
};

export const latticeAxisDirections = (scene: AtomicSceneSpec): [Vector3, Vector3, Vector3] => {
  if (scene.kind === 'molecule') return cartesianAxisDirections();
  return latticeAxisDirectionsFromVectors(scene.structure.lattice);
};

export const reciprocalAxisDirections = (scene: AtomicSceneSpec): [Vector3, Vector3, Vector3] => {
  if (scene.kind === 'molecule') return cartesianAxisDirections();
  return reciprocalAxisDirectionsFromVectors(scene.structure.lattice);
};

export const cameraAxisFrameFromVectors = (
  lattice: Matrix3Tuple,
  axis: CrystalCameraAxis,
): CameraAxisFrame => {
  const index = axisIndex(axis);
  const directions = axis.endsWith('*')
    ? reciprocalAxisDirectionsFromVectors(lattice)
    : latticeAxisDirectionsFromVectors(lattice);
  const source = directions[index];
  const direction =
    source.lengthSq() > Number.EPSILON ? source.normalize() : cartesianAxes[index].clone();

  // Project a stable world reference onto the view plane. This gives
  // camera.up an exact right angle to the sight axis and prevents an
  // unintended roll for skewed or nearly vertical lattice vectors.
  const referenceUp =
    Math.abs(direction.dot(cartesianAxes[2])) > 0.98
      ? cartesianAxes[1].clone()
      : cartesianAxes[2].clone();
  const up = referenceUp.addScaledVector(direction, -referenceUp.dot(direction)).normalize();

  return { direction, up };
};

/**
 * Return a stable camera frame for a crystallographic axis view.
 *
 * AtomicSceneSpec follows pymatgen/matgenlab's row-vector convention:
 * lattice[0], lattice[1], and lattice[2] are a, b, and c respectively.
 * The camera is placed on the positive axis and looks back toward the
 * structure, so its sight line is antiparallel (and therefore collinear)
 * with the requested lattice vector.
 */
export const cameraAxisFrame = (
  scene: AtomicSceneSpec,
  axis: CrystalCameraAxis,
): CameraAxisFrame => {
  if (scene.kind === 'molecule') {
    return cameraAxisFrameFromVectors(
      [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
      ],
      axis,
    );
  }
  return cameraAxisFrameFromVectors(scene.structure.lattice, axis);
};
