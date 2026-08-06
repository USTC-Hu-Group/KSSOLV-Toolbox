import {
  BatchedMesh,
  BufferGeometry,
  CircleGeometry,
  Color,
  FrontSide,
  Matrix4,
  MeshPhongMaterial,
  MeshPhysicalMaterial,
  SphereGeometry,
  type Texture,
  Vector3,
} from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

import type {
  AtomInstanceSpec,
  AtomicSceneSpec,
  SiteSpec,
  SpeciesComponent,
  ViewerOptions,
} from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';
import { encodeElementMaterialColor, installElementMaterialShader } from '../artDirection';
import { color, geometryCapacity, vector } from '../geometry';
import { renderQualityProfile } from '../quality';

interface SegmentRecord {
  atom: AtomInstanceSpec;
  site: SiteSpec;
  component: SpeciesComponent | null;
  geometryKey: string;
  phiStart: number;
  phiLength: number;
}

const sphereSegmentGeometry = (
  widthSegments: number,
  heightSegments: number,
  phiStart: number,
  phiLength: number,
): BufferGeometry => {
  const sphere = new SphereGeometry(
    1,
    widthSegments,
    heightSegments,
    phiStart,
    Math.max(phiLength, 0.001),
  );
  if (phiLength >= Math.PI * 2 - 1e-6) return sphere;
  const startCap = new CircleGeometry(1, heightSegments, -Math.PI / 2, Math.PI);
  startCap.rotateX(Math.PI / 2);
  startCap.rotateZ(phiStart);
  const endCap = startCap.clone();
  endCap.rotateZ(phiLength);
  const merged = mergeGeometries([sphere, startCap, endCap], false);
  sphere.dispose();
  startCap.dispose();
  endCap.dispose();
  return merged ?? new SphereGeometry(1, widthSegments, heightSegments);
};

export class AtomLayer {
  readonly mesh: BatchedMesh;
  private readonly saturateColors: boolean;
  private readonly artDirectedMaterials: boolean;
  private readonly records = new Map<number, SegmentRecord>();
  private readonly transforms = new Map<number, Matrix4>();

  constructor(
    scene: AtomicSceneSpec,
    private options: ViewerOptions,
    theme: ViewerTheme,
    private readonly materialsEnvironment?: Texture,
  ) {
    this.saturateColors = theme.id === 'materials';
    this.artDirectedMaterials = theme.id === 'gleamoe-premiror' && options.renderMode === 'quality';
    const siteByIndex = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    const records: SegmentRecord[] = [];
    for (const atom of scene.atomInstances) {
      const site = siteByIndex.get(atom.siteIndex);
      if (!site) continue;
      const total = site.species.reduce((sum, component) => sum + component.occupancy, 0);
      let cursor = 0;
      for (const component of site.species) {
        records.push({
          atom,
          site,
          component,
          geometryKey: `sphere:${component.occupancy.toFixed(6)}:${cursor.toFixed(6)}`,
          phiStart: cursor * Math.PI * 2,
          phiLength: component.occupancy * Math.PI * 2,
        });
        cursor += component.occupancy;
      }
      if (total < 0.999999) {
        records.push({
          atom,
          site,
          component: null,
          geometryKey: `vacancy:${(1 - total).toFixed(6)}:${cursor.toFixed(6)}`,
          phiStart: cursor * Math.PI * 2,
          phiLength: (1 - total) * Math.PI * 2,
        });
      }
    }

    const geometryByKey = new Map<string, BufferGeometry>();
    const quality = renderQualityProfile(options.renderMode, options.renderQuality);
    const [widthSegments, heightSegments] =
      scene.atomInstances.length > 5000 ? quality.largeAtomSegments : quality.atomSegments;
    for (const record of records) {
      if (!geometryByKey.has(record.geometryKey)) {
        geometryByKey.set(
          record.geometryKey,
          sphereSegmentGeometry(widthSegments, heightSegments, record.phiStart, record.phiLength),
        );
      }
    }
    const capacity = geometryCapacity(geometryByKey.values());
    const usePhysicalMaterial = options.renderMode === 'quality';
    const material = !usePhysicalMaterial
      ? new MeshPhongMaterial({
          color: 0xffffff,
          specular: 0x8f8f8f,
          shininess: theme.atom.shininess,
          side: FrontSide,
        })
      : new MeshPhysicalMaterial({
          color: 0xffffff,
          metalness: theme.atom.metalness,
          roughness: theme.atom.roughness,
          clearcoat: theme.atom.clearcoat,
          clearcoatRoughness: theme.atom.clearcoatRoughness,
          ior: theme.atom.ior,
          reflectivity: theme.atom.reflectivity,
          specularIntensity: theme.atom.specularIntensity,
          sheen: theme.atom.sheen,
          sheenColor: 0xffffff,
          sheenRoughness: 0.18,
          transmission: theme.atom.transmission,
          thickness: theme.atom.thickness,
          anisotropy: theme.atom.anisotropy,
          iridescence: theme.atom.iridescence,
          iridescenceIOR: theme.atom.iridescenceIOR,
          attenuationColor: theme.atom.attenuationColor,
          attenuationDistance: theme.atom.attenuationDistance,
          transparent: theme.atom.opacity < 1,
          opacity: theme.atom.opacity,
          envMap: materialsEnvironment,
          envMapIntensity:
            theme.id === 'gleamoe-premiror' ? 1.35 : theme.id === 'materials' ? 0.34 : 1,
          side: FrontSide,
        });
    if (material instanceof MeshPhysicalMaterial && this.artDirectedMaterials) {
      installElementMaterialShader(material);
    }
    this.mesh = new BatchedMesh(
      Math.max(records.length, 1),
      capacity.vertices,
      capacity.indices,
      material,
    );
    this.mesh.name = 'crystal-atoms';
    this.mesh.sortObjects = false;
    const geometryIds = new Map<string, number>();
    for (const [key, geometry] of geometryByKey) {
      geometryIds.set(key, this.mesh.addGeometry(geometry));
      geometry.dispose();
    }
    for (const record of records) {
      const geometryId = geometryIds.get(record.geometryKey);
      if (geometryId === undefined) continue;
      const batchId = this.mesh.addInstance(geometryId);
      const radius = this.radiusFor(record);
      const transform = new Matrix4().compose(
        vector(record.atom.position),
        this.mesh.quaternion,
        new Vector3(radius, radius, radius),
      );
      this.mesh.setMatrixAt(batchId, transform);
      this.mesh.setColorAt(batchId, this.colorFor(record));
      this.records.set(batchId, record);
      this.transforms.set(batchId, transform);
    }
    this.mesh.computeBoundingBox();
    this.mesh.computeBoundingSphere();
    this.updateVisibility(options);
  }

