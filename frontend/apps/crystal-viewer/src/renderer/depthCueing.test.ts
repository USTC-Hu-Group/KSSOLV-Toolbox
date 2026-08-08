import { describe, expect, it } from 'vitest';

import { depthCueRange } from './depthCueing';

describe('depth cueing', () => {
  it('scales fog planes with the scene radius', () => {
    expect(depthCueRange(12, 2)).toEqual({ near: 10, far: 15 });
    expect(depthCueRange(24, 4)).toEqual({ near: 20, far: 30 });
  });

  it('keeps valid fog planes for empty or degenerate bounds', () => {
    const range = depthCueRange(Number.NaN, 0);
    expect(range.near).toBe(0);
    expect(range.far).toBeGreaterThan(range.near);
  });
});
