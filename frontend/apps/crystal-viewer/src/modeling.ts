import type { Vector3Tuple } from './scene/types';

export type ContextModelingCommandId =
  'delete_atoms' | 'substitute_atoms' | 'move_atoms' | 'translate_atoms';

export type ContextModelingParameters =
  | Record<string, never>
  | { species: string }
  | { coordinates: Vector3Tuple; cartesian: boolean }
  | { vector: Vector3Tuple; fractional: boolean };

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
    ['delete_atoms', 'substitute_atoms', 'move_atoms', 'translate_atoms'].includes(
      candidate.commandId ?? '',
    ) &&
    (candidate.status === 'success' || candidate.status === 'error') &&
    typeof candidate.message === 'string'
  );
};

export const modelingBackendAvailable = (): boolean =>
  document.documentElement.dataset.kssolvOffline !== 'true';
