import { describe, expect, it } from 'vitest';

import { atomIdsForElement, primaryElementSymbol, siteSpeciesLabel } from './elementSelection';
import { createDebugScene } from './scene/debugScene';

describe('same-element atom selection', () => {
  it('finds every periodic atom instance for the selected element', () => {
    const scene = createDebugScene();

    expect(primaryElementSymbol(scene.sites[0])).toBe('Na');
    expect(atomIdsForElement(scene, 'Na')).toEqual(
      scene.atomInstances.filter((atom) => atom.siteIndex === 0).map((atom) => atom.id),
    );
    expect(atomIdsForElement(scene, 'Cl')).toEqual(['site-1@0,0,0']);
  });

  it('derives the visible identity from current species instead of a stale site label', () => {
    const site = createDebugScene().sites[0];
    site.label = 'B';
    site.species[0].symbol = 'C';

    expect(siteSpeciesLabel(site)).toBe('C');
  });
});
