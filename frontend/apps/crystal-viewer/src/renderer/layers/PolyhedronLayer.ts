import {
  AdditiveBlending,
  BatchedMesh,
  Color,
  DoubleSide,
  EdgesGeometry,
  Group,
  LineBasicMaterial,
  LineSegments,
  Matrix4,
  MeshPhysicalMaterial,
  Vector3,
} from 'three';
import { ConvexGeometry } from 'three/examples/jsm/geometries/ConvexGeometry.js';

import type { AtomicSceneSpec, ViewerOptions } from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';
import { color, geometryCapacity } from '../geometry';

interface GeometryRecord {
  geometry: ConvexGeometry;
  polyhedronIndex: number;
}

export class PolyhedronLayer {
  readonly group = new Group();
  readonly mesh?: BatchedMesh;
  private readonly opacityScale: number;
  private readonly edgeRecords: Array<{
    core: LineSegments;
    glow: LineSegments;
    visibility: AtomicSceneSpec['polyhedra'][number]['visibility'];
  }> = [];
  private readonly visibility = new Map<
    number,
    AtomicSceneSpec['polyhedra'][number]['visibility']
  >();

  constructor(scene: AtomicSceneSpec, options: ViewerOptions, theme: ViewerTheme) {
    const premium = theme.id === 'gleamoe-premiror';
    this.group.name = 'crystal-polyhedron-layer';
    this.opacityScale = premium ? 0.44 : theme.id === 'materials' ? 1.3 : 1;
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
      roughness: premium ? 0.085 : 0.5,
      metalness: premium ? 0.015 : 0,
      clearcoat: premium ? 1 : 0,
      clearcoatRoughness: premium ? 0.035 : 0,
      ior: premium ? 1.52 : 1.5,
      reflectivity: premium ? 0.9 : 0.5,
      specularIntensity: premium ? 1.1 : 1,
      iridescence: premium ? 0.1 : 0,
      iridescenceIOR: 1.34,
      transparent: true,
      opacity: options.polyhedronOpacity * this.opacityScale,
      depthWrite: false,
      side: DoubleSide,
    });
    this.mesh = new BatchedMesh(records.length, capacity.vertices, capacity.indices, material);
    this.mesh.name = 'crystal-polyhedra';
    this.mesh.sortObjects = true;
    this.mesh.renderOrder = premium ? 5 : 0;
    this.group.add(this.mesh);
    if (premium) {
      material.onBeforeCompile = (shader) => {
        shader.fragmentShader = shader.fragmentShader.replace(
          '#include <opaque_fragment>',
          `float gleamoeGlassFresnel = pow(1.0 - abs(dot(normalize(normal), normalize(vViewPosition))), 2.4);
          diffuseColor.a *= mix(0.48, 1.85, gleamoeGlassFresnel);
          totalEmissiveRadiance += diffuseColor.rgb * gleamoeGlassFresnel * 0.18;
          #include <opaque_fragment>`,
        );
      };
      material.customProgramCacheKey = () => 'gleamoe-polyhedron-glass-v1';
    }
    for (const record of records) {
      const polyhedron = scene.polyhedra[record.polyhedronIndex];
      const geometryId = this.mesh.addGeometry(record.geometry);
      const batchId = this.mesh.addInstance(geometryId);
      this.mesh.setMatrixAt(batchId, new Matrix4());
      this.mesh.setColorAt(batchId, color(polyhedron.color));
      this.visibility.set(batchId, polyhedron.visibility);
      if (premium) this.addGlassEdges(record.geometry, polyhedron.color, polyhedron.visibility);
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
    for (const record of this.edgeRecords) {
      const visible =
        options.showPolyhedra && (record.visibility === 'base' || options.showBondedOutside);
      record.core.visible = visible;
      record.glow.visible = visible;
    }
  }

  dispose(): void {
    if (!this.mesh) return;
    this.mesh.dispose();
    (this.mesh.material as MeshPhysicalMaterial).dispose();
    for (const record of this.edgeRecords) {
      record.core.geometry.dispose();
      (record.core.material as LineBasicMaterial).dispose();
      (record.glow.material as LineBasicMaterial).dispose();
    }
    this.group.clear();
  }

  private addGlassEdges(
    geometry: ConvexGeometry,
    tintValue: AtomicSceneSpec['polyhedra'][number]['color'],
    visibility: AtomicSceneSpec['polyhedra'][number]['visibility'],
  ): void {
    const edgeGeometry = new EdgesGeometry(geometry, 16);
    const tint = color(tintValue);
    const coreMaterial = new LineBasicMaterial({
      color: tint.clone().lerp(new Color(1, 1, 1), 0.34),
      transparent: true,
      opacity: 0.72,
      depthWrite: false,
      toneMapped: true,
    });
    const glowMaterial = new LineBasicMaterial({
      color: tint.clone().multiplyScalar(1.45),
      transparent: true,
      opacity: 0.2,
      depthWrite: false,
      blending: AdditiveBlending,
      toneMapped: true,
    });
    const core = new LineSegments(edgeGeometry, coreMaterial);
    const glow = new LineSegments(edgeGeometry, glowMaterial);
    core.renderOrder = 6;
    glow.renderOrder = 7;
    this.group.add(core, glow);
    this.edgeRecords.push({ core, glow, visibility });
  }
}
