import {
  ConeGeometry,
  CylinderGeometry,
  Group,
  Mesh,
  MeshPhongMaterial,
  Vector3,
} from 'three';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

const arrow = (direction: Vector3, color: number): Group => {
  const group = new Group();
  const length = 1.05;
  const head = 0.24;
  const shaftGeometry = new CylinderGeometry(0.045, 0.045, length - head, 20);
  const headGeometry = new ConeGeometry(0.105, head, 24);
  const material = new MeshPhongMaterial({
    color,
    emissive: color,
    emissiveIntensity: 0.28,
    shininess: 38,
    specular: 0x4a4a4a,
  });
  const shaft = new Mesh(shaftGeometry, material);
  shaft.position.y = (length - head) / 2;
  const tip = new Mesh(headGeometry, material);
  tip.position.y = length - head / 2;
  group.add(shaft, tip);
  group.quaternion.setFromUnitVectors(new Vector3(0, 1, 0), direction.clone().normalize());
  return group;
};

export class OrientationAxes extends Group {
  constructor(grid: VolumeGridSpec) {
    super();
    const directions = grid.voxelVectors.map((entry) => new Vector3(...entry).normalize());
    this.add(
      arrow(directions[0], 0xf51f25),
      arrow(directions[1], 0x08a72b),
      arrow(directions[2], 0x174bff),
    );
  }

  dispose(): void {
    this.traverse((object) => {
      if (!(object instanceof Mesh)) return;
      object.geometry.dispose();
      (object.material as MeshPhongMaterial).dispose();
    });
    this.clear();
  }
}
