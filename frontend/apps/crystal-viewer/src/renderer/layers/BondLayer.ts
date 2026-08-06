import { BatchedMesh, CylinderGeometry, MeshPhysicalMaterial, Vector3, type Color } from 'three';

import type { BondInstanceSpec, AtomicSceneSpec, SiteSpec, ViewerOptions } from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';
import { color, cylinderMatrix, geometryCapacity } from '../geometry';

interface BondRecord {
  bond: BondInstanceSpec;
  half: 'from' | 'to';
  hydrogen: boolean;
}

export class BondLayer {
  readonly mesh: BatchedMesh;
  private readonly records = new Map<number, BondRecord>();

  constructor(
    scene: AtomicSceneSpec,
    private options: ViewerOptions,
    theme: ViewerTheme,
  ) {
    const radialSegments = scene.bondInstances.length > 5000 ? 8 : 16;
    // Each colored half narrows toward the bond midpoint and blends slightly beneath its atom.
    const fromGeometry = new CylinderGeometry(0.86, 1.16, 1, radialSegments);
    const toGeometry = new CylinderGeometry(1.16, 0.86, 1, radialSegments);
    const capacity = geometryCapacity([fromGeometry, toGeometry]);
    const material = new MeshPhysicalMaterial({
      color: 0xffffff,
      metalness: theme.bond.metalness,
      roughness: theme.bond.roughness,
      clearcoat: theme.bond.clearcoat,
      clearcoatRoughness: theme.bond.clearcoatRoughness,
    });
    this.mesh = new BatchedMesh(
      Math.max(scene.bondInstances.length * 6, 1),
      capacity.vertices,
      capacity.indices,
      material,
    );
    this.mesh.name = 'crystal-bonds';
    this.mesh.sortObjects = false;
    const fromGeometryId = this.mesh.addGeometry(fromGeometry);
    const toGeometryId = this.mesh.addGeometry(toGeometry);
    fromGeometry.dispose();
    toGeometry.dispose();
    const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    for (const bond of scene.bondInstances) {
      const hydrogen =
        this.isHydrogen(sites, bond.fromSiteIndex) || this.isHydrogen(sites, bond.toSiteIndex);
      const lanes = this.options.showBondOrders
        ? Math.max(1, Math.min(3, Math.round(bond.order ?? 1)))
        : 1;
      const offsets = this.bondOffsets(bond, lanes);
      for (const offset of offsets) {
        const start = this.shift(bond.start, offset);
        const end = this.shift(bond.end, offset);
        const midpoint = start.map(
          (entry, index) => (entry + end[index]) * 0.5,
        ) as BondInstanceSpec['start'];
        this.addHalf(
          fromGeometryId,
          bond,
          'from',
          start,
          midpoint,
          this.siteColor(sites, bond.fromSiteIndex),
          hydrogen,
        );
        this.addHalf(
          toGeometryId,
          bond,
          'to',
          midpoint,
          end,
          this.siteColor(sites, bond.toSiteIndex),
          hydrogen,
        );
      }
    }
    this.mesh.computeBoundingBox();
    this.mesh.computeBoundingSphere();
    this.updateVisibility(options);
  }

  get(batchId: number): BondInstanceSpec | undefined {
    return this.records.get(batchId)?.bond;
  }

  isBondVisible(bondId: string): boolean {
    for (const [batchId, record] of this.records) {
      if (record.bond.id === bondId && this.mesh.getVisibleAt(batchId)) return true;
    }
    return false;
  }

  updateVisibility(options: ViewerOptions): void {
    this.options = options;
    for (const [batchId, record] of this.records) {
      const visible =
        options.showBonds &&
        (options.showHydrogens || !record.hydrogen) &&
        (record.bond.visibility === 'base' ||
          options.showBondedOutside ||
          (!options.hideIncompleteBonds && record.half === 'from'));
      this.mesh.setVisibleAt(batchId, visible);
    }
  }

  updateTheme(theme: ViewerTheme): void {
    const material = this.mesh.material as MeshPhysicalMaterial;
    material.metalness = theme.bond.metalness;
    material.roughness = theme.bond.roughness;
    material.clearcoat = theme.bond.clearcoat;
    material.clearcoatRoughness = theme.bond.clearcoatRoughness;
    material.needsUpdate = true;
  }

  dispose(): void {
    this.mesh.dispose();
    (this.mesh.material as MeshPhysicalMaterial).dispose();
  }

  private addHalf(
    geometryId: number,
    bond: BondInstanceSpec,
    half: BondRecord['half'],
    start: BondInstanceSpec['start'],
    end: BondInstanceSpec['end'],
    tint: Color,
    hydrogen: boolean,
  ): void {
    const batchId = this.mesh.addInstance(geometryId);
    this.mesh.setMatrixAt(batchId, cylinderMatrix(start, end, this.options.bondRadius));
    this.mesh.setColorAt(batchId, tint);
    this.records.set(batchId, { bond, half, hydrogen });
  }

  private siteColor(sites: Map<number, SiteSpec>, siteIndex: number): Color {
    const component = sites.get(siteIndex)?.species[0];
    if (!component) return color([160, 160, 160]);
    return color(this.options.colorMode === 'vesta' ? component.colorVesta : component.colorJmol);
  }

  private isHydrogen(sites: Map<number, SiteSpec>, siteIndex: number): boolean {
    return sites.get(siteIndex)?.species.every((component) => component.symbol === 'H') ?? false;
  }

  private bondOffsets(bond: BondInstanceSpec, lanes: number): Vector3[] {
    if (lanes === 1) return [new Vector3()];
    const direction = new Vector3(...bond.end).sub(new Vector3(...bond.start)).normalize();
    const candidates = [new Vector3(1, 0, 0), new Vector3(0, 1, 0), new Vector3(0, 0, 1)];
    candidates.sort(
      (first, second) => Math.abs(direction.dot(first)) - Math.abs(direction.dot(second)),
    );
    const perpendicular = new Vector3().crossVectors(direction, candidates[0]).normalize();
    const spacing = Math.max(this.options.bondRadius * 2.6, 0.08);
    const positions = lanes === 2 ? [-0.5, 0.5] : [-1, 0, 1];
    return positions.map((position) => perpendicular.clone().multiplyScalar(position * spacing));
  }

  private shift(point: BondInstanceSpec['start'], offset: Vector3): BondInstanceSpec['start'] {
    return [point[0] + offset.x, point[1] + offset.y, point[2] + offset.z];
  }
}
