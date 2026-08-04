import { describe, expect, it } from 'vitest';

import {
  canMeasure,
  measurementProgressAnnotation,
  measurementPrompt,
  measurementStopHint,
  measureScene,
} from './measurement';
import { createDebugMoleculeScene, createDebugScene } from './scene/debugScene';
import type { MoleculeSceneSpec, SiteSpec, Vector3Tuple } from './scene/types';

const moleculeScene = (coordinates: Vector3Tuple[]): MoleculeSceneSpec => {
  const scene = createDebugMoleculeScene();
  const species = scene.sites[0].species;
  scene.sites = coordinates.map((cartesian, siteIndex): SiteSpec => ({
    id: `site-${siteIndex}`,
    siteIndex,
    label: `C${siteIndex + 1}`,
    species,
    cartesian,
  }));
  scene.atomInstances = scene.sites.map((site) => ({
    id: `${site.id}@0,0,0`,
    siteId: site.id,
    siteIndex: site.siteIndex,
    imageOffset: [0, 0, 0],
    position: site.cartesian,
    visibility: 'base',
  }));
  scene.molecule.atomCount = coordinates.length;
  scene.bondRelations = [];
  scene.bondInstances = [];
  return scene;
};

describe('frontend measurements', () => {
  it('guides ordered picking for multi-atom geometry measurements', () => {
    expect(measurementPrompt('distance', 0)).toContain('first atom (1 of 2)');
    expect(measurementPrompt('distance', 1)).toContain('second atom (2 of 2)');
    expect(measurementPrompt('dihedral', 0)).toContain('terminal atom A (1 of 4)');
    expect(measurementPrompt('dihedral', 2)).toContain('central atom C (3 of 4)');
    expect(measurementPrompt('atom_plane', 0)).toContain('atom to measure (1 of 4)');
    expect(measurementPrompt('atom_plane', 3)).toContain('third plane atom (4 of 4)');
    expect(measurementPrompt('plane_plane', 3)).toContain('first atom of plane 2 (4 of 6)');
    expect(measurementPrompt('dihedral', 0)).not.toContain('stop button');
    expect(measurementStopHint).toBe('Click the stop button at any time to end measurement mode.');
  });

  it('builds candidate and fixed planes progressively while atoms are picked', () => {
    const first: Vector3Tuple = [1, 0, 0];
    const second: Vector3Tuple = [0, 0, 0];
    const third: Vector3Tuple = [0, 1, 0];
    const fourth: Vector3Tuple = [0, 1, 1];

    const firstCandidate = measurementProgressAnnotation('dihedral', [first, second], third)!;
    expect(firstCandidate.planePoints).toEqual([first, second, third]);
    expect(firstCandidate.candidatePlaneIndices).toEqual([0]);

    const firstFixed = measurementProgressAnnotation('dihedral', [first, second, third])!;
    expect(firstFixed.planePoints).toEqual([first, second, third]);
    expect(firstFixed.candidatePlaneIndices).toEqual([]);

    const secondCandidate = measurementProgressAnnotation(
      'dihedral',
      [first, second, third],
      fourth,
    )!;
    expect(secondCandidate.planePoints).toEqual([first, second, third, second, third, fourth]);
    expect(secondCandidate.candidatePlaneIndices).toEqual([1]);

    const atomPlaneCandidate = measurementProgressAnnotation(
      'atom_plane',
      [[0, 0, 2], second, first],
      third,
    )!;
    expect(atomPlaneCandidate.planePoints).toEqual([second, first, third]);
    expect(atomPlaneCandidate.projection).toEqual([0, 0, 0]);
    expect(atomPlaneCandidate.candidatePlaneIndices).toEqual([0]);

    const planeFixed = measurementProgressAnnotation('plane_plane', [first, second, third])!;
    expect(planeFixed.planePoints).toEqual([first, second, third]);
    expect(planeFixed.candidatePlaneIndices).toEqual([]);
  });

  it('measures periodic shortest distance and crystal cell values', () => {
    const scene = createDebugScene();
    scene.structure.lattice = [
      [10, 0, 0],
      [0, 10, 0],
      [0, 0, 10],
    ];
    scene.sites[0].fractional = [0.95, 0.5, 0.5];
    scene.sites[0].cartesian = [9.5, 5, 5];
    scene.sites[1].fractional = [0.05, 0.5, 0.5];
    scene.sites[1].cartesian = [0.5, 5, 5];

    const distance = measureScene(scene, 'distance', [0, 1], 'measurement-1');
    const cell = measureScene(scene, 'cell', [0], 'measurement-2');

    expect(distance.summary).toBe('Distance: 1.00000 Å');
    expect(distance.annotation.segments[0]).toEqual([9.5, 5, 5, 10.5, 5, 5]);
    expect(cell.summary).toContain('a 10.00000');
    expect(cell.details).toContain('Volume: 1000.00000 Å³');
    expect(canMeasure(scene, 'cell', 3)).toBe(true);
  });

  it('measures angle, dihedral, atom-plane distance, and plane angle', () => {
    const scene = moleculeScene([
      [1, 0, 0],
      [0, 0, 0],
      [0, 1, 0],
      [0, 1, 1],
      [0, 0, 1],
      [1, 0, 1],
      [0, 0, 2],
    ]);

    expect(measureScene(scene, 'angle', [0, 1, 2], 'a').summary).toBe('Angle: 90.000°');
    const dihedral = measureScene(scene, 'dihedral', [0, 1, 2, 3], 'd');
    expect(dihedral.summary).toContain('90.000°');
    expect(dihedral.siteLabels).toEqual(['#1 C1', '#2 C2', '#3 C3', '#4 C4']);
    expect(dihedral.diagram?.points).toHaveLength(4);
    expect(dihedral.annotation.planePoints).toEqual([
      [1, 0, 0],
      [0, 0, 0],
      [0, 1, 0],
      [0, 0, 0],
      [0, 1, 0],
      [0, 1, 1],
    ]);
    const atomPlane = measureScene(scene, 'atom_plane', [6, 1, 0, 2], 'p');
    expect(atomPlane.summary).toBe('Atom-to-plane distance: 2.00000 Å');
    expect(atomPlane.annotation.projection).toEqual([0, 0, 0]);
    expect(atomPlane.annotation.segments[0]).toEqual([0, 0, 2, 0, 0, 0]);
    expect(measureScene(scene, 'plane_plane', [1, 0, 2, 4, 5, 6], 'pp').summary).toBe(
      'Plane angle: 90.000°',
    );
  });

  it('measures distinct rendered instances of repeated crystallographic sites', () => {
    const scene = moleculeScene([
      [0, 0, 0],
      [0, 1, 0],
    ]);
    const selectedAtoms = [
      { ...scene.atomInstances[0], id: 'a', position: [1, 0, 0] as Vector3Tuple },
      { ...scene.atomInstances[0], id: 'b', position: [0, 0, 0] as Vector3Tuple },
      { ...scene.atomInstances[1], id: 'c', position: [0, 1, 0] as Vector3Tuple },
      { ...scene.atomInstances[1], id: 'd', position: [0, 1, 1] as Vector3Tuple },
    ];
    expect(
      measureScene(scene, 'dihedral', [0, 0, 1, 1], 'repeated', selectedAtoms).summary,
    ).toContain('90.000°');
    expect(
      measureScene(scene, 'distance', [0, 0], 'repeated-distance', selectedAtoms.slice(0, 2))
        .summary,
    ).toBe('Distance: 1.00000 Å');
  });

  it('uses active scene bonds for element-pair statistics and coordination', () => {
    const scene = createDebugScene();
    const statistics = measureScene(scene, 'bond_stats', [0, 1], 'stats');
    const coordination = measureScene(scene, 'coordination', [1], 'coord');
    const neighbors = measureScene(scene, 'nearest_neighbors', [1], 'neighbors');

    expect(statistics.summary).toContain('Cl–Na: 8 bonds');
    expect(statistics.details).toContain('Algorithm: CrystalNN');
    expect(statistics.bondStatistics?.pairLabel).toBe('Cl–Na');
    expect(statistics.bondStatistics?.count).toBe(8);
    expect(statistics.bondStatistics?.average).toBeCloseTo(statistics.bondStatistics!.minimum!);
    expect(statistics.bondStatistics?.maximum).toBeCloseTo(statistics.bondStatistics!.minimum!);
    expect(statistics.bondStatistics?.algorithm).toBe('CrystalNN');
    expect(statistics.annotation.segments).toHaveLength(8);
    expect(coordination.summary).toContain('coordination 8');
    expect(neighbors.details.split('\n')).toHaveLength(8);
    expect(neighbors.neighbors).toHaveLength(8);
  });

  it('reports atom data and exposes structured cell values', () => {
    const scene = createDebugScene();
    const atom = measureScene(scene, 'atom_info', [1], 'atom');
    const cell = measureScene(scene, 'cell', [], 'cell');

    expect(atom.summary).toBe('Atom #2 Cl · Cl');
    expect(atom.details).toContain('Fractional: (0.500000, 0.500000, 0.500000)');
    expect(cell.cellValues?.lengths).toEqual([5.64, 5.64, 5.64]);
    expect(cell.cellValues?.angles).toEqual([90, 90, 90]);
    expect(cell.cellValues?.volume).toBeCloseTo(179.406144);
    expect(canMeasure(scene, 'distance', 1)).toBe(false);
    expect(canMeasure(scene, 'distance', 2)).toBe(true);
  });
});
