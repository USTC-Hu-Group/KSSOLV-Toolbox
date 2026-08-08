import { describe, expect, it } from 'vitest';

import { createDebugMoleculeScene, createDebugScene } from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import { atomCountLabel, visibleAtomCount } from './atomVisibility';

describe('atom visibility count', () => {
  it('shows only the total while every atom is visible', () => {
    const scene = createDebugScene();
    expect(atomCountLabel(scene, defaultViewerOptions())).toBe('9');
  });

  it('shows visible and total counts after atoms are hidden', () => {
    const scene = createDebugScene();
    const options = { ...defaultViewerOptions(), showBoundaryAtoms: false };

    expect(visibleAtomCount(scene, options)).toBe(2);
    expect(atomCountLabel(scene, options)).toBe('2/9');
    expect(atomCountLabel(scene, { ...options, showAtoms: false })).toBe('0/9');
  });

  it('counts hidden hydrogens with the same rule as the renderer', () => {
    const scene = createDebugMoleculeScene();
    scene.sites[1].species[0].symbol = 'H';

    expect(atomCountLabel(scene, { ...defaultViewerOptions(), showHydrogens: false })).toBe('1/2');
  });
});
