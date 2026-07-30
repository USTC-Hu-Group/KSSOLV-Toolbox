import { Color, FrontSide, MeshPhongMaterial, MeshPhysicalMaterial } from 'three';
import { describe, expect, it } from 'vitest';

import { createDebugMoleculeScene, createDebugScene } from '../../scene/debugScene';
import { defaultViewerOptions } from '../../scene/types';
import { themes } from '../../themes/themes';
import { AtomLayer } from './AtomLayer';
import { BondLayer } from './BondLayer';
import { CellLayer } from './CellLayer';
import { MagmomLayer } from './MagmomLayer';
import { PolyhedronLayer } from './PolyhedronLayer';

describe('batched crystal layers', () => {
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
    const layer = new AtomLayer(scene, options, themes.pretty);
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

  it('uses two colored halves per bond and toggles bonded-outside geometry', () => {
    const scene = createDebugScene();
    const options = { ...defaultViewerOptions(), showBondedOutside: false };
    const layer = new BondLayer(scene, options, themes.materials);
    expect(layer.mesh.instanceCount).toBe(scene.bondInstances.length * 2);
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

  it('keeps both themes on fast Phong unless physical quality is enabled', () => {
    const scene = createDebugScene();
    const options = defaultViewerOptions();
    const pretty = new AtomLayer(scene, { ...options, theme: 'pretty' }, themes.pretty);
    const materialsFast = new AtomLayer(scene, options, themes.materials);
    const materialsQuality = new AtomLayer(
      scene,
      { ...options, renderMode: 'quality', renderQuality: 'high' },
      themes.materials,
    );
    const materialsMaterial = materialsQuality.mesh.material as MeshPhysicalMaterial;
    expect(pretty.mesh.material).toBeInstanceOf(MeshPhongMaterial);
    expect(materialsFast.mesh.material).toBeInstanceOf(MeshPhongMaterial);
    expect(materialsQuality.mesh.material).toBeInstanceOf(MeshPhysicalMaterial);
    expect(materialsMaterial.side).toBe(FrontSide);
    expect(materialsMaterial.roughness).toBeLessThan(0.1);
    expect(materialsMaterial.clearcoat).toBe(1);
    expect(materialsMaterial.clearcoatRoughness).toBeLessThan(0.02);
    expect(materialsMaterial.reflectivity).toBe(1);
    expect(materialsMaterial.transmission).toBeGreaterThan(0);
    expect(materialsMaterial.thickness).toBeGreaterThan(0);
    const prettyColor = new Color();
    const materialsColor = new Color();
    pretty.mesh.getColorAt(0, prettyColor);
    materialsFast.mesh.getColorAt(0, materialsColor);
    const prettyHsl = { h: 0, s: 0, l: 0 };
    const materialsHsl = { h: 0, s: 0, l: 0 };
    prettyColor.getHSL(prettyHsl);
    materialsColor.getHSL(materialsHsl);
    expect(materialsHsl.s).toBeGreaterThan(prettyHsl.s);
    pretty.dispose();
    materialsFast.dispose();
    materialsQuality.dispose();
  });

  it('builds repeated-cell and coordination polyhedron geometry', () => {
    const scene = createDebugScene();
    scene.structure.repeat = [2, 1, 1];
    const cell = new CellLayer(scene, themes.pretty);
    cell.lines.geometry.computeBoundingBox();
    expect(cell.lines.geometry.boundingBox?.max.x).toBeCloseTo(11.28);
    const options = defaultViewerOptions();
    const prettyPolyhedra = new PolyhedronLayer(scene, options, themes.pretty);
    const materialsPolyhedra = new PolyhedronLayer(scene, options, themes.materials);
    expect(prettyPolyhedra.mesh?.instanceCount).toBe(1);
    expect((prettyPolyhedra.mesh?.material as MeshPhysicalMaterial).opacity).toBe(
      options.polyhedronOpacity,
    );
    expect((materialsPolyhedra.mesh?.material as MeshPhysicalMaterial).opacity).toBe(
      options.polyhedronOpacity * 1.3,
    );
    prettyPolyhedra.dispose();
    materialsPolyhedra.dispose();
    cell.dispose();
  });

  it('renders molecular double bonds and hides hydrogen geometry together', () => {
    const scene = createDebugMoleculeScene();
    const options = defaultViewerOptions();
    const bonds = new BondLayer(scene, options, themes.pretty);
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
    const atoms = new AtomLayer(scene, options, themes.pretty);
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
    const layer = new AtomLayer(scene, defaultViewerOptions(), themes.pretty);
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
