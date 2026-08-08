import {
  Box3,
  BufferGeometry,
  Color,
  CylinderGeometry,
  DoubleSide,
  Float32BufferAttribute,
  Group,
  LineBasicMaterial,
  LineSegments,
  Mesh,
  MeshPhongMaterial,
  MeshPhysicalMaterial,
  SphereGeometry,
  type Material,
  Vector3,
} from 'three';
import { ConvexGeometry } from 'three/addons/geometries/ConvexGeometry.js';

import {
  defaultViewerOptions,
  type AtomicSceneSpec,
  type BondInstanceSpec,
  type RgbTuple,
} from '@kssolv/atomic-scene';

import type { VolumeOptions } from '../state/volumeStore';
import {
  appearanceScale,
  scaledMetalness,
  scaledRoughness,
  volumeViewerThemes,
  type VolumeViewerTheme,
} from '../themes';

const color = (rgb: RgbTuple): Color => new Color(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255);

export type AtomicOverlayStyle = Pick<
  VolumeOptions,
  | 'theme'
  | 'colorMode'
  | 'radiusMode'
  | 'atomScale'
  | 'bondRadius'
  | 'metalness'
  | 'roughness'
>;

const viewerDefaults = defaultViewerOptions();
export const defaultAtomicOverlayStyle = (): AtomicOverlayStyle => ({
  theme: viewerDefaults.theme,
  colorMode: viewerDefaults.colorMode,
  radiusMode: viewerDefaults.radiusMode,
  atomScale: viewerDefaults.atomScale,
  bondRadius: viewerDefaults.bondRadius,
  metalness: viewerDefaults.metalness,
  roughness: viewerDefaults.roughness,
});

const atomicTint = (
  rgb: RgbTuple,
  theme: VolumeViewerTheme,
): Color => {
  const tint = color(rgb);
  if (theme.id === 'materials') tint.offsetHSL(0, 0.08, 0.01);
  return tint;
};

const atomMaterial = (
  tint: Color,
  style: AtomicOverlayStyle,
  theme: VolumeViewerTheme,
): Material =>
  theme.atom.model === 'phong'
    ? new MeshPhongMaterial({
        color: tint,
        shininess:
          theme.atom.shininess /
          Math.max(appearanceScale(style.roughness), 0.2),
        specular: new Color(0x8f8f8f).multiplyScalar(
          appearanceScale(style.metalness),
        ),
      })
    : new MeshPhysicalMaterial({
        color: tint,
        metalness: scaledMetalness(theme.atom.metalness, style.metalness),
        roughness: scaledRoughness(theme.atom.roughness, style.roughness),
        clearcoat: theme.atom.clearcoat,
        clearcoatRoughness: theme.atom.clearcoatRoughness,
      });

const bondMaterial = (
  tint: Color,
  style: AtomicOverlayStyle,
  theme: VolumeViewerTheme,
): MeshPhysicalMaterial =>
  new MeshPhysicalMaterial({
    color: tint,
    metalness: scaledMetalness(theme.bond.metalness, style.metalness),
    roughness: scaledRoughness(theme.bond.roughness, style.roughness),
    clearcoat: theme.bond.clearcoat,
    clearcoatRoughness: theme.bond.clearcoatRoughness,
  });

const bondMesh = (
  startPoint: BondInstanceSpec['start'],
  endPoint: BondInstanceSpec['end'],
  radius: number,
  material: Material,
): Mesh => {
  const start = new Vector3(...startPoint);
  const end = new Vector3(...endPoint);
  const midpoint = start.clone().add(end).multiplyScalar(0.5);
  const direction = end.clone().sub(start);
  const geometry = new CylinderGeometry(radius, radius, direction.length(), 16);
  const mesh = new Mesh(geometry, material);
  mesh.position.copy(midpoint);
  mesh.quaternion.setFromUnitVectors(new Vector3(0, 1, 0), direction.normalize());
  return mesh;
};

export class AtomicOverlayLayer extends Group {
  private readonly resources: Array<{ dispose(): void }> = [];
  private atomGroup = new Group();
  private bondGroup = new Group();
  private cellGroup = new Group();
  private polyhedronGroup = new Group();

