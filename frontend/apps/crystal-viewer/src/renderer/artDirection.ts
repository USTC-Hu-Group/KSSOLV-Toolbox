import { Color, Vector2, Vector3, type MeshPhysicalMaterial } from 'three';

import type { AtomicSceneSpec, ColorMode, SpeciesComponent } from '../scene/types';
import { color } from './geometry';

export type ElementMaterialClass = 'ceramic' | 'metallic' | 'gem' | 'iridescent' | 'vacancy';

export interface ElementMaterialProfile {
  code: number;
  metalness: number;
  roughness: number;
  clearcoat: number;
  clearcoatRoughness: number;
  iridescence: number;
  transmission: number;
  thickness: number;
  anisotropy: number;
  sheen: number;
}

const profiles: Record<ElementMaterialClass, ElementMaterialProfile> = {
  ceramic: {
    code: 0,
    metalness: 0.04,
    roughness: 0.2,
    clearcoat: 0.95,
    clearcoatRoughness: 0.055,
    iridescence: 0.035,
    transmission: 0.015,
    thickness: 0.3,
    anisotropy: 0.04,
    sheen: 0.14,
  },
  metallic: {
    code: 1,
    metalness: 0.68,
    roughness: 0.16,
    clearcoat: 0.48,
    clearcoatRoughness: 0.09,
    iridescence: 0.025,
    transmission: 0,
    thickness: 0,
    anisotropy: 0.42,
    sheen: 0.03,
  },
  gem: {
    code: 2,
    metalness: 0,
    roughness: 0.075,
    clearcoat: 1,
    clearcoatRoughness: 0.025,
    iridescence: 0.16,
    transmission: 0.14,
    thickness: 0.58,
    anisotropy: 0.08,
    sheen: 0.2,
  },
  iridescent: {
    code: 3,
    metalness: 0.38,
    roughness: 0.12,
    clearcoat: 0.82,
    clearcoatRoughness: 0.04,
    iridescence: 0.48,
    transmission: 0.025,
    thickness: 0.4,
    anisotropy: 0.28,
    sheen: 0.12,
  },
  vacancy: {
    code: 4,
    metalness: 0,
    roughness: 0.32,
    clearcoat: 0.32,
    clearcoatRoughness: 0.18,
    iridescence: 0,
    transmission: 0.24,
    thickness: 0.2,
    anisotropy: 0,
    sheen: 0,
  },
};

const alkaliMetals = new Set([3, 11, 19, 37, 55, 87]);
const alkalineEarthMetals = new Set([4, 12, 20, 38, 56, 88]);
const postTransitionMetals = new Set([13, 31, 49, 50, 81, 82, 83, 113, 114, 115, 116]);
const metalloids = new Set([5, 14, 32, 33, 51, 52, 84]);
const halogens = new Set([9, 17, 35, 53, 85, 117]);
const nobleGases = new Set([2, 10, 18, 36, 54, 86, 118]);

export const elementMaterialClass = (atomicNumber?: number): ElementMaterialClass => {
  if (!atomicNumber || atomicNumber < 1) return 'vacancy';
  if ((atomicNumber >= 57 && atomicNumber <= 71) || (atomicNumber >= 89 && atomicNumber <= 103)) {
    return 'iridescent';
  }
  if (
    alkaliMetals.has(atomicNumber) ||
    alkalineEarthMetals.has(atomicNumber) ||
    postTransitionMetals.has(atomicNumber) ||
    (atomicNumber >= 21 && atomicNumber <= 30) ||
    (atomicNumber >= 39 && atomicNumber <= 48) ||
    (atomicNumber >= 72 && atomicNumber <= 80) ||
    (atomicNumber >= 104 && atomicNumber <= 112)
  ) {
    return 'metallic';
  }
  if (halogens.has(atomicNumber) || nobleGases.has(atomicNumber)) return 'gem';
  if (metalloids.has(atomicNumber)) return 'iridescent';
  return 'ceramic';
};

export const elementMaterialProfile = (
  component?: SpeciesComponent | null,
): ElementMaterialProfile => profiles[elementMaterialClass(component?.atomicNumber)];

/** Packs the material class into the red channel of the float batching texture. */
export const encodeElementMaterialColor = (
  baseColor: Color,
  component?: SpeciesComponent | null,
): Color => {
  const encoded = baseColor.clone();
  encoded.r += elementMaterialProfile(component).code * 2;
  return encoded;
};

