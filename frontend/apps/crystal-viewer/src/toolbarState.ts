import type { AtomicSceneSpec } from './scene/types';

export const shouldShowReciprocalAxes = (sceneKind: AtomicSceneSpec['kind'] | undefined): boolean =>
  sceneKind !== 'molecule';