  get(batchId: number): { atom: AtomInstanceSpec; site: SiteSpec; radius: number } | undefined {
    const record = this.records.get(batchId);
    if (!record) return undefined;
    return { atom: record.atom, site: record.site, radius: this.radiusFor(record) };
  }

  getVisibleAtom(
    atomId: string,
  ): { atom: AtomInstanceSpec; site: SiteSpec; radius: number } | undefined {
    let match: { atom: AtomInstanceSpec; site: SiteSpec; radius: number } | undefined;
    for (const [batchId, record] of this.records) {
      if (record.atom.id !== atomId || !this.mesh.getVisibleAt(batchId)) continue;
      const radius = this.radiusFor(record);
      if (!match || radius > match.radius) match = { atom: record.atom, site: record.site, radius };
    }
    return match;
  }

  isAtomVisible(atomId: string): boolean {
    for (const [batchId, record] of this.records) {
      if (record.atom.id === atomId && this.mesh.getVisibleAt(batchId)) return true;
    }
    return false;
  }

  updateVisibility(options: ViewerOptions): void {
    this.options = options;
    for (const [batchId, record] of this.records) {
      const visible =
        options.showAtoms &&
        (options.showHydrogens ||
          !record.site.species.every((component) => component.symbol === 'H')) &&
        (record.atom.visibility === 'base' ||
          record.atom.visibility === 'repeat' ||
          (record.atom.visibility === 'boundary' && options.showBoundaryAtoms) ||
          (record.atom.visibility === 'bonded' && options.showBondedOutside));
      this.mesh.setVisibleAt(batchId, visible);
    }
  }

  updateTheme(theme: ViewerTheme): void {
    const material = this.mesh.material;
    if (material instanceof MeshPhongMaterial) {
      material.shininess = theme.atom.shininess;
      material.specular.set(0x8f8f8f);
      material.side = FrontSide;
    } else if (material instanceof MeshPhysicalMaterial) {
      material.metalness = theme.atom.metalness;
      material.roughness = theme.atom.roughness;
      material.clearcoat = theme.atom.clearcoat;
      material.clearcoatRoughness = theme.atom.clearcoatRoughness;
      material.ior = theme.atom.ior;
      material.reflectivity = theme.atom.reflectivity;
      material.specularIntensity = theme.atom.specularIntensity;
      material.sheen = theme.atom.sheen;
      material.transmission = theme.atom.transmission;
      material.thickness = theme.atom.thickness;
      material.anisotropy = theme.atom.anisotropy;
      material.iridescence = theme.atom.iridescence;
      material.iridescenceIOR = theme.atom.iridescenceIOR;
      material.attenuationColor.set(theme.atom.attenuationColor);
      material.attenuationDistance = theme.atom.attenuationDistance;
      material.transparent = theme.atom.opacity < 1;
      material.opacity = theme.atom.opacity;
      material.envMap = this.materialsEnvironment ?? null;
      material.envMapIntensity =
        theme.id === 'gleamoe-premiror' ? 1.35 : theme.id === 'materials' ? 0.34 : 1;
      material.side = FrontSide;
    }
    material.needsUpdate = true;
  }

  setCinematicFocus(active: boolean): void {
    const material = this.mesh.material;
    if (!(material instanceof MeshPhysicalMaterial) || !this.artDirectedMaterials) return;
    material.envMapIntensity = active ? 0.38 : 1.35;
    material.needsUpdate = true;
  }

  dispose(): void {
    this.mesh.dispose();
    this.mesh.material.dispose();
  }

  private radiusFor(record: SegmentRecord): number {
    if (this.options.radiusMode === 'uniform' || !record.component) {
      return 0.5 * this.options.atomScale;
    }
    return Math.max(record.component.atomicRadius, 0.35) * this.options.atomScale;
  }

  private colorFor(record: SegmentRecord): Color {
    if (!record.component) return new Color(0.82, 0.82, 0.82);
    const atomColor = color(
      this.options.colorMode === 'vesta' ? record.component.colorVesta : record.component.colorJmol,
    );
    if (this.saturateColors) {
      const hsl = { h: 0, s: 0, l: 0 };
      atomColor.getHSL(hsl);
      if (hsl.s > 0.04) {
        atomColor.setHSL(hsl.h, Math.min(1, hsl.s * 1.35 + 0.04), hsl.l);
      }
    }
    return this.artDirectedMaterials
      ? encodeElementMaterialColor(atomColor, record.component)
      : atomColor;
  }
}
