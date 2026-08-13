import type { AtomicSceneSpec } from './scene/types';

/** Reframe when an atoms-first preview becomes the bonded scene for one request. */
export const shouldAutoFitAfterConnectivity = (
  previous: AtomicSceneSpec | undefined,
  next: AtomicSceneSpec,
): boolean =>
  previous?.requestId === next.requestId &&
  previous.bondInstances.length === 0 &&
  next.bondInstances.length > 0;
