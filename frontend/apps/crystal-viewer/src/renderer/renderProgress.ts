export interface PathTraceProgress {
  progress: number;
  sample: number;
  totalSamples: number;
  region: number;
  totalRegions: number;
  batch: number;
  totalBatches: number;
  regionsPerBatch: number;
}

/**
 * Keep several regional draw calls in flight before yielding back to Vue.
 * A single WebGL context cannot render the same accumulation target from
 * multiple workers safely, so batching is the useful form of parallelism here:
 * pixels and rays remain GPU-parallel while JavaScript submits half a regional
 * sweep at a time. The cap still gives the progress overlay two updates per
 * sweep instead of appearing frozen for a whole sample.
 */
export const regionalSubmissionBatchSize = (regionColumns: number, regionRows: number): number => {
  const totalRegions = Math.max(Math.round(regionColumns) * Math.round(regionRows), 1);
  return Math.min(totalRegions, Math.max(3, Math.ceil(totalRegions / 2)));
};

export const pathTraceProgress = (
  samples: number,
  targetSamples: number,
  regionColumns: number,
  regionRows: number,
  regionsPerBatch = 1,
): PathTraceProgress => {
  const safeTarget = Math.max(targetSamples, 0);
  const totalRegions = Math.max(Math.round(regionColumns) * Math.round(regionRows), 1);
  const clampedSamples = Math.min(Math.max(samples, 0), safeTarget);
  const completedRegions = Math.min(
    Math.round(clampedSamples * totalRegions),
    safeTarget * totalRegions,
  );
  const safeBatchSize = Math.min(Math.max(Math.round(regionsPerBatch), 1), totalRegions);
  const region = completedRegions === 0 ? 0 : ((completedRegions - 1) % totalRegions) + 1;
  return {
    progress: safeTarget > 0 ? clampedSamples / safeTarget : 1,
    sample: safeTarget > 0 ? Math.min(Math.ceil(clampedSamples), safeTarget) : 0,
    totalSamples: safeTarget,
    region,
    totalRegions,
    batch: region === 0 ? 0 : Math.ceil(region / safeBatchSize),
    totalBatches: Math.ceil(totalRegions / safeBatchSize),
    regionsPerBatch: safeBatchSize,
  };
};
