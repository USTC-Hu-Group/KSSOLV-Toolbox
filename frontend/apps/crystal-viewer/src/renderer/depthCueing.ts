export interface DepthCueRange {
  near: number;
  far: number;
}

/**
 * Derive stable linear-fog planes from the structure's camera-space bounding sphere.
 * The front of the sphere remains clear while its back blends strongly into
 * the background, making the depth difference readable at a glance.
 */
export const depthCueRange = (centerDepth: number, radius: number): DepthCueRange => {
  const safeRadius = Math.max(Number.isFinite(radius) ? radius : 0, 0.5);
  const safeCenterDepth = Math.max(Number.isFinite(centerDepth) ? centerDepth : 0, safeRadius);
  const near = Math.max(safeCenterDepth - safeRadius, 0);
  return {
    near,
    far: Math.max(safeCenterDepth + safeRadius * 1.5, near + safeRadius),
  };
};