/** Adds per-instance art-directed PBR parameters while retaining a single BatchedMesh draw call. */
export const installElementMaterialShader = (material: MeshPhysicalMaterial): void => {
  material.onBeforeCompile = (shader) => {
    shader.fragmentShader = shader.fragmentShader
      .replace(
        '#include <color_fragment>',
        `float gleamoeMaterialClass = 0.0;
        #ifdef USE_BATCHING_COLOR
          gleamoeMaterialClass = floor(vColor.r * 0.5 + 0.001);
          vColor.r -= gleamoeMaterialClass * 2.0;
        #endif
        float gleamoeMetal = 1.0 - step(0.25, abs(gleamoeMaterialClass - 1.0));
        float gleamoeGem = 1.0 - step(0.25, abs(gleamoeMaterialClass - 2.0));
        float gleamoeIridescent = 1.0 - step(0.25, abs(gleamoeMaterialClass - 3.0));
        float gleamoeVacancy = 1.0 - step(0.25, abs(gleamoeMaterialClass - 4.0));
        #include <color_fragment>`,
      )
      .replace(
        '#include <roughnessmap_fragment>',
        `#include <roughnessmap_fragment>
        roughnessFactor = mix(roughnessFactor, 0.16, gleamoeMetal);
        roughnessFactor = mix(roughnessFactor, 0.075, gleamoeGem);
        roughnessFactor = mix(roughnessFactor, 0.12, gleamoeIridescent);
        roughnessFactor = mix(roughnessFactor, 0.32, gleamoeVacancy);`,
      )
      .replace(
        '#include <metalnessmap_fragment>',
        `#include <metalnessmap_fragment>
        metalnessFactor = mix(metalnessFactor, 0.68, gleamoeMetal);
        metalnessFactor = mix(metalnessFactor, 0.0, gleamoeGem);
        metalnessFactor = mix(metalnessFactor, 0.38, gleamoeIridescent);
        metalnessFactor = mix(metalnessFactor, 0.0, gleamoeVacancy);`,
      )
      .replace(
        'material.clearcoat = clearcoat;',
        `material.clearcoat = clearcoat;
        material.clearcoat = mix(material.clearcoat, 0.48, gleamoeMetal);
        material.clearcoat = mix(material.clearcoat, 1.0, gleamoeGem);
        material.clearcoat = mix(material.clearcoat, 0.82, gleamoeIridescent);
        material.clearcoat = mix(material.clearcoat, 0.32, gleamoeVacancy);`,
      )
      .replace(
        'material.iridescence = iridescence;',
        `material.iridescence = iridescence;
        material.iridescence = mix(material.iridescence, 0.025, gleamoeMetal);
        material.iridescence = mix(material.iridescence, 0.16, gleamoeGem);
        material.iridescence = mix(material.iridescence, 0.48, gleamoeIridescent);
        material.iridescence = mix(material.iridescence, 0.0, gleamoeVacancy);`,
      );
  };
  material.customProgramCacheKey = () => 'gleamoe-element-materials-v1';
  material.needsUpdate = true;
};

export interface CinematicPalette {
  dominant: Color;
  key: Color;
  fill: Color;
  rim: Color;
}

export const cinematicPalette = (
  scene: AtomicSceneSpec,
  colorMode: ColorMode,
): CinematicPalette => {
  const dominant = new Color(0, 0, 0);
  let totalWeight = 0;
  for (const site of scene.sites) {
    for (const component of site.species) {
      const tint = color(colorMode === 'vesta' ? component.colorVesta : component.colorJmol);
      const weight = Math.max(component.occupancy, 0);
      dominant.r += tint.r * weight;
      dominant.g += tint.g * weight;
      dominant.b += tint.b * weight;
      totalWeight += weight;
    }
  }
  if (totalWeight > 0) dominant.multiplyScalar(1 / totalWeight);
  else dominant.set(0x66d9ff);

  const hsl = { h: 0, s: 0, l: 0 };
  dominant.getHSL(hsl);
  const key = dominant.clone().lerp(new Color(0xf5fbff), 0.78);
  const fill = new Color().setHSL((hsl.h + 0.5) % 1, Math.max(0.34, hsl.s * 0.48), 0.66);
  const rim = new Color().setHSL((hsl.h + 0.82) % 1, Math.max(0.54, hsl.s * 0.72), 0.62);
  return { dominant, key, fill, rim };
};

const heroDirections = [
  [1.18, 1, 0.86],
  [-1.18, 1, 0.86],
  [1.18, -1, 0.86],
  [-1.18, -1, 0.86],
  [0.9, 1.2, 1.16],
  [-0.9, 1.2, 1.16],
  [1.25, 0.72, 1.08],
  [-1.25, 0.72, 1.08],
] as const;

/** Chooses the isometric view with the least projected atom overlap. */
export const bestHeroDirection = (scene: AtomicSceneSpec): Vector3 => {
  const points = [
    ...new Map(
      scene.atomInstances.map((atom) => [
        atom.position.map((value) => value.toFixed(5)).join(':'),
        new Vector3(...atom.position),
      ]),
    ).values(),
  ];
  if (points.length < 2) return new Vector3(...heroDirections[0]).normalize();

  let bestDirection = new Vector3(...heroDirections[0]).normalize();
  let bestScore = -Infinity;
  for (const candidate of heroDirections) {
    const direction = new Vector3(...candidate).normalize();
    const worldUp = Math.abs(direction.z) > 0.96 ? new Vector3(0, 1, 0) : new Vector3(0, 0, 1);
    const right = new Vector3().crossVectors(direction, worldUp).normalize();
    const up = new Vector3().crossVectors(right, direction).normalize();
    const projected = points.map((point) => new Vector2(point.dot(right), point.dot(up)));
    const min = new Vector2(Infinity, Infinity);
    const max = new Vector2(-Infinity, -Infinity);
    projected.forEach((point) => {
      min.min(point);
      max.max(point);
    });
    const diagonal = Math.max(max.distanceTo(min), 1e-6);
    let separation = 0;
    for (let first = 0; first < projected.length; first += 1) {
      let nearest = Infinity;
      for (let second = 0; second < projected.length; second += 1) {
        if (first === second) continue;
        nearest = Math.min(nearest, projected[first].distanceTo(projected[second]));
      }
      separation += Math.min(nearest / diagonal, 0.25);
    }
    const score = separation / projected.length;
    if (score > bestScore) {
      bestScore = score;
      bestDirection = direction;
    }
  }
  return bestDirection;
};
