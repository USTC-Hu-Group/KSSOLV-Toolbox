import { describe, expect, it } from 'vitest';

import { shouldShowReciprocalAxes } from './toolbarState';

describe('crystal toolbar state', () => {
  it('reserves reciprocal-axis controls while the initial scene is pending', () => {
    expect(shouldShowReciprocalAxes(undefined)).toBe(true);
    expect(shouldShowReciprocalAxes('crystal')).toBe(true);
    expect(shouldShowReciprocalAxes('molecule')).toBe(false);
  });
});
