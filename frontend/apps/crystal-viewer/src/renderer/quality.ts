import type { RenderMode, RenderQualityLevel } from '../scene/types';

export interface RenderQualityProfile {
  atomSegments: readonly [number, number];
  largeAtomSegments: readonly [number, number];
  pixelRatioScale: number;
  pixelRatioCap: number;
  exportScale: number;
  pathTracingSamples: number;
  pathTracingBounces: number;
  textureSize: number;
}

export type HeroExportScale = 2.5 | 3 | 4;

const fastProfile: RenderQualityProfile = {
  atomSegments: [48, 32],
  largeAtomSegments: [20, 14],
  pixelRatioScale: 1,
  pixelRatioCap: 2,
  exportScale: 1,
  pathTracingSamples: 0,
  pathTracingBounces: 0,
  textureSize: 1024,
};

const qualityProfiles: Record<RenderQualityLevel, RenderQualityProfile> = {
  balanced: {
    atomSegments: [56, 36],
    largeAtomSegments: [26, 18],
    pixelRatioScale: 1.25,
    pixelRatioCap: 2.5,
    exportScale: 1.25,
    pathTracingSamples: 24,
    pathTracingBounces: 5,
    textureSize: 1024,
  },
  high: {
    atomSegments: [72, 48],
    largeAtomSegments: [32, 22],
    pixelRatioScale: 1.5,
    pixelRatioCap: 3,
    exportScale: 1.5,
    pathTracingSamples: 48,
    pathTracingBounces: 7,
    textureSize: 2048,
  },
  ultra: {
    atomSegments: [96, 64],
    largeAtomSegments: [40, 28],
    pixelRatioScale: 1.75,
    pixelRatioCap: 3.5,
    exportScale: 2,
    pathTracingSamples: 96,
    pathTracingBounces: 9,
    textureSize: 2048,
  },
};

export const renderQualityProfile = (
  mode: RenderMode,
  quality: RenderQualityLevel,
): RenderQualityProfile => (mode === 'quality' ? qualityProfiles[quality] : fastProfile);

export const interactivePixelRatio = (
  devicePixelRatio: number,
  mode: RenderMode,
  quality: RenderQualityLevel,
): number => {
  const profile = renderQualityProfile(mode, quality);
  return Math.min(devicePixelRatio * profile.pixelRatioScale, profile.pixelRatioCap);
};

export const exportPixelRatio = (
  devicePixelRatio: number,
  mode: RenderMode,
  quality: RenderQualityLevel,
): number => {
  const fastPixelRatio = interactivePixelRatio(devicePixelRatio, 'fast', quality);
  const profile = renderQualityProfile(mode, quality);
  return Math.min(fastPixelRatio * profile.exportScale, 4);
};

/** Gleamoe uses a higher fixed supersample for final raster output than for interaction. */
export const gleamoeExportPixelRatio = (
  devicePixelRatio: number,
  heroShot: boolean,
  heroExportScale: HeroExportScale = 2.5,
): number => (heroShot ? heroExportScale : Math.min(Math.max(devicePixelRatio, 1.75), 2.25));
