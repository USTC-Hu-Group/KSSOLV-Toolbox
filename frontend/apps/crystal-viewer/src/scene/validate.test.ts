import { describe, expect, it } from 'vitest';

import { createBlankDebugScene, createDebugMoleculeScene, createDebugScene } from './debugScene';
import type { BondAlgorithm } from './types';
import { scientificSceneFingerprint, SceneValidationError, validateScene } from './validate';

describe('CrystalSceneSpec validation', () => {
  it('accepts the complete debug scene', () => {
    const scene = createDebugScene();
    expect(validateScene(scene)).toBe(scene);
  });

  it('accepts the slab view hint and rejects unsupported hints', () => {
    const slab = createDebugScene();
    slab.viewHint = 'slab';
    expect(validateScene(slab)).toBe(slab);

    const unsupported = createDebugScene() as unknown as { viewHint: string };
    unsupported.viewHint = 'surface';
    expect(() => validateScene(unsupported)).toThrow(/unsupported view hint/);
  });

  it('validates optional user adsorbate fragments at the scene boundary', () => {
    const scene = createDebugScene();
    scene.modeling = {
      adsorbateFragments: [
        {
          id: 'user-formyl-o',
          label: 'User formyl · O anchor',
          formula: 'CO',
          species: ['O', 'C'],
          coordinates: [
            [0, 0, 0],
            [1.2, 0, 0],
          ],
          bonds: [[0, 1, 2]],
          anchorAtomIndex: 0,
          orientation: [1, 0, 0],
          defaultHostBondLength: 2,
          source: 'user',
        },
      ],
      constructionBonds: [
        {
          firstElement: 'C',
          secondElement: 'O',
          bondOrder: 1,
          value: 1.43,
          unit: 'angstrom',
          parameterSet: 'kssolv-generic-mm-parameters-v2',
          source: 'frozen-pymatgen-bond-lengths',
          fallback: false,
        },
      ],
    };
    expect(validateScene(scene)).toBe(scene);
    scene.modeling.adsorbateFragments[0]!.anchorAtomIndex = 2;
    expect(() => validateScene(scene)).toThrow(/unknown atom/);
  });

  it('rejects malformed or duplicate construction bond parameters', () => {
    const scene = createDebugScene();
    const parameter = {
      firstElement: 'C',
      secondElement: 'O',
      bondOrder: 1,
      value: 1.43,
      unit: 'angstrom' as const,
      parameterSet: 'kssolv-generic-mm-parameters-v2',
      source: 'frozen-pymatgen-bond-lengths',
      fallback: false,
    };
    scene.modeling = { adsorbateFragments: [], constructionBonds: [parameter, parameter] };
    expect(() => validateScene(scene)).toThrow(/keys must be unique/);
    scene.modeling.constructionBonds = [{ ...parameter, value: 0 }];
    expect(() => validateScene(scene)).toThrow(/must be positive/);
  });

  it('accepts every Crystal Toolkit bonding strategy exposed by the viewer', () => {
    const algorithms: BondAlgorithm[] = [
      'CrystalNN',
      'CutOffDictNN',
      'JmolNN',
      'MinimumDistanceNN',
      'MinimumOKeeffeNN',
      'EconNN',
      'BrunnerNNReciprocal',
    ];
    for (const algorithm of algorithms) {
      const scene = createDebugScene();
      scene.analysis.algorithm = algorithm;
      expect(validateScene(scene).analysis.algorithm).toBe(algorithm);
    }
  });

  it('accepts None only for a strictly empty crystal scene', () => {
    const blank = createBlankDebugScene();
    expect(validateScene(blank)).toBe(blank);

    const populated = createDebugScene();
    populated.analysis.algorithm = 'None';
    expect(() => validateScene(populated)).toThrow(/unsupported algorithm/);

    const malformed = createBlankDebugScene();
    malformed.atomInstances.push(createDebugScene().atomInstances[0]);
    expect(() => validateScene(malformed)).toThrow(/atomic geometry/);
  });

  it('rejects unsupported versions and dangling site references', () => {
    expect(() => validateScene({ ...createDebugScene(), schemaVersion: '1.0' })).toThrow(
      SceneValidationError,
    );
    const scene = createDebugScene();
    scene.atomInstances[0].siteIndex = 99;
    expect(() => validateScene(scene)).toThrow(/unknown site/);
  });

  it('accepts molecules and rejects crystal metadata in molecule scenes', () => {
    const molecule = createDebugMoleculeScene();
    expect(validateScene(molecule)).toBe(molecule);
    expect(() =>
      validateScene({
        ...molecule,
        structure: createDebugScene().structure,
      }),
    ).toThrow(/cannot contain crystal metadata/);
  });

  it('rejects duplicate sites and invalid occupancies', () => {
    const duplicate = createDebugScene();
    duplicate.sites[1].id = duplicate.sites[0].id;
    expect(() => validateScene(duplicate)).toThrow(/unique/);
    const occupancy = createDebugScene();
    occupancy.sites[0].species[0].occupancy = 1.1;
    expect(() => validateScene(occupancy)).toThrow(/interval/);
  });

  it('creates a fingerprint containing scientific data only', () => {
    const first = createDebugScene();
    const second = structuredClone(first);
    second.warnings.push({ code: 'UI', message: 'visual only', severity: 'info' });
    expect(scientificSceneFingerprint(first)).toBe(scientificSceneFingerprint(second));
    second.bondRelations[0].distance += 0.01;
    expect(scientificSceneFingerprint(first)).not.toBe(scientificSceneFingerprint(second));
  });
});
