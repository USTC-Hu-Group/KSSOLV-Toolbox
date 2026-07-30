import { describe, expect, it } from 'vitest';

import {
  histogramThresholdSign,
  histogramThresholdValueForSign,
  histogramValueAtFraction,
  nearestHistogramRangeBound,
} from './histogramInteraction';

describe('histogram threshold interaction', () => {
  it('maps the horizontal pointer position onto the channel value range', () => {
    expect(histogramValueAtFraction(-2, 6, 0)).toBe(-2);
    expect(histogramValueAtFraction(-2, 6, 0.25)).toBe(0);
    expect(histogramValueAtFraction(-2, 6, 1)).toBe(6);
  });

  it('clamps pointer positions outside the histogram', () => {
    expect(histogramValueAtFraction(0, 7, -0.1)).toBe(0);
    expect(histogramValueAtFraction(0, 7, 1.1)).toBe(7);
  });

  it('selects the negative marker only for negative values in signed channels', () => {
    expect(histogramThresholdSign(true, -0.1)).toBe('negative');
    expect(histogramThresholdSign(true, 0)).toBe('positive');
    expect(histogramThresholdSign(false, -0.1)).toBe('positive');
  });

  it('keeps dragged signed thresholds on their corresponding side of zero', () => {
    expect(histogramThresholdValueForSign(true, 'negative', 2)).toBe(0);
    expect(histogramThresholdValueForSign(true, 'negative', -2)).toBe(-2);
    expect(histogramThresholdValueForSign(true, 'positive', -2)).toBe(0);
    expect(histogramThresholdValueForSign(true, 'positive', 2)).toBe(2);
    expect(histogramThresholdValueForSign(false, 'positive', -2)).toBe(-2);
  });

  it('selects the display-range endpoint nearest to the clicked value', () => {
    expect(nearestHistogramRangeBound(0, 10, 2)).toBe('minimum');
    expect(nearestHistogramRangeBound(0, 10, 8)).toBe('maximum');
    expect(nearestHistogramRangeBound(2, 8, 5)).toBe('minimum');
  });
});
