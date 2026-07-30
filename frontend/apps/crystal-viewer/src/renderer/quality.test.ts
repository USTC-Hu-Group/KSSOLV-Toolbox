import { describe, expect, it } from 'vitest';

import { exportPixelRatio, interactivePixelRatio, renderQualityProfile } from './quality';

describe('render quality profiles', () => {
  it('uses the inexpensive profile for the default interactive path', () => {
    const profile = renderQualityProfile('fast', 'ultra');
    expect(profile.atomSegments).toEqual([48, 32]);
    expect(profile.pixelRatioCap).toBe(2);
    expect(profile.exportScale).toBe(1);
  });

  it('scales mesh density, device pixels, and export resolution by quality level', () => {
    const balanced = renderQualityProfile('quality', 'balanced');
    const high = renderQualityProfile('quality', 'high');
    const ultra = renderQualityProfile('quality', 'ultra');
    expect(high.atomSegments[0]).toBeGreaterThan(balanced.atomSegments[0]);
    expect(ultra.atomSegments[0]).toBeGreaterThan(high.atomSegments[0]);
    expect([balanced.exportScale, high.exportScale, ultra.exportScale]).toEqual([1.25, 1.5, 2]);
    expect(ultra.pixelRatioCap).toBeGreaterThan(high.pixelRatioCap);
  });

  it('defines PNG scale relative to the standard fast output', () => {
    expect(interactivePixelRatio(2, 'fast', 'high')).toBe(2);
    expect(exportPixelRatio(2, 'quality', 'balanced')).toBe(2.5);
    expect(exportPixelRatio(2, 'quality', 'high')).toBe(3);
    expect(exportPixelRatio(2, 'quality', 'ultra')).toBe(4);
    expect(exportPixelRatio(2, 'fast', 'ultra')).toBe(2);
  });
});
