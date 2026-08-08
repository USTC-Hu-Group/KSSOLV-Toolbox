import { describe, expect, it } from 'vitest';

import {
  ANGSTROM_DENSITY_TO_BOHR_DENSITY,
  densityDisplayFor,
  fromDisplayedDensity,
  toDisplayedDensity,
} from './densityUnits';

describe('density display units', () => {
  it('converts inverse cubic angstrom values to inverse cubic bohr', () => {
    const display = densityDisplayFor('1/Angstrom^3', 'bohr-3');

    expect(display.convertible).toBe(true);
    expect(display.units).toBe('bohr⁻³');
    expect(display.scale).toBeCloseTo(0.148184711171, 12);
    expect(toDisplayedDensity(1, display)).toBeCloseTo(
      ANGSTROM_DENSITY_TO_BOHR_DENSITY,
      14,
    );
    expect(fromDisplayedDensity(toDisplayedDensity(0.0546529696, display), display)).toBeCloseTo(
      0.0546529696,
      14,
    );
  });

  it('uses a compact angstrom label without changing the value', () => {
    const display = densityDisplayFor('1/Angstrom^3', 'angstrom-3');

    expect(display).toEqual({ convertible: true, scale: 1, units: 'Å⁻³' });
  });

  it('leaves non-density channels unchanged', () => {
    expect(densityDisplayFor('arbitrary', 'bohr-3')).toEqual({
      convertible: false,
      scale: 1,
      units: 'arbitrary',
    });
  });
});
