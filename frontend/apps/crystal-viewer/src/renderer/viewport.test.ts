import { describe, expect, it } from 'vitest';

import { viewportLayout } from './viewport';

describe('viewportLayout', () => {
  it('keeps Retina viewports in CSS pixels', () => {
    // A 1200×800 CSS viewport has a 2400×1600 drawing buffer at DPR=2.
    // Passing the latter to Three.js would multiply the viewport twice.
    expect(viewportLayout(1200, 800)).toEqual({
      main: { width: 1200, height: 800 },
      axes: { x: 18, y: 18, size: 118 },
    });
  });

  it('shrinks the orientation inset in a short document panel', () => {
    expect(viewportLayout(640, 200).axes.size).toBe(48);
  });
});
