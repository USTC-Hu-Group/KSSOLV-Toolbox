import { describe, expect, it } from 'vitest';

import { sliceExportStem, volumeExportStem } from './exportNames';

describe('volume export filenames', () => {
  it('includes the source, channel, and representation', () => {
    expect(volumeExportStem('CHGCAR', 'magnetization-z')).toBe(
      'CHGCAR.magnetization-z',
    );
    expect(sliceExportStem('density.cube', 'orbital 7', [1, -1, 2])).toBe(
      'density.cube.orbital_7.slice-1_-1_2',
    );
  });

  it('removes filesystem control characters and supplies fallbacks', () => {
    expect(volumeExportStem('../bad:name', '\u0000')).toBe(
      '..-bad-name.channel',
    );
  });
});
