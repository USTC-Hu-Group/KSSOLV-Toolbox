import { describe, expect, it } from 'vitest';

import { appearanceScale, scaledMetalness, scaledRoughness } from './appearance';

describe('appearance scaling', () => {
  it('preserves authored material values at the 50% midpoint', () => {
    expect(appearanceScale(0.5)).toBe(1);
    expect(scaledMetalness(0.16, 0.5)).toBeCloseTo(0.16);
    expect(scaledRoughness(0.28, 0.5)).toBeCloseTo(0.28);
  });

  it('can metalize a nonmetallic base above the midpoint', () => {
    expect(scaledMetalness(0, 0.75)).toBeCloseTo(0.5);
    expect(scaledMetalness(0, 1)).toBe(1);
  });

  it('clamps material endpoints', () => {
    expect(scaledMetalness(0.7, 1.5)).toBe(1);
    expect(scaledRoughness(0.7, 1)).toBe(1);
  });
});
