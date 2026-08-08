/** Maps the normalized UI midpoint (50%) to the theme-authored value. */
export const appearanceScale = (value: number): number => Math.min(Math.max(value, 0), 1) * 2;

/** Keeps the authored value at 50%, removes it at 0%, and reaches full metal at 100%. */
export const scaledMetalness = (base: number, value: number): number => {
  const safeBase = Math.min(Math.max(base, 0), 1);
  const safeScale = appearanceScale(value);
  return safeScale <= 1 ? safeBase * safeScale : safeBase + (1 - safeBase) * (safeScale - 1);
};

/** Roughness is a direct multiplier because zero roughness is already a meaningful endpoint. */
export const scaledRoughness = (base: number, value: number): number =>
  Math.min(Math.max(base * appearanceScale(value), 0), 1);
