import { describe, expect, it } from 'vitest';

import {
  adsorbateDraftIssue,
  adsorbateHostBondLength,
  applyConstructionBondLength,
  beginSketchDraft,
  compatibleMouseTransformFor,
  constructionBondLength,
  createAdsorbateDraft,
  crystalSurfaceNormal,
  liveGeometryValue,
  moveAdsorbateAnchor,
  pointAtBondLength,
  rotateAdsorbateAroundHostBond,
  rotatePointAroundBond,
  sketchDraftIssue,
  sketchDraftLength,
  updateSketchDraft,
} from './modelingInteraction';
import { directAdsorbateFragment } from './adsorbateFragments';

const pointerGesture = (
  button: number,
  overrides: Partial<PointerEvent> = {},
): Pick<PointerEvent, 'button' | 'ctrlKey' | 'metaKey' | 'pointerType' | 'shiftKey'> => ({
  button,
  ctrlKey: false,
  metaKey: false,
  pointerType: 'mouse',
  shiftKey: true,
  ...overrides,
});

describe('interactive sketch and live geometry', () => {
  it('validates a dragged bond draft and reports its live length', () => {
    const draft = {
      stage: 'drag-bond' as const,
      start: [0, 0, 0] as [number, number, number],
      end: [1.42, 0, 0] as [number, number, number],
      anchorSiteIndex: 0,
      element: 'C',
      bondOrder: 1,
      formalCharge: 0,
      hybridization: 'sp3' as const,
      aromatic: false,
    };
    expect(sketchDraftLength(draft)).toBeCloseTo(1.42, 12);
    expect(sketchDraftIssue(draft)).toBe('');
    expect(sketchDraftIssue({ ...draft, end: [0.1, 0, 0] })).toBe('Bond is too short');
    expect(sketchDraftIssue({ ...draft, end: [0.59, 0, 0] })).toBe('Bond is too short');
    expect(sketchDraftIssue({ ...draft, targetSiteIndex: 0 })).toBe(
      'Choose a different target atom',
    );
  });

  it('uses one generic state machine for atom placement, bond dragging, and atom connection', () => {
    const isolated = beginSketchDraft([1, 2, 3], { element: 'O', bondOrder: 1 });
    expect(isolated.stage).toBe('place-atom');
    expect(isolated.formalCharge).toBe(0);

    const connected = beginSketchDraft(
      [0, 0, 0],
      { element: 'N', bondOrder: 1.5, hybridization: 'sp2' },
      { position: [0, 0, 0], siteIndex: 4 },
    );
    expect(connected.stage).toBe('drag-bond');
    expect(connected.aromatic).toBe(true);
    const target = updateSketchDraft(connected, [1.4, 0, 0], 8);
    expect(target.stage).toBe('connect-atoms');
    expect(target.targetSiteIndex).toBe(8);
  });

  it('uses MATLAB-supplied construction geometry for click and tiny-drag bonds', () => {
    const parameters = [
      {
        firstElement: 'C',
        secondElement: 'O',
        bondOrder: 1,
        value: 1.43,
        unit: 'angstrom' as const,
        parameterSet: 'kssolv-generic-mm-parameters-v2',
        source: 'frozen-pymatgen-bond-lengths',
        fallback: false,
      },
    ];
    expect(constructionBondLength(parameters, 'O', 'C', 1)).toBe(1.43);
    expect(constructionBondLength(parameters, 'C', 'O', 2)).toBeUndefined();
    expect(applyConstructionBondLength([0, 0, 0], [0, 0, 0], 1.43, [1, 0, 0])).toEqual([
      1.43, 0, 0,
    ]);
    expect(applyConstructionBondLength([0, 0, 0], [0, 0.2, 0], 1.43, [1, 0, 0])).toEqual([
      0, 1.43, 0,
    ]);
    expect(applyConstructionBondLength([0, 0, 0], [0, 0.7, 0], 1.43, [1, 0, 0])).toEqual([
      0, 0.7, 0,
    ]);
  });

  it('computes distance, angle, and signed dihedral from hover coordinates', () => {
    expect(
      liveGeometryValue('distance', [
        [0, 0, 0],
        [0, 3, 4],
      ]),
    ).toBeCloseTo(5, 12);
    expect(
      liveGeometryValue('angle', [
        [1, 0, 0],
        [0, 0, 0],
        [0, 1, 0],
      ]),
    ).toBeCloseTo(90, 12);
    expect(
      liveGeometryValue('dihedral', [
        [0, 1, 0],
        [0, 0, 0],
        [1, 0, 0],
        [1, 0, 1],
      ]),
    ).toBeCloseTo(90, 12);
  });
});

