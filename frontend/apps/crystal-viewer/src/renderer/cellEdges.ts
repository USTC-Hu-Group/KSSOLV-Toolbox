import { Vector3 } from 'three';

import type { Matrix3Tuple, Vector3Tuple } from '../scene/types';

export type CellEdge = [Vector3, Vector3];

const pointAt = (lattice: [Vector3, Vector3, Vector3], coordinates: Vector3Tuple): Vector3 =>
  lattice[0]
    .clone()
    .multiplyScalar(coordinates[0])
    .addScaledVector(lattice[1], coordinates[1])
    .addScaledVector(lattice[2], coordinates[2]);

/**
 * Build the distinct, single-cell-length edges of a visually repeated crystal.
 * Keeping the internal divisions visible makes it clear that repeat is a display
 * operation rather than a scientific supercell transformation.
 */
export const repeatedCellEdges = (
  latticeValues: Matrix3Tuple,
  repeat: Vector3Tuple,
): CellEdge[] => {
  const lattice = latticeValues.map((value) => new Vector3(...value)) as [
    Vector3,
    Vector3,
    Vector3,
  ];
  const [repeatA, repeatB, repeatC] = repeat;
  const edges: CellEdge[] = [];

  for (let b = 0; b <= repeatB; b += 1) {
    for (let c = 0; c <= repeatC; c += 1) {
      for (let a = 0; a < repeatA; a += 1) {
        edges.push([pointAt(lattice, [a, b, c]), pointAt(lattice, [a + 1, b, c])]);
      }
    }
  }
  for (let a = 0; a <= repeatA; a += 1) {
    for (let c = 0; c <= repeatC; c += 1) {
      for (let b = 0; b < repeatB; b += 1) {
        edges.push([pointAt(lattice, [a, b, c]), pointAt(lattice, [a, b + 1, c])]);
      }
    }
  }
  for (let a = 0; a <= repeatA; a += 1) {
    for (let b = 0; b <= repeatB; b += 1) {
      for (let c = 0; c < repeatC; c += 1) {
        edges.push([pointAt(lattice, [a, b, c]), pointAt(lattice, [a, b, c + 1])]);
      }
    }
  }

  return edges;
};
