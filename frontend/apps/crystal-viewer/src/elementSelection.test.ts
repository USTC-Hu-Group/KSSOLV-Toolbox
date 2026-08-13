import { describe, expect, it } from 'vitest';

import {
  atomIdsForElement,
  connectedSiteIndices,
  primaryElementSymbol,
  siteSpeciesLabel,
} from './elementSelection';
import { createDebugMoleculeScene, createDebugScene } from './scene/debugScene';

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

  it('selects a complete bonded component by source site rather than rendered image', () => {
    const molecule = createDebugMoleculeScene();
    expect(connectedSiteIndices(molecule, 0)).toEqual(molecule.sites.map((site) => site.siteIndex));
    expect(connectedSiteIndices(molecule, 999)).toEqual([]);

    const disconnected = createDebugMoleculeScene();
    disconnected.bondRelations = disconnected.bondRelations.filter(
      (bond) => bond.fromSiteIndex !== 0 && bond.toSiteIndex !== 0,
    );
    expect(connectedSiteIndices(disconnected, 0)).toEqual([0]);
  });
});
