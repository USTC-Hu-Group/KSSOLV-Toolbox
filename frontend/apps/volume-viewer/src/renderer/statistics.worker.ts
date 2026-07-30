/// <reference lib="webworker" />

import { percentileTable } from './statistics';

self.onmessage = (
  event: MessageEvent<{
    id: number;
    values: ArrayBuffer;
    encoding: 'float32' | 'float64';
    minimum: number;
    maximum: number;
    bins: number;
  }>,
): void => {
  const { id, values, encoding, minimum, maximum, bins } = event.data;
  const input = encoding === 'float32' ? new Float32Array(values) : new Float64Array(values);
  const percentiles = percentileTable(input);
  const histogram = new Uint32Array(bins);
  const span = Math.max(maximum - minimum, Number.EPSILON);
  for (const value of input) {
    if (!Number.isFinite(value)) continue;
    const index = Math.min(
      bins - 1,
      Math.max(0, Math.floor(((value - minimum) / span) * bins)),
    );
    histogram[index] += 1;
  }
  self.postMessage({
    id,
    percentiles: percentiles.buffer,
    histogram: histogram.buffer,
  }, {
    transfer: [percentiles.buffer, histogram.buffer],
  });
};