describe('compatible mouse transforms', () => {
  it('maps Materials Studio-style modified drags without replacing camera controls', () => {
    expect(compatibleMouseTransformFor(pointerGesture(1))).toBe('move');
    expect(compatibleMouseTransformFor(pointerGesture(2))).toBe('rotate');
  });

  it('leaves ordinary mouse, touch, and platform-modified gestures to the viewer', () => {
    expect(compatibleMouseTransformFor(pointerGesture(0))).toBeUndefined();
    expect(compatibleMouseTransformFor(pointerGesture(1, { shiftKey: false }))).toBeUndefined();
    expect(
      compatibleMouseTransformFor(pointerGesture(1, { pointerType: 'touch' })),
    ).toBeUndefined();
    expect(compatibleMouseTransformFor(pointerGesture(1, { ctrlKey: true }))).toBeUndefined();
    expect(compatibleMouseTransformFor(pointerGesture(2, { metaKey: true }))).toBeUndefined();
  });
});

describe('Materials Studio-style generic adsorbate sketch geometry', () => {
  it('starts any fragment along the crystal c direction with calibrated host distance', () => {
    const normal = crystalSurfaceNormal([
      [4, 0, 0],
      [0, 4, 0],
      [1, 0, 12],
    ]);
    const oxygenHydrogen = directAdsorbateFragment('oxygen-hydrogen');
    const draft = createAdsorbateDraft(oxygenHydrogen, 7, [1, 2, 3], normal, 2);

    expect(draft.anchorSiteIndex).toBe(7);
    expect(adsorbateHostBondLength(draft)).toBeCloseTo(2, 12);
    expect(draft.stage).toBe('anchor');
    const carboxyl = createAdsorbateDraft(
      directAdsorbateFragment('carboxyl'),
      7,
      [1, 2, 3],
      normal,
    );
    expect(carboxyl.coordinates).toHaveLength(4);
    expect(carboxyl.fragment.formula).toBe('COOH');
  });

  it('uses a user fragment port orientation instead of assuming local z', () => {
    const draft = createAdsorbateDraft(
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
      },
      0,
      [0, 0, 0],
      [0, 0, 1],
    );
    expect(draft.coordinates[1]![0]).toBeCloseTo(0, 12);
    expect(draft.coordinates[1]![2]).toBeCloseTo(3.2, 12);
  });

  it('resizes a bond and rotates its free end around the selected bond axis', () => {
    expect(pointAtBondLength([0, 0, 0], [4, 0, 0], 0.96)).toEqual([0.96, 0, 0]);
    const rotated = rotatePointAroundBond([0, 1, 0], [0, 0, 0], [1, 0, 0], 90);
    expect(rotated[0]).toBeCloseTo(0, 12);
    expect(rotated[1]).toBeCloseTo(0, 12);
    expect(rotated[2]).toBeCloseTo(1, 12);
  });

  it('reports short bonds and close contacts before the transaction is submitted', () => {
    const draft = createAdsorbateDraft(
      directAdsorbateFragment('oxygen-hydrogen'),
      0,
      [0, 0, 0],
      [0, 0, 1],
    );
    expect(adsorbateDraftIssue(draft)).toBe('');
    const collapsed = moveAdsorbateAnchor(draft, [0, 0, 0.1]);
    expect(adsorbateDraftIssue(collapsed)).toBe('Host–adsorbate bond is too short');
    expect(adsorbateDraftIssue(draft, [[0, 0, 2.1]])).toMatch(/^Close contact/);
  });

  it('rotates a complete COOH group around its host bond without changing internal geometry', () => {
    const draft = createAdsorbateDraft(
      directAdsorbateFragment('carboxyl'),
      0,
      [0, 0, 0],
      [0, 0, 1],
    );
    const before = Math.hypot(
      ...draft.coordinates[1]!.map((value, index) => value - draft.coordinates[0]![index]!),
    );
    const rotated = rotateAdsorbateAroundHostBond(draft, 90);
    const after = Math.hypot(
      ...rotated.coordinates[1]!.map((value, index) => value - rotated.coordinates[0]![index]!),
    );
    expect(after).toBeCloseTo(before, 12);
    expect(rotated.coordinates[1]![0]).toBeCloseTo(0, 12);
  });
});
