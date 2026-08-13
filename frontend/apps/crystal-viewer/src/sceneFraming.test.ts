import { describe, expect, it } from 'vitest';

import { createDebugScene } from './scene/debugScene';
import { shouldAutoFitAfterConnectivity } from './sceneFraming';

const sceneWith = (requestId: string, bondCount: number) => {
  const scene = createDebugScene();
  return {
    ...scene,
    requestId,
    bondInstances: scene.bondInstances.slice(0, bondCount),
  };
};

describe('shouldAutoFitAfterConnectivity', () => {
  it('fits when the same request advances from atoms-only to bonded', () => {
    expect(
      shouldAutoFitAfterConnectivity(sceneWith('request-1', 0), sceneWith('request-1', 1)),
    ).toBe(true);
  });

  it('ignores unrelated requests and repeated bonded scenes', () => {
    expect(
      shouldAutoFitAfterConnectivity(sceneWith('request-1', 0), sceneWith('request-2', 1)),
    ).toBe(false);
    expect(
      shouldAutoFitAfterConnectivity(sceneWith('request-1', 1), sceneWith('request-1', 1)),
    ).toBe(false);
    expect(shouldAutoFitAfterConnectivity(undefined, sceneWith('request-1', 1))).toBe(false);
  });
});
