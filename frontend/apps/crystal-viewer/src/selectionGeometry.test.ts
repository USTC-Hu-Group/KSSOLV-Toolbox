import { describe, expect, it } from 'vitest';

import { atomIdsInPolygon, pointInPolygon, rectanglePolygon } from './selectionGeometry';

describe('screen selection geometry', () => {
  it('normalizes rectangles dragged in either direction', () => {
    expect(rectanglePolygon({ x: 8, y: 7 }, { x: 2, y: 3 })).toEqual([
      { x: 2, y: 3 },
      { x: 8, y: 3 },
      { x: 8, y: 7 },
      { x: 2, y: 7 },
    ]);
  });

  it('selects points inside concave lasso polygons', () => {
    const polygon = [
      { x: 0, y: 0 },
      { x: 8, y: 0 },
      { x: 4, y: 4 },
      { x: 8, y: 8 },
      { x: 0, y: 8 },
    ];
    expect(pointInPolygon({ x: 2, y: 4 }, polygon)).toBe(true);
    expect(pointInPolygon({ x: 7, y: 4 }, polygon)).toBe(false);
  });

  it('filters ten thousand projected atoms within the interaction budget', () => {
    const atoms = Array.from({ length: 10_000 }, (_, index) => ({
      id: `atom-${index}`,
      x: index % 100,
      y: Math.floor(index / 100),
    }));
    const polygon = rectanglePolygon({ x: 25, y: 25 }, { x: 75, y: 75 });
    const started = performance.now();
    const selected = atomIdsInPolygon(atoms, polygon);
    expect(performance.now() - started).toBeLessThan(500);
    expect(selected).toHaveLength(2_500);
  });
});
