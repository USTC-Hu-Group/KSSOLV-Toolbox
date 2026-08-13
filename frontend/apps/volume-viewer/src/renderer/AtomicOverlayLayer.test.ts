import {
  Color,
  LineBasicMaterial,
  LineSegments,
  Mesh,
  MeshPhysicalMaterial,
} from 'three';

import type { CrystalSceneSpec } from '@kssolv/atomic-scene';
import { describe, expect, it } from 'vitest';

import { defaultVolumeAppearance, type VolumeOptions } from '../state/volumeStore';
import { AtomicOverlayLayer } from './AtomicOverlayLayer';

const scene = (): CrystalSceneSpec => ({
  schemaVersion: '2.0',
  kind: 'crystal',
  requestId: 'bounds-test',
  sites: [
    {
      id: 'site-0',
      siteIndex: 0,
      label: 'Si',
      species: [
        {
          symbol: 'Si',
          occupancy: 1,
          atomicNumber: 14,
          colorVesta: [35, 69, 250],
          colorJmol: [240, 200, 160],
          atomicRadius: 2,
        },
      ],
      fractional: [10, 0, 0],
      cartesian: [20, 0, 0],
    },
  ],
  atomInstances: [
    {
      id: 'site-0@10,0,0',
      siteId: 'site-0',
      siteIndex: 0,
      imageOffset: [10, 0, 0],
      position: [20, 0, 0],
      visibility: 'bonded',
    },
  ],
  bondRelations: [],
  bondInstances: [],
  polyhedra: [],
  structure: {
    formula: 'Si',
    lattice: [
      [2, 0, 0],
      [0, 2, 0],
      [0, 0, 2],
    ],
    periodic: [true, true, true],
    repeat: [1, 1, 1],
    siteCount: 1,
    isOrdered: true,
  },
  analysis: {
    algorithm: 'CrystalNN',
    parameters: {},
    source: 'matgenlab',
    sourceVersion: 'test',
    elapsedMilliseconds: 0,
  },
  warnings: [],
});

describe('atomic overlay bounds', () => {
  it('include atoms outside the unit cell for joint camera fitting', () => {
    const layer = new AtomicOverlayLayer(scene());
    const bounds = layer.getBounds();

    expect(bounds.min.x).toBeLessThanOrEqual(0);
    expect(bounds.max.x).toBeGreaterThan(20.5);

    layer.dispose();
  });

  it('applies the crystal viewer radius, color, and theme choices', () => {
    const layer = new AtomicOverlayLayer(scene(), {
      ...defaultVolumeAppearance(),
      theme: 'gleamoe-premiror',
      colorMode: 'jmol',
      radiusMode: 'uniform',
      atomScale: 0.6,
    });
    const meshes: Mesh[] = [];
    layer.traverse((entry) => {
      if (entry instanceof Mesh) meshes.push(entry);
    });
    expect(meshes).toHaveLength(1);
    meshes[0].geometry.computeBoundingSphere();
    expect(meshes[0].geometry.boundingSphere?.radius).toBeCloseTo(0.3, 4);
    expect(meshes[0].material).toBeInstanceOf(MeshPhysicalMaterial);
    expect((meshes[0].material as MeshPhysicalMaterial).color.getHex()).toBe(
      new Color(240 / 255, 200 / 255, 160 / 255).getHex(),
    );

    const cellMaterial = (layer.children[3].children[0] as LineSegments)
      .material;
    expect(cellMaterial).toBeInstanceOf(LineBasicMaterial);
    expect((cellMaterial as LineBasicMaterial).color.getHex()).toBe(0x85bde7);
    layer.dispose();
  });

  it('matches crystal visibility rules for image atoms, bonded atoms, bonds, and magmoms', () => {
    const fixture = scene();
    fixture.sites[0].magmom = [0, 0, 2];
    fixture.atomInstances = [
      { ...fixture.atomInstances[0], id: 'base', position: [0, 0, 0], visibility: 'base' },
      { ...fixture.atomInstances[0], id: 'boundary', position: [2, 0, 0], visibility: 'boundary' },
      { ...fixture.atomInstances[0], id: 'bonded', position: [3, 0, 0], visibility: 'bonded' },
    ];
    fixture.bondInstances = [{
      id: 'bonded-bond',
      relationId: 'relation',
      fromSiteIndex: 0,
      toSiteIndex: 0,
      fromImage: [0, 0, 0],
      toImage: [1, 0, 0],
      start: [0, 0, 0],
      end: [3, 0, 0],
      distance: 3,
      visibility: 'bonded',
    }];
    fixture.polyhedra = [{
      id: 'bonded-polyhedron',
      centerSiteIndex: 0,
      center: [0, 0, 0],
      vertices: [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
      color: [35, 69, 250],
      visibility: 'bonded',
    }];
    const layer = new AtomicOverlayLayer(fixture);
    const visibility = {
      showAtoms: true,
      showBonds: true,
      showCell: true,
      showPolyhedra: true,
      showBoundaryAtoms: false,
      showBondedOutside: false,
      hideIncompleteBonds: true,
      showMagmoms: false,
    } as VolumeOptions;

    layer.setVisibility(visibility);
    expect(layer.children[2].children.map((child) => child.visible)).toEqual([
      true, false, false,
    ]);
    expect(layer.children[1].children.map((child) => child.visible)).toEqual([false, false]);
    expect(layer.children[0].children[0].visible).toBe(false);
    expect(layer.children[4].visible).toBe(false);
    expect(layer.pickableObjects()).toHaveLength(1);
    expect(layer.selectionForObject(layer.children[2].children[0])).toMatchObject({
      kind: 'atom',
      id: 'base',
      site: { siteIndex: 0 },
    });

    layer.setVisibility({
      ...visibility,
      showBoundaryAtoms: true,
      showBondedOutside: true,
      showMagmoms: true,
    });
    expect(layer.children[2].children.every((child) => child.visible)).toBe(true);
    expect(layer.children[1].children.every((child) => child.visible)).toBe(true);
    expect(layer.children[0].children[0].visible).toBe(true);
    expect(layer.children[4].children).toHaveLength(2);
    expect(layer.children[4].visible).toBe(true);
    expect(layer.pickableObjects()).toHaveLength(5);
    expect(layer.selectionForObject(layer.children[1].children[0])).toMatchObject({
      kind: 'bond',
      id: 'bonded-bond',
      bond: { distance: 3 },
    });

    layer.setVisibility({
      ...visibility,
      hideIncompleteBonds: false,
    });
    expect(layer.children[1].children.map((child) => child.visible)).toEqual([true, false]);
    layer.dispose();
  });
});
