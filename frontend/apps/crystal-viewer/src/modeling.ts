import type { Vector3Tuple } from './scene/types';

export type ContextModelingCommandId =
  | 'delete_atoms'
  | 'substitute_atoms'
  | 'move_atoms'
  | 'rotate_atoms'
  | 'translate_atoms'
  | 'sketch_atom'
  | 'sketch_ring'
  | 'add_bond'
  | 'delete_bond'
  | 'set_bond_order'
  | 'place_adsorbate'
  | 'set_distance'
  | 'set_angle'
  | 'set_dihedral';

export type ContextModelingParameters =
  | Record<string, never>
  | { species: string }
  | { coordinates: Vector3Tuple; cartesian: boolean }
  | { angleDegrees: number; axis: Vector3Tuple; anchor: Vector3Tuple }
  | { vector: Vector3Tuple; fractional: boolean }
  | {
      species: string;
      coordinates: Vector3Tuple;
      connectTo: number;
      bondOrder: number;
      formalCharge: number;
      hybridization: string;
      aromatic: boolean;
    }
  | {
      ringSize: number;
      species: string;
      center: Vector3Tuple;
      normal: Vector3Tuple;
      bondOrder: number;
      aromatic: boolean;
      attachTo: number;
    }
  | { bondOrder: number }
  | {
      adsorbateName: string;
      adsorbateSpecies: string[];
      adsorbateCoordinates: Vector3Tuple[];
      adsorbateBonds: Array<[number, number, number]>;
      anchorAtomIndices: number[];
      minimumDistance: number;
    }
  | {
      value: number;
      scope: 'atom' | 'subtree' | 'fragment';
      referenceCoordinates: Vector3Tuple[];
    };

export interface ContextModelingRequest {
  requestId: string;
  commandId: ContextModelingCommandId;
  siteIndices: number[];
  parameters: ContextModelingParameters;
}

export interface ContextModelingResult {
  commandId: ContextModelingCommandId;
  status: 'success' | 'error';
  message: string;
}

export const isContextModelingResult = (value: unknown): value is ContextModelingResult => {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<ContextModelingResult>;
  return (
    [
      'delete_atoms',
      'substitute_atoms',
      'move_atoms',
      'rotate_atoms',
      'translate_atoms',
      'sketch_atom',
      'sketch_ring',
      'add_bond',
      'delete_bond',
      'set_bond_order',
      'place_adsorbate',
      'set_distance',
      'set_angle',
      'set_dihedral',
    ].includes(candidate.commandId ?? '') &&
    (candidate.status === 'success' || candidate.status === 'error') &&
    typeof candidate.message === 'string'
  );
};

/** A successful edit remains locked until the corresponding scene revision arrives. */
export const modelingResultAwaitsScene = (result: ContextModelingResult): boolean =>
  result.status === 'success';

export const modelingBackendAvailable = (): boolean =>
  document.documentElement.dataset.kssolvOffline !== 'true';
