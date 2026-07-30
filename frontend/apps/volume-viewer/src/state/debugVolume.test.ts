import { describe, expect, it } from 'vitest';

import { shouldUseDebugVolume } from './debugVolume';

describe('debug volume startup', () => {
  it('does not inject demo data merely because the MATLAB bridge is not connected yet', () => {
    expect(shouldUseDebugVolume('', false)).toBe(false);
    expect(shouldUseDebugVolume('?kssolvTest=1', false)).toBe(false);
  });

  it('requires the explicit debugVolume=1 query parameter', () => {
    expect(shouldUseDebugVolume('?debugVolume=1', false)).toBe(true);
    expect(shouldUseDebugVolume('?debugVolume=0', false)).toBe(false);
    expect(shouldUseDebugVolume('?debugVolume', false)).toBe(false);
  });

  it('does not replace a connected MATLAB scene with demo data', () => {
    expect(shouldUseDebugVolume('?debugVolume=1', true)).toBe(false);
  });
});
