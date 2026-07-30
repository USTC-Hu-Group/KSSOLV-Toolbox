export type HistogramThresholdSign = 'positive' | 'negative';
export type HistogramRangeBound = 'minimum' | 'maximum';

export const histogramValueAtFraction = (
  minimum: number,
  maximum: number,
  fraction: number,
): number => {
  const clamped = Math.min(1, Math.max(0, fraction));
  return minimum + (maximum - minimum) * clamped;
};

export const histogramThresholdSign = (
  signed: boolean,
  value: number,
): HistogramThresholdSign =>
  signed && value < 0 ? 'negative' : 'positive';

export const histogramThresholdValueForSign = (
  signed: boolean,
  sign: HistogramThresholdSign,
  value: number,
): number => {
  if (!signed) return value;
  return sign === 'negative' ? Math.min(value, 0) : Math.max(value, 0);
};

export const nearestHistogramRangeBound = (
  minimum: number,
  maximum: number,
  value: number,
): HistogramRangeBound =>
  Math.abs(value - minimum) <= Math.abs(maximum - value)
    ? 'minimum'
    : 'maximum';
