import { BatchedMesh, DoubleSide, Matrix4, MeshPhysicalMaterial, Vector3 } from 'three';
import { ConvexGeometry } from 'three/examples/jsm/geometries/ConvexGeometry.js';

import type { AtomicSceneSpec, ViewerOptions } from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';
import { color, geometryCapacity } from '../geometry';

interface GeometryRecord {
  geometry: ConvexGeometry;
  polyhedronIndex: number;
}

export class PolyhedronLayer {
  readonly mesh?: BatchedMesh;
  private readonly opacityScale: number;
  private readonly visibility = new Map<
    number,
    AtomicSceneSpec['polyhedra'][number]['visibility']
  >();

  constructor(scene: AtomicSceneSpec, options: ViewerOptions, theme: ViewerTheme) {
    this.opacityScale = theme.id === 'materials' ? 1.3 : 1;
    const records: GeometryRecord[] = [];
    scene.polyhedra.forEach((polyhedron, polyhedronIndex) => {
      if (polyhedron.vertices.length < 4) return;
      records.push({
        geometry: new ConvexGeometry(polyhedron.vertices.map((entry) => new Vector3(...entry))),
        polyhedronIndex,
      });
    });
    if (records.length === 0) return;
    const capacity = geometryCapacity(records.map((record) => record.geometry));
    const material = new MeshPhysicalMaterial({
      color: 0xffffff,
      roughness: 0.5,
      metalness: 0,
      transparent: true,
      opacity: options.polyhedronOpacity * this.opacityScale,
      depthWrite: false,
      side: DoubleSide,
    });
    this.mesh = new BatchedMesh(records.length, capacity.vertices, capacity.indices, material);
    this.mesh.name = 'crystal-polyhedra';
    this.mesh.sortObjects = true;
    for (const record of records) {
      const polyhedron = scene.polyhedra[record.polyhedronIndex];
      const geometryId = this.mesh.addGeometry(record.geometry);
      const batchId = this.mesh.addInstance(geometryId);
      this.mesh.setMatrixAt(batchId, new Matrix4());
      this.mesh.setColorAt(batchId, color(polyhedron.color));
      this.visibility.set(batchId, polyhedron.visibility);
      record.geometry.dispose();
    }
    this.updateVisibility(options);
  }

  updateVisibility(options: ViewerOptions): void {
    if (!this.mesh) return;
    for (const [batchId, group] of this.visibility) {
      this.mesh.setVisibleAt(
        batchId,
        options.showPolyhedra && (group === 'base' || options.showBondedOutside),
      );
    }
    (this.mesh.material as MeshPhysicalMaterial).opacity =
      options.polyhedronOpacity * this.opacityScale;
  }

  dispose(): void {
    if (!this.mesh) return;
    this.mesh.dispose();
    (this.mesh.material as MeshPhysicalMaterial).dispose();
  }
}
