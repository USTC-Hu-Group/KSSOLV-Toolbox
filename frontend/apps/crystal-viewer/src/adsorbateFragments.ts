import type { Vector3Tuple } from './scene/types';

export interface AdsorbateFragment {
  id: string;
  label: string;
  formula: string;
  species: string[];
  coordinates: Vector3Tuple[];
  bonds: Array<[number, number, number]>;
  anchorAtomIndex: number;
  orientation?: Vector3Tuple;
  defaultHostBondLength: number;
}

/**
 * Frozen direct-sketch presets. The data contract is generic and mirrors the
 * MATLAB fragment topology; adding a group does not add gesture branches.
 * User/project fragments will use the same contract when supplied by MATLAB.
 */
export const directAdsorbateFragments: readonly AdsorbateFragment[] = [
  {
    id: 'oxygen-hydrogen',
    label: 'O–H fragment',
    formula: 'OH',
    species: ['O', 'H'],
    coordinates: [
      [0, 0, 0],
      [0.4, 0, 0.8727],
    ],
    bonds: [[0, 1, 1]],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
  {
    id: 'carboxyl',
    label: 'Carboxyl',
    formula: 'COOH',
    species: ['C', 'O', 'O', 'H'],
    coordinates: [
      [0, 0, 0],
      [1.23, 0, 0],
      [-0.65, 1.12, 0],
      [-1.1, 1.9, 0],
    ],
    bonds: [
      [0, 1, 2],
      [0, 2, 1],
      [2, 3, 1],
    ],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
  {
    id: 'amino',
    label: 'Amino',
    formula: 'NH₂',
    species: ['N', 'H', 'H'],
    coordinates: [
      [0, 0, 0],
      [0.78, 0, 0.64],
      [-0.39, 0.6755, 0.64],
    ],
    bonds: [
      [0, 1, 1],
      [0, 2, 1],
    ],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
  {
    id: 'methyl',
    label: 'Methyl',
    formula: 'CH₃',
    species: ['C', 'H', 'H', 'H'],
    coordinates: [
      [0, 0, 0],
      [1.03, 0, 0.36],
      [-0.515, 0.892, 0.36],
      [-0.515, -0.892, 0.36],
    ],
    bonds: [
      [0, 1, 1],
      [0, 2, 1],
      [0, 3, 1],
    ],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
  {
    id: 'carbon-monoxide',
    label: 'Carbon monoxide',
    formula: 'CO',
    species: ['C', 'O'],
    coordinates: [
      [0, 0, 0],
      [0, 0, 1.13],
    ],
    bonds: [[0, 1, 3]],
    anchorAtomIndex: 0,
    defaultHostBondLength: 1.9,
  },
  {
    id: 'carbon-dioxide',
    label: 'Carbon dioxide',
    formula: 'CO₂',
    species: ['O', 'C', 'O'],
    coordinates: [
      [0, 0, 0],
      [0, 0, 1.16],
      [0, 0, 2.32],
    ],
    bonds: [
      [0, 1, 2],
      [1, 2, 2],
    ],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
  {
    id: 'water',
    label: 'Water',
    formula: 'H₂O',
    species: ['O', 'H', 'H'],
    coordinates: [
      [0, 0, 0],
      [0.9572, 0, 0],
      [-0.239, 0.927, 0],
    ],
    bonds: [
      [0, 1, 1],
      [0, 2, 1],
    ],
    anchorAtomIndex: 0,
    defaultHostBondLength: 2,
  },
];

export const directAdsorbateFragment = (id: string): AdsorbateFragment =>
  directAdsorbateFragments.find((fragment) => fragment.id === id) ?? directAdsorbateFragments[0]!;
