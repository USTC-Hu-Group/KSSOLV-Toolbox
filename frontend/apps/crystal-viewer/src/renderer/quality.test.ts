import { describe, expect, it } from 'vitest';

import {
  exportPixelRatio,
  gleamoeExportPixelRatio,
  interactivePixelRatio,
  renderQualityProfile,
} from './quality';

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
    expect(ultra.pathTracingSamples).toBe(96);
    expect(ultra.pathTracingBounces).toBe(9);
    expect(ultra.textureSize).toBe(2048);
  });

  it('defines PNG scale relative to the standard fast output', () => {
    expect(interactivePixelRatio(2, 'fast', 'high')).toBe(2);
    expect(exportPixelRatio(2, 'quality', 'balanced')).toBe(2.5);
    expect(exportPixelRatio(2, 'quality', 'high')).toBe(3);
    expect(exportPixelRatio(2, 'quality', 'ultra')).toBe(4);
    expect(exportPixelRatio(2, 'fast', 'ultra')).toBe(2);
  });

  it('supersamples Gleamoe Hero Shots at a crisp 2.5× minimum', () => {
    expect(gleamoeExportPixelRatio(1, false)).toBe(1.75);
    expect(gleamoeExportPixelRatio(1, true)).toBe(2.5);
    expect(gleamoeExportPixelRatio(2, true)).toBe(2.5);
    expect(gleamoeExportPixelRatio(4, true)).toBe(2.5);
    expect(gleamoeExportPixelRatio(1, true, 3)).toBe(3);
    expect(gleamoeExportPixelRatio(1, true, 4)).toBe(4);
  });
});
