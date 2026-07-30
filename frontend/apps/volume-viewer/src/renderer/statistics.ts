export const percentileTable = (
  input: Float32Array | Float64Array,
  steps = 100,
): Float32Array => {
  const finite = Float64Array.from(input).filter(Number.isFinite);
  finite.sort();
  const result = new Float32Array(steps + 1);
  if (finite.length === 0) {
    result.fill(Number.NaN);
    return result;
  }
  for (let step = 0; step <= steps; step += 1) {
    const position = (step / steps) * (finite.length - 1);
    const lower = Math.floor(position);
    const upper = Math.min(finite.length - 1, lower + 1);
    const fraction = position - lower;
    result[step] = finite[lower] * (1 - fraction) + finite[upper] * fraction;
  }
  return result;
};
