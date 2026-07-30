import {
  BatchedMesh,
  ConeGeometry,
  CylinderGeometry,
  MeshStandardMaterial,
  type BufferGeometry,
} from 'three';

import type { AtomicSceneSpec, Vector3Tuple, ViewerOptions } from '../../scene/types';
import { color, cylinderMatrix, geometryCapacity } from '../geometry';

interface ArrowGeometry {
  shaft: CylinderGeometry;
  head: ConeGeometry;
}

const addVector = (first: Vector3Tuple, second: Vector3Tuple): Vector3Tuple => [
  first[0] + second[0],
  first[1] + second[1],
  first[2] + second[2],
];

const scaleVector = (value: Vector3Tuple, scalar: number): Vector3Tuple => [
  value[0] * scalar,
  value[1] * scalar,
  value[2] * scalar,
];

export class MagmomLayer {
  readonly mesh?: BatchedMesh;

  constructor(scene: AtomicSceneSpec, options: ViewerOptions) {
    const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    const atoms = scene.atomInstances.filter((atom) => {
      const magmom = sites.get(atom.siteIndex)?.magmom;
      return atom.visibility === 'base' && magmom && Math.hypot(...magmom) >= 1e-12;
    });
    if (atoms.length === 0) return;
    const geometries: ArrowGeometry = {
      shaft: new CylinderGeometry(1, 1, 1, 10),
      head: new ConeGeometry(1, 1, 12),
    };
    const capacity = geometryCapacity(Object.values(geometries) as BufferGeometry[]);
    this.mesh = new BatchedMesh(
      atoms.length * 2,
      capacity.vertices,
      capacity.indices,
      new MeshStandardMaterial({ color: 0xffffff, roughness: 0.36 }),
    );
    this.mesh.name = 'crystal-magnetic-moments';
    const shaftId = this.mesh.addGeometry(geometries.shaft);
    const headId = this.mesh.addGeometry(geometries.head);
    geometries.shaft.dispose();
    geometries.head.dispose();
    for (const atom of atoms) {
      const magmom = sites.get(atom.siteIndex)?.magmom;
      if (!magmom) continue;
      const norm = Math.hypot(...magmom);
      if (norm < 1e-12) continue;
      const direction = scaleVector(magmom, 1 / norm);
      const length = Math.min(Math.max(norm * 0.3, 0.7), 2.4);
      const shaftEnd = addVector(atom.position, scaleVector(direction, length * 0.72));
      const tip = addVector(atom.position, scaleVector(direction, length));
      const shaft = this.mesh.addInstance(shaftId);
      this.mesh.setMatrixAt(shaft, cylinderMatrix(atom.position, shaftEnd, 0.055));
      this.mesh.setColorAt(shaft, color([53, 99, 190]));
      const head = this.mesh.addInstance(headId);
      this.mesh.setMatrixAt(head, cylinderMatrix(shaftEnd, tip, 0.14));
      this.mesh.setColorAt(head, color([53, 99, 190]));
    }
    this.mesh.visible = options.showMagmoms;
  }

  setVisible(visible: boolean): void {
    if (this.mesh) this.mesh.visible = visible;
  }

  dispose(): void {
    if (!this.mesh) return;
    this.mesh.dispose();
    (this.mesh.material as MeshStandardMaterial).dispose();
  }
}
