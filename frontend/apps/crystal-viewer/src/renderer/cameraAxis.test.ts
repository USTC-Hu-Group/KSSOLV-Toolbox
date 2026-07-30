import { OrthographicCamera, Vector3 } from 'three';
import { describe, expect, it } from 'vitest';

import { createDebugMoleculeScene, createDebugScene } from '../scene/debugScene';
import {
  cameraAxisFrame,
  defaultCameraDirection,
  latticeAxisDirections,
  reciprocalAxisDirections,
  type CrystalCameraAxis,
} from './cameraAxis';

const sightLineFor = (axis: CrystalCameraAxis): { direction: Vector3; up: Vector3 } => {
  const scene = createDebugScene();
  scene.structure.lattice = [
    [3.1, 0, 0],
    [-1.55, 2.6846787517, 0],
    [0.42, -0.31, 5.2],
  ];
  const frame = cameraAxisFrame(scene, axis);
  const target = new Vector3(0.7, -1.1, 2.3);
  const camera = new OrthographicCamera(-1, 1, 1, -1);
  camera.position.copy(target).addScaledVector(frame.direction, 10);
  camera.up.copy(frame.up);
  camera.lookAt(target);
  camera.updateMatrixWorld();

  return {
    direction: camera.getWorldDirection(new Vector3()),
    up: camera.up.clone(),
  };
};

describe('crystallographic camera axes', () => {
  it('uses the exact (1, 1, 1) isometric direction for camera reset', () => {
    const direction = defaultCameraDirection();
    const expectedComponent = 1 / Math.sqrt(3);

    expect(direction.toArray()).toEqual([expectedComponent, expectedComponent, expectedComponent]);
  });

  it.each([
    ['a', [3.1, 0, 0]],
    ['b', [-1.55, 2.6846787517, 0]],
    ['c', [0.42, -0.31, 5.2]],
  ] as const)('aligns the %s view with the corresponding lattice row', (axis, expected) => {
    const { direction, up } = sightLineFor(axis);
    const latticeDirection = new Vector3(...expected).normalize();

    // The camera sits on +axis and looks toward the structure along -axis.
    expect(direction.dot(latticeDirection)).toBeCloseTo(-1, 12);
    expect(up.dot(latticeDirection)).toBeCloseTo(0, 12);
    expect(up.length()).toBeCloseTo(1, 12);
  });

  it('preserves the direct-lattice angles in the orientation axes', () => {
    const scene = createDebugScene();
    scene.structure.lattice = [
      [3, 0, 0],
      [-1.5, 2.598076211, 0],
      [0, 0, 5],
    ];
    const [a, b, c] = latticeAxisDirections(scene);

    expect(a.angleTo(b)).toBeCloseTo((2 * Math.PI) / 3, 9);
    expect(a.angleTo(c)).toBeCloseTo(Math.PI / 2, 10);
    expect(b.angleTo(c)).toBeCloseTo(Math.PI / 2, 10);
  });

  it('builds reciprocal axes normal to the other two direct axes', () => {
    const scene = createDebugScene();
    scene.structure.lattice = [
      [3.1, 0, 0],
      [-1.55, 2.6846787517, 0],
      [0.42, -0.31, 5.2],
    ];
    const [a, b, c] = latticeAxisDirections(scene);
    const [aStar, bStar, cStar] = reciprocalAxisDirections(scene);

    expect(aStar.dot(b)).toBeCloseTo(0, 12);
    expect(aStar.dot(c)).toBeCloseTo(0, 12);
    expect(bStar.dot(a)).toBeCloseTo(0, 12);
    expect(bStar.dot(c)).toBeCloseTo(0, 12);
    expect(cStar.dot(a)).toBeCloseTo(0, 12);
    expect(cStar.dot(b)).toBeCloseTo(0, 12);
    expect(aStar.dot(a)).toBeGreaterThan(0);
    expect(bStar.dot(b)).toBeGreaterThan(0);
    expect(cStar.dot(c)).toBeGreaterThan(0);
  });

  it.each(['a*', 'b*', 'c*'] as const)(
    'aligns the %s view with the corresponding reciprocal axis',
    (axis) => {
      const scene = createDebugScene();
      scene.structure.lattice = [
        [3.1, 0, 0],
        [-1.55, 2.6846787517, 0],
        [0.42, -0.31, 5.2],
      ];
      const reciprocal = reciprocalAxisDirections(scene);
      const frame = cameraAxisFrame(scene, axis);
      const index = axis.startsWith('a') ? 0 : axis.startsWith('b') ? 1 : 2;

      expect(frame.direction.dot(reciprocal[index])).toBeCloseTo(1, 12);
      expect(frame.up.dot(frame.direction)).toBeCloseTo(0, 12);
    },
  );

  it('uses Cartesian axes for molecules, which have no crystallographic lattice', () => {
    const molecule = createDebugMoleculeScene();
    const frame = cameraAxisFrame(molecule, 'b');
    expect(frame.direction.toArray()).toEqual([0, 1, 0]);
    expect(frame.up.dot(frame.direction)).toBeCloseTo(0, 12);
  });
});
