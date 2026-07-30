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
  Vector3,
} from 'three';
import { ConvexGeometry } from 'three/addons/geometries/ConvexGeometry.js';

import type { AtomicSceneSpec, BondInstanceSpec, RgbTuple } from '@kssolv/atomic-scene';

const color = (rgb: RgbTuple): Color => new Color(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255);

const bondMesh = (bond: BondInstanceSpec, radius: number, tint: Color): Mesh => {
  const start = new Vector3(...bond.start);
  const end = new Vector3(...bond.end);
  const midpoint = start.clone().add(end).multiplyScalar(0.5);
  const direction = end.clone().sub(start);
  const geometry = new CylinderGeometry(radius, radius, direction.length(), 12);
  const mesh = new Mesh(
    geometry,
    new MeshPhongMaterial({ color: tint, shininess: 70, specular: 0xffffff }),
  );
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

  constructor(scene: AtomicSceneSpec) {
    super();
    this.add(this.polyhedronGroup, this.bondGroup, this.atomGroup, this.cellGroup);
    const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    for (const atom of scene.atomInstances) {
      const site = sites.get(atom.siteIndex);
      if (!site) continue;
      const species = site.species[0];
      const geometry = new SphereGeometry(Math.max(0.18, species.atomicRadius * 0.34), 28, 20);
      const material = new MeshPhongMaterial({
        color: color(species.colorVesta),
        shininess: 95,
        specular: 0xffffff,
      });
      this.resources.push(geometry, material);
      const mesh = new Mesh(geometry, material);
      mesh.position.fromArray(atom.position);
      this.atomGroup.add(mesh);
    }
    for (const bond of scene.bondInstances) {
      const mesh = bondMesh(bond, 0.075, new Color(0x8d95a3));
      this.resources.push(mesh.geometry, mesh.material as MeshPhongMaterial);
      this.bondGroup.add(mesh);
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
        roughness: 0.55,
        metalness: 0,
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
      const material = new LineBasicMaterial({ color: 0x6d7480, transparent: true, opacity: 0.62 });
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
