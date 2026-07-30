import type { RenderMode, RenderQualityLevel } from '../scene/types';

export interface RenderQualityProfile {
  atomSegments: readonly [number, number];
  largeAtomSegments: readonly [number, number];
  pixelRatioScale: number;
  pixelRatioCap: number;
  exportScale: number;
}

const fastProfile: RenderQualityProfile = {
  atomSegments: [48, 32],
  largeAtomSegments: [20, 14],
  pixelRatioScale: 1,
  pixelRatioCap: 2,
  exportScale: 1,
};

const qualityProfiles: Record<RenderQualityLevel, RenderQualityProfile> = {
  balanced: {
    atomSegments: [56, 36],
    largeAtomSegments: [26, 18],
    pixelRatioScale: 1.25,
    pixelRatioCap: 2.5,
    exportScale: 1.25,
  },
  high: {
    atomSegments: [72, 48],
    largeAtomSegments: [32, 22],
    pixelRatioScale: 1.5,
    pixelRatioCap: 3,
    exportScale: 1.5,
  },
  ultra: {
    atomSegments: [96, 64],
    largeAtomSegments: [40, 28],
    pixelRatioScale: 1.75,
    pixelRatioCap: 3.5,
    exportScale: 2,
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
