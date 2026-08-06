import { Color } from 'three';
import { describe, expect, it } from 'vitest';

import { createDebugScene } from '../scene/debugScene';
import type { SpeciesComponent } from '../scene/types';
import {
  cinematicPalette,
  bestHeroDirection,
  elementMaterialClass,
  elementMaterialProfile,
  encodeElementMaterialColor,
} from './artDirection';

describe('Gleamoe art direction', () => {
  it('assigns distinct material languages to element families', () => {
    expect(elementMaterialClass(26)).toBe('metallic');
    expect(elementMaterialClass(17)).toBe('gem');
    expect(elementMaterialClass(8)).toBe('ceramic');
    expect(elementMaterialClass(14)).toBe('iridescent');
    expect(elementMaterialClass(60)).toBe('iridescent');
    expect(elementMaterialClass()).toBe('vacancy');
    expect(
      elementMaterialProfile({ atomicNumber: 26 } as unknown as SpeciesComponent).metalness,
    ).toBeGreaterThan(0.6);
  });

  it('encodes a material class without discarding the base color', () => {
    const base = new Color(0.25, 0.5, 0.75);
    const encoded = encodeElementMaterialColor(base, { atomicNumber: 17 } as never);
    expect(encoded.r).toBeCloseTo(4.25);
    expect(encoded.g).toBeCloseTo(base.g);
    expect(encoded.b).toBeCloseTo(base.b);
  });

  it('derives complementary cinematic lights from the structure palette', () => {
    const palette = cinematicPalette(createDebugScene(), 'vesta');
    const colorDistance = (first: Color, second: Color): number =>
      Math.hypot(first.r - second.r, first.g - second.g, first.b - second.b);
    expect(palette.dominant.getHex()).not.toBe(0);
    expect(
      Math.max(palette.dominant.r, palette.dominant.g, palette.dominant.b),
    ).toBeLessThanOrEqual(1);
    expect(colorDistance(palette.key, palette.fill)).toBeGreaterThan(0.05);
    expect(colorDistance(palette.fill, palette.rim)).toBeGreaterThan(0.05);
  });

  it('chooses a normalized non-axial hero view from the structure silhouette', () => {
    const direction = bestHeroDirection(createDebugScene());
    expect(direction.length()).toBeCloseTo(1);
    expect(
      Math.min(Math.abs(direction.x), Math.abs(direction.y), Math.abs(direction.z)),
    ).toBeGreaterThan(0.2);
  });
});
