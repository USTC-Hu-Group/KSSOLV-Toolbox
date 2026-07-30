import { describe, expect, it } from 'vitest';
import { Vector3 } from 'three';

import {
  cylinderMatrix,
  fittedViewHeight,
  orthographicFitHeight,
  projectedFitHeight,
} from './geometry';

describe('renderer geometry helpers', () => {
  it('maps a unit cylinder onto an arbitrary bond segment', () => {
    const matrix = cylinderMatrix([1, 2, 3], [1, 2, 7], 0.1);
    const midpoint = new Vector3().setFromMatrixPosition(matrix);
    const scale = new Vector3().setFromMatrixScale(matrix);
    expect(midpoint.toArray()).toEqual([1, 2, 5]);
    expect(scale.x).toBeCloseTo(0.1);
    expect(scale.y).toBeCloseTo(4);
    expect(scale.z).toBeCloseTo(0.1);
  });

  it('fits a bounding sphere in wide and narrow orthographic viewports', () => {
    expect(orthographicFitHeight(5, 2)).toBe(12.5);
    expect(orthographicFitHeight(5, 0.5)).toBe(25);
  });

  it('fits Materials scenes more tightly while preserving the Pretty camera profile', () => {
    expect(fittedViewHeight(5, 2, 8, 'pretty')).toBe(12.5);
    expect(fittedViewHeight(5, 2, 8, 'materials')).toBeCloseTo(10.6);
    expect(fittedViewHeight(0.4, 2, 0.6, 'materials')).toBe(2.2);
  });

  it('includes atom radii when tightly fitting the current camera projection', () => {
    const height = projectedFitHeight(
      [
        { center: new Vector3(-2, 0, 0), radius: 0.5 },
        { center: new Vector3(2, 0, 0), radius: 0.5 },
      ],
      new Vector3(),
      new Vector3(0, 0, 1),
      new Vector3(0, 1, 0),
      2,
      1,
      0,
    );
    expect(height).toBeCloseTo(2.5);
  });
});
