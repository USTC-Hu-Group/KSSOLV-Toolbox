import { describe, expect, it } from 'vitest';
import { Vector3 } from 'three';

import type { CrystalSceneSpec } from '@kssolv/atomic-scene';

import {
  cameraAxisFrame,
  cameraAxisFrameFromVectors,
  latticeAxisDirections,
  reciprocalAxisDirections,
  slabCameraFrame,
} from './cameraAxis';

const scene = {
  kind: 'crystal',
  structure: {
    lattice: [
      [4, 0, 0],
      [1, 3, 0],
      [0.5, 0.7, 5],
    ],
  },
} as CrystalSceneSpec;

describe('crystallographic camera axes', () => {
  it('keeps direct arrows parallel to lattice vectors', () => {
    const directions = latticeAxisDirections(scene);
    expect(directions[1].cross(new Vector3(1, 3, 0)).length()).toBeLessThan(1e-12);
  });

  it('constructs reciprocal directions orthogonal to the other two vectors', () => {
    const reciprocal = reciprocalAxisDirections(scene);
    const direct = latticeAxisDirections(scene);
    expect(Math.abs(reciprocal[0].dot(direct[1]))).toBeLessThan(1e-12);
    expect(Math.abs(reciprocal[0].dot(direct[2]))).toBeLessThan(1e-12);
  });

  it.each(['a', 'b', 'c', 'a*', 'b*', 'c*'] as const)(
    'returns an orthogonal stable frame for %s',
    (axis) => {
      const frame = cameraAxisFrame(scene, axis);
      expect(Math.abs(frame.direction.dot(frame.up))).toBeLessThan(1e-12);
      expect(frame.direction.length()).toBeCloseTo(1);
      expect(frame.up.length()).toBeCloseTo(1);
    },
  );

  it('builds the same frames directly from volume-grid vectors', () => {
    const frame = cameraAxisFrameFromVectors(scene.structure.lattice, 'b*');
    const directA = new Vector3(...scene.structure.lattice[0]);
    const directC = new Vector3(...scene.structure.lattice[2]);
    expect(Math.abs(frame.direction.dot(directA.normalize()))).toBeLessThan(1e-12);
    expect(Math.abs(frame.direction.dot(directC.normalize()))).toBeLessThan(1e-12);
    expect(Math.abs(frame.direction.dot(frame.up))).toBeLessThan(1e-12);
  });

  it('projects the exact slab normal onto the vertical screen direction', () => {
    const skewedSlab = {
      ...scene,
      structure: {
        ...scene.structure,
        lattice: [
          [3, 0.2, 1],
          [0.4, 2.7, 0.6],
          [0.5, 0.7, 5],
        ],
      },
    } as CrystalSceneSpec;
    const frame = slabCameraFrame(skewedSlab);
    const normal = new Vector3(...skewedSlab.structure.lattice[0])
      .cross(new Vector3(...skewedSlab.structure.lattice[1]))
      .normalize();
    const projectedNormal = normal
      .clone()
      .addScaledVector(frame.direction, -normal.dot(frame.direction))
      .normalize();

    expect(frame.up.dot(projectedNormal)).toBeCloseTo(1, 12);
    expect(frame.up.dot(frame.direction)).toBeCloseTo(0, 12);
  });
});
