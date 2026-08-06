import { describe, expect, it } from 'vitest';

import { pathTraceProgress, regionalSubmissionBatchSize } from './renderProgress';

describe('regional render progress', () => {
  it('batches half of a tiled sweep into the GPU command queue', () => {
    expect(regionalSubmissionBatchSize(4, 3)).toBe(6);
    expect(regionalSubmissionBatchSize(2, 2)).toBe(3);
    expect(regionalSubmissionBatchSize(1, 1)).toBe(1);
  });

  it('tracks fractional path-tracing samples across a 4 × 3 region grid', () => {
    expect(pathTraceProgress(0, 96, 4, 3)).toEqual({
      progress: 0,
      sample: 0,
      totalSamples: 96,
      region: 0,
      totalRegions: 12,
      batch: 0,
      totalBatches: 12,
      regionsPerBatch: 1,
    });
    expect(pathTraceProgress(4 / 12, 96, 4, 3)).toMatchObject({
      sample: 1,
      region: 4,
      totalRegions: 12,
    });
    expect(pathTraceProgress(1, 96, 4, 3)).toMatchObject({ sample: 1, region: 12 });
    expect(pathTraceProgress(95 + 11 / 12, 96, 4, 3)).toMatchObject({
      sample: 96,
      region: 11,
    });
    expect(pathTraceProgress(96, 96, 4, 3)).toMatchObject({
      progress: 1,
      sample: 96,
      region: 12,
    });
  });

  it('describes the active GPU submission batch', () => {
    expect(pathTraceProgress(6 / 12, 96, 4, 3, 6)).toMatchObject({
      region: 6,
      batch: 1,
      totalBatches: 2,
      regionsPerBatch: 6,
    });
    expect(pathTraceProgress(1, 96, 4, 3, 6)).toMatchObject({ region: 12, batch: 2 });
  });
});
