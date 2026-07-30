import { describe, expect, it } from 'vitest';

import { percentileTable } from './statistics';

describe('volume statistics', () => {
  it('computes interpolated percentiles and ignores non-finite samples', () => {
    const table = percentileTable(new Float32Array([4, 1, Number.NaN, 3, 2]), 4);
    expect(Array.from(table)).toEqual([1, 1.75, 2.5, 3.25, 4]);
  });
});

