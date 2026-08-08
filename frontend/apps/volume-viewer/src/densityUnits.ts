export type DensityDisplayUnit = 'angstrom-3' | 'bohr-3';

// Keep this consistent with matgenlab's UnitConstants.bohr_to_angstrom.
export const BOHR_TO_ANGSTROM = 0.529177210544;
export const ANGSTROM_DENSITY_TO_BOHR_DENSITY = BOHR_TO_ANGSTROM ** 3;

const inverseCubicAngstromUnits = new Set([
  '1/Angstrom^3',
  '1/Å^3',
  'Å^-3',
  'Å⁻³',
  'e/Angstrom^3',
  'e/Å^3',
  'e/Å³',
]);

export interface DensityDisplay {
  convertible: boolean;
  scale: number;
  units: string;
}

export const densityDisplayFor = (
  sourceUnits: string,
  requested: DensityDisplayUnit,
): DensityDisplay => {
  if (!inverseCubicAngstromUnits.has(sourceUnits)) {
    return { convertible: false, scale: 1, units: sourceUnits };
  }
  return requested === 'bohr-3'
    ? {
        convertible: true,
        scale: ANGSTROM_DENSITY_TO_BOHR_DENSITY,
        units: 'bohr⁻³',
      }
    : { convertible: true, scale: 1, units: 'Å⁻³' };
};

export const toDisplayedDensity = (value: number, display: DensityDisplay): number =>
  value * display.scale;

export const fromDisplayedDensity = (value: number, display: DensityDisplay): number =>
  value / display.scale;
