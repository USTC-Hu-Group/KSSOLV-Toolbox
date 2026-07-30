import { describe, expect, it } from 'vitest';
import {
  BufferGeometry,
  Float32BufferAttribute,
  Matrix4,
  Uint16BufferAttribute,
} from 'three';

import { geometryTriangles } from './geometryTriangles';

describe('scientific geometry expansion', () => {
  it('preserves every indexed face and applies the world transform', () => {
    const geometry = new BufferGeometry();
    geometry.setAttribute(
      'position',
      new Float32BufferAttribute(
        [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0],
        3,
      ),
    );
    geometry.setIndex(new Uint16BufferAttribute([0, 1, 2, 0, 2, 3], 1));
    const result = geometryTriangles(
      geometry,
      new Matrix4().makeTranslation(10, -3, 2),
    );
    expect([...result]).toEqual([
      10, -3, 2, 11, -3, 2, 11, -2, 2,
      10, -3, 2, 11, -2, 2, 10, -2, 2,
    ]);
    expect(result.length / 9).toBe(2);
  });

  it('rejects incomplete triangle data', () => {
    const geometry = new BufferGeometry();
    geometry.setAttribute(
      'position',
      new Float32BufferAttribute([0, 0, 0, 1, 0, 0], 3),
    );
    expect(() => geometryTriangles(geometry)).toThrow(/complete triangles/);
  });
});
