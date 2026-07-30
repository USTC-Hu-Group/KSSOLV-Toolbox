import { describe, expect, it } from 'vitest';

import { sliceExportStem, volumeExportStem } from './exportNames';

describe('volume export filenames', () => {
  it('includes the source, channel, and representation', () => {
    expect(volumeExportStem('CHGCAR', 'magnetization-z')).toBe(
      'CHGCAR.magnetization-z',
    );
    expect(sliceExportStem('density.cube', 'orbital 7', 'k', 12.4)).toBe(
      'density.cube.orbital_7.slice-k12',
    );
  });

  it('removes filesystem control characters and supplies fallbacks', () => {
    expect(volumeExportStem('../bad:name', '\u0000')).toBe(
      '..-bad-name.channel',
    );
  });
});