  constructor(
    scene: AtomicSceneSpec,
    style: AtomicOverlayStyle = defaultAtomicOverlayStyle(),
  ) {
    super();
    const theme = volumeViewerThemes[style.theme];
    this.add(this.polyhedronGroup, this.bondGroup, this.atomGroup, this.cellGroup);
    const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    for (const atom of scene.atomInstances) {
      const site = sites.get(atom.siteIndex);
      if (!site) continue;
      const species = site.species[0];
      const radius =
        style.radiusMode === 'uniform'
          ? 0.5 * style.atomScale
          : Math.max(species.atomicRadius, 0.35) * style.atomScale;
      const geometry = new SphereGeometry(radius, 32, 24);
      const material = atomMaterial(
        atomicTint(
          style.colorMode === 'vesta' ? species.colorVesta : species.colorJmol,
          theme,
        ),
        style,
        theme,
      );
      this.resources.push(geometry, material);
      const mesh = new Mesh(geometry, material);
      mesh.position.fromArray(atom.position);
      this.atomGroup.add(mesh);
    }
    for (const bond of scene.bondInstances) {
      const midpoint = bond.start.map(
        (entry, index) => (entry + bond.end[index]) * 0.5,
      ) as BondInstanceSpec['start'];
      const fromSpecies = sites.get(bond.fromSiteIndex)?.species[0];
      const toSpecies = sites.get(bond.toSiteIndex)?.species[0];
      const speciesTint = (species: typeof fromSpecies): Color =>
        species
          ? atomicTint(
              style.colorMode === 'vesta' ? species.colorVesta : species.colorJmol,
              theme,
            )
          : new Color(0x8d95a3);
      const halves = [
        bondMesh(
          bond.start,
          midpoint,
          style.bondRadius,
          bondMaterial(speciesTint(fromSpecies), style, theme),
        ),
        bondMesh(
          midpoint,
          bond.end,
          style.bondRadius,
          bondMaterial(speciesTint(toSpecies), style, theme),
        ),
      ];
      for (const mesh of halves) {
        this.resources.push(mesh.geometry, mesh.material as Material);
        this.bondGroup.add(mesh);
      }
    }
    for (const polyhedron of scene.polyhedra) {
      if (polyhedron.vertices.length < 4) continue;
      const geometry = new ConvexGeometry(
        polyhedron.vertices.map((entry) => new Vector3(...entry)),
      );
      const material = new MeshPhysicalMaterial({
        color: color(polyhedron.color),
        transparent: true,
        opacity: 0.24,
        roughness: scaledRoughness(0.55, style.roughness),
        metalness: scaledMetalness(0.04, style.metalness),
        depthWrite: false,
        side: DoubleSide,
      });
      this.resources.push(geometry, material);
      this.polyhedronGroup.add(new Mesh(geometry, material));
    }
    if (scene.kind === 'crystal') {
      const [a, b, c] = scene.structure.lattice.map((entry) => new Vector3(...entry));
      const vertices: Vector3[] = [];
      for (const origin of [
        new Vector3(),
        a,
        b,
        c,
        a.clone().add(b),
        a.clone().add(c),
        b.clone().add(c),
        a.clone().add(b).add(c),
      ]) {
        vertices.push(origin);
      }
      const edgeIndices = [
        0, 1, 0, 2, 0, 3, 1, 4, 1, 5, 2, 4, 2, 6, 3, 5, 3, 6, 4, 7, 5, 7, 6, 7,
      ];
      const positions = edgeIndices.flatMap((index) => vertices[index].toArray());
      const geometry = new BufferGeometry();
      geometry.setAttribute('position', new Float32BufferAttribute(positions, 3));
      const material = new LineBasicMaterial({ color: theme.cell, transparent: true, opacity: 0.62 });
      this.resources.push(geometry, material);
      this.cellGroup.add(new LineSegments(geometry, material));
    }
  }

  setVisibility(
    atoms: boolean,
    bonds: boolean,
    cell: boolean,
    polyhedra: boolean,
  ): void {
    this.atomGroup.visible = atoms;
    this.bondGroup.visible = bonds;
    this.cellGroup.visible = cell;
    this.polyhedronGroup.visible = polyhedra;
  }

  getBounds(target = new Box3()): Box3 {
    this.updateWorldMatrix(true, true);
    return target.setFromObject(this, true);
  }

  dispose(): void {
    for (const resource of this.resources) resource.dispose();
    this.clear();
  }
}
