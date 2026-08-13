import { FrontSide, MeshPhongMaterial, MeshPhysicalMaterial } from 'three';
import { describe, expect, it } from 'vitest';

import {
  createBlankDebugScene,
  createDebugMoleculeScene,
  createDebugScene,
} from '../../scene/debugScene';
import { defaultViewerOptions } from '../../scene/types';
import { themes } from '../../themes/themes';
import { AtomLayer, atomGeometryCacheMetrics, clearAtomGeometryCache } from './AtomLayer';
import { BondLayer } from './BondLayer';
import { CellLayer } from './CellLayer';
import { MagmomLayer } from './MagmomLayer';
import { MeasurementLayer, measurementLineWidths } from './MeasurementLayer';
import { PolyhedronLayer } from './PolyhedronLayer';

describe('batched crystal layers', () => {
  it('constructs empty atom, bond, and cell layers without errors', () => {
    const scene = createBlankDebugScene();
    const options = defaultViewerOptions();
    const atoms = new AtomLayer(scene, options, themes.materials);
    const bonds = new BondLayer(scene, options, themes.materials);
    const cell = new CellLayer(scene, themes.materials);

    expect(atoms.mesh.instanceCount).toBe(0);
    expect(bonds.mesh.instanceCount).toBe(0);
    expect(cell.lines.geometry.getAttribute('position').count).toBe(24);

    atoms.dispose();
    bonds.dispose();
    cell.dispose();
  });

  it('batches atom occupancy segments and supports visibility groups', () => {
    const scene = createDebugScene();
    scene.sites[0].species = [
      { ...scene.sites[0].species[0], occupancy: 0.6 },
      {
        ...scene.sites[1].species[0],
        occupancy: 0.3,
      },
    ];
    const options = defaultViewerOptions();
    const layer = new AtomLayer(scene, options, themes.materials);
    expect(layer.mesh.instanceCount).toBeGreaterThan(scene.atomInstances.length);
    layer.updateVisibility({ ...options, showBoundaryAtoms: false });
    const boundaryBatch = [...Array(layer.mesh.instanceCount).keys()].find(
      (id) => layer.get(id)?.atom.visibility === 'boundary',
    );
    expect(boundaryBatch).toBeDefined();
    expect(layer.mesh.getVisibleAt(boundaryBatch!)).toBe(false);
    expect(layer.isAtomVisible(layer.get(boundaryBatch!)!.atom.id)).toBe(false);
    layer.dispose();
  });

  it('reuses bounded sphere geometry across scene loads', () => {
    clearAtomGeometryCache();
    const scene = createDebugScene();
    const first = new AtomLayer(scene, defaultViewerOptions(), themes.materials);
    const firstMetrics = atomGeometryCacheMetrics();
    const second = new AtomLayer(scene, defaultViewerOptions(), themes.materials);
    const secondMetrics = atomGeometryCacheMetrics();

    expect(firstMetrics.misses).toBeGreaterThan(0);
    expect(secondMetrics.misses).toBe(firstMetrics.misses);
    expect(secondMetrics.hits).toBeGreaterThan(firstMetrics.hits);
    expect(secondMetrics.entries).toBeLessThanOrEqual(32);
    first.dispose();
    second.dispose();
    clearAtomGeometryCache();
  });

  it('uses two colored halves per bond and toggles bonded-outside geometry', () => {
    const scene = createDebugScene();
    const options = { ...defaultViewerOptions(), showBondedOutside: false };
    const layer = new BondLayer(scene, options, themes.materials);
    expect(layer.mesh.instanceCount).toBe(scene.bondInstances.length * 2);
    expect(layer.mesh.getGeometryIdAt(0)).not.toBe(layer.mesh.getGeometryIdAt(1));
    const outside = [...Array(layer.mesh.instanceCount).keys()].find(
      (id) => layer.get(id)?.visibility === 'bonded',
    );
    expect(outside).toBeDefined();
    expect(layer.mesh.getVisibleAt(outside!)).toBe(false);
    layer.updateVisibility({ ...options, hideIncompleteBonds: false });
    const visibleOutsideHalves = [...Array(layer.mesh.instanceCount).keys()].filter(
      (id) => layer.get(id)?.visibility === 'bonded' && layer.mesh.getVisibleAt(id),
    );
    expect(visibleOutsideHalves).toHaveLength(
      scene.bondInstances.filter((bond) => bond.visibility === 'bonded').length,
    );
    layer.updateVisibility({ ...options, showBondedOutside: true });
    expect(layer.mesh.getVisibleAt(outside!)).toBe(true);
    const outsideBond = layer.get(outside!);
    expect(layer.isBondVisible(outsideBond!.id)).toBe(true);
    layer.updateVisibility({ ...options, showBonds: false });
    expect(layer.isBondVisible(outsideBond!.id)).toBe(false);
    layer.dispose();
  });

  it('keeps Materials on fast Phong unless physical quality is enabled', () => {
    const scene = createDebugScene();
    const options = defaultViewerOptions();
    const materialsFast = new AtomLayer(scene, options, themes.materials);
    const materialsQuality = new AtomLayer(
      scene,
      { ...options, renderMode: 'quality', renderQuality: 'high' },
      themes.materials,
    );
    const materialsMaterial = materialsQuality.mesh.material as MeshPhysicalMaterial;
    expect(materialsFast.mesh.material).toBeInstanceOf(MeshPhongMaterial);
    expect(materialsQuality.mesh.material).toBeInstanceOf(MeshPhysicalMaterial);
    expect(materialsMaterial.side).toBe(FrontSide);
    expect(materialsMaterial.roughness).toBeLessThan(0.1);
    expect(materialsMaterial.clearcoat).toBe(1);
    expect(materialsMaterial.clearcoatRoughness).toBeLessThan(0.02);
    expect(materialsMaterial.reflectivity).toBe(1);
    expect(materialsMaterial.transmission).toBeGreaterThan(0);
    expect(materialsMaterial.thickness).toBeGreaterThan(0);
    materialsFast.dispose();
    materialsQuality.dispose();
  });

  it('builds repeated-cell and coordination polyhedron geometry', () => {
    const scene = createDebugScene();
    scene.structure.repeat = [2, 1, 1];
    const cell = new CellLayer(scene, themes.materials);
    cell.lines.geometry.computeBoundingBox();
    expect(cell.lines.geometry.boundingBox?.max.x).toBeCloseTo(11.28);
    // Two adjacent visual cells have 20 distinct single-cell edges, including
    // the four edges of the internal division between them.
    expect(cell.lines.geometry.getAttribute('position').count).toBe(40);
    const options = defaultViewerOptions();
    const materialsPolyhedra = new PolyhedronLayer(scene, options, themes.materials);
    expect(materialsPolyhedra.mesh?.instanceCount).toBe(1);
    expect((materialsPolyhedra.mesh?.material as MeshPhysicalMaterial).opacity).toBe(
      options.polyhedronOpacity * 1.3,
    );
    const gleamoePolyhedra = new PolyhedronLayer(scene, options, themes['gleamoe-premiror']);
    expect((gleamoePolyhedra.mesh?.material as MeshPhysicalMaterial).opacity).toBeCloseTo(
      options.polyhedronOpacity * 0.44,
    );
    expect(gleamoePolyhedra.group.children).toHaveLength(3);
    materialsPolyhedra.dispose();
    gleamoePolyhedra.dispose();
    cell.dispose();
  });

  it('uses visible screen-space widths for measurement segments and angle arcs', () => {
    const layer = new MeasurementLayer(themes.materials);
    layer.setAnnotations([
      {
        id: 'angle-width-test',
        kind: 'angle',
        label: 'Angle: 90°',
        points: [
          [1, 0, 0],
          [0, 0, 0],
          [0, 1, 0],
        ],
        segments: [
          [0, 0, 0, 1, 0, 0],
          [0, 0, 0, 0, 1, 0],
        ],
        planePoints: [],
      },
    ]);

    const widths: number[] = [];
    layer.group.traverse((object) => {
      if (!('material' in object)) return;
      const material = object.material as { linewidth?: number };
      if (typeof material.linewidth === 'number') widths.push(material.linewidth);
    });
    expect(widths).toContain(measurementLineWidths.segment);
    expect(widths).toContain(measurementLineWidths.angleArc);
    layer.dispose();
  });

  it('renders molecular double bonds and hides hydrogen geometry together', () => {
    const scene = createDebugMoleculeScene();
    const options = defaultViewerOptions();
    const bonds = new BondLayer(scene, options, themes.materials);
    expect(bonds.mesh.instanceCount).toBe(4);
    bonds.dispose();

    const hydrogenSite = {
      ...scene.sites[1],
      species: [
        {
          ...scene.sites[1].species[0],
          symbol: 'H',
          atomicNumber: 1,
        },
      ],
    };
    scene.sites[1] = hydrogenSite;
    const atoms = new AtomLayer(scene, options, themes.materials);
    atoms.updateVisibility({ ...options, showHydrogens: false });
    const hydrogenBatch = [...Array(atoms.mesh.instanceCount).keys()].find(
      (id) => atoms.get(id)?.site.siteIndex === 1,
    );
    expect(atoms.mesh.getVisibleAt(hydrogenBatch!)).toBe(false);
    atoms.dispose();
  });

  it('constructs a 10,000-atom batch without per-atom meshes', () => {
    const scene = createDebugScene();
    const base = scene.atomInstances[0];
    scene.atomInstances = Array.from({ length: 10_000 }, (_, index) => ({
      ...base,
      id: `stress-${index}`,
      imageOffset: [index, 0, 0] as [number, number, number],
      position: [(index % 100) * 2, Math.floor(index / 100) * 2, 0] as [number, number, number],
      visibility: index === 0 ? ('base' as const) : ('repeat' as const),
    }));
    const started = performance.now();
    const layer = new AtomLayer(scene, defaultViewerOptions(), themes.materials);
    expect(layer.mesh.instanceCount).toBe(10_000);
    expect(performance.now() - started).toBeLessThan(3_000);
    layer.dispose();
  });

  it('batches magnetic-moment arrows only for nonzero vectors', () => {
    const scene = createDebugScene();
    scene.sites[0].magmom = [0, 0, 2];
    const layer = new MagmomLayer(scene, defaultViewerOptions());
    expect(layer.mesh?.instanceCount).toBe(2);
    layer.setVisible(false);
    expect(layer.mesh?.visible).toBe(false);
    layer.dispose();
    scene.sites[0].magmom = [0, 0, 0];
    expect(new MagmomLayer(scene, defaultViewerOptions()).mesh).toBeUndefined();
  });
});
