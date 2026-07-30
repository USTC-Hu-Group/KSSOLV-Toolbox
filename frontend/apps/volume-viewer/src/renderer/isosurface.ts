const cubeCorners = [
  [0, 0, 0],
  [1, 0, 0],
  [1, 1, 0],
  [0, 1, 0],
  [0, 0, 1],
  [1, 0, 1],
  [1, 1, 1],
  [0, 1, 1],
] as const;

const tetrahedra = [
  [0, 5, 1, 6],
  [0, 1, 2, 6],
  [0, 2, 3, 6],
  [0, 3, 7, 6],
  [0, 7, 4, 6],
  [0, 4, 5, 6],
] as const;

const tetrahedronEdges = [
  [0, 1],
  [0, 2],
  [0, 3],
  [1, 2],
  [1, 3],
  [2, 3],
] as const;

type Point = [number, number, number];

const subtract = (a: Point, b: Point): Point => [
  a[0] - b[0],
  a[1] - b[1],
  a[2] - b[2],
];
const dot = (a: Point, b: Point): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a: Point, b: Point): Point => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const normalize = (value: Point): Point => {
  const length = Math.hypot(...value) || 1;
  return [value[0] / length, value[1] / length, value[2] / length];
};
const average = (points: Point[]): Point => {
  const result: Point = [0, 0, 0];
  for (const point of points) {
    result[0] += point[0];
    result[1] += point[1];
    result[2] += point[2];
  }
  return result.map((value) => value / points.length) as Point;
};

const triangulatePolygon = (points: Point[], towardHigh: Point): Point[][] => {
  points = points.filter(
    (point, index) =>
      points.findIndex(
        (candidate) =>
          Math.abs(candidate[0] - point[0]) < 1e-7 &&
          Math.abs(candidate[1] - point[1]) < 1e-7 &&
          Math.abs(candidate[2] - point[2]) < 1e-7,
      ) === index,
  );
  if (points.length < 3) return [];
  const center = average(points);
  const normal = normalize(towardHigh);
  const reference: Point =
    Math.abs(normal[0]) < 0.8 ? [1, 0, 0] : Math.abs(normal[1]) < 0.8 ? [0, 1, 0] : [0, 0, 1];
  const tangent = normalize(cross(normal, reference));
  const bitangent = cross(normal, tangent);
  points.sort((first, second) => {
    const a = subtract(first, center);
    const b = subtract(second, center);
    return (
      Math.atan2(dot(a, bitangent), dot(a, tangent)) -
      Math.atan2(dot(b, bitangent), dot(b, tangent))
    );
  });
  const triangles: Point[][] = [];
  for (let index = 1; index < points.length - 1; index += 1) {
    const triangle = [points[0], points[index], points[index + 1]];
    const faceNormal = cross(
      subtract(triangle[1], triangle[0]),
      subtract(triangle[2], triangle[0]),
    );
    if (Math.hypot(...faceNormal) < 1e-10) continue;
    if (dot(faceNormal, towardHigh) < 0) {
      [triangle[1], triangle[2]] = [triangle[2], triangle[1]];
    }
    triangles.push(triangle);
  }
  return triangles;
};

export interface IsosurfaceResult {
  positions: Float32Array;
  truncated: boolean;
}

export const wrapPeriodicGrid = (
  values: Float32Array,
  dimensions: readonly [number, number, number],
  periodic: readonly [boolean, boolean, boolean],
): { values: Float32Array; dimensions: [number, number, number] } => {
  if (!periodic.some(Boolean)) {
    return { values, dimensions: [...dimensions] };
  }
  const outputDimensions: [number, number, number] = dimensions.map(
    (value, axis) => value + (periodic[axis] ? 1 : 0),
  ) as [number, number, number];
  const output = new Float32Array(
    outputDimensions[0] * outputDimensions[1] * outputDimensions[2],
  );
  const inputIndex = (x: number, y: number, z: number) =>
    (x % dimensions[0]) +
    dimensions[0] * ((y % dimensions[1]) + dimensions[1] * (z % dimensions[2]));
  let offset = 0;
  for (let z = 0; z < outputDimensions[2]; z += 1)
    for (let y = 0; y < outputDimensions[1]; y += 1)
      for (let x = 0; x < outputDimensions[0]; x += 1) {
        output[offset] = values[inputIndex(x, y, z)];
        offset += 1;
      }
  return { values: output, dimensions: outputDimensions };
};

export const marchingTetrahedra = (
  values: Float32Array,
  dimensions: readonly number[],
  threshold: number,
  maxTriangles = 4_000_000,
): IsosurfaceResult => {
  const [nx, ny, nz] = dimensions;
  const positions: number[] = [];
  const index = (x: number, y: number, z: number) => x + nx * (y + ny * z);
  let truncated = false;

  outer: for (let z = 0; z < nz - 1; z += 1) {
    for (let y = 0; y < ny - 1; y += 1) {
      for (let x = 0; x < nx - 1; x += 1) {
        const cubeValues = cubeCorners.map(
          ([dx, dy, dz]) => values[index(x + dx, y + dy, z + dz)],
        );
        if (
          cubeValues.every((value) => value < threshold) ||
          cubeValues.every((value) => value >= threshold)
        ) {
          continue;
        }
        const cubeGradient: Point = [
          (cubeValues[1] + cubeValues[2] + cubeValues[5] + cubeValues[6] -
            cubeValues[0] -
            cubeValues[3] -
            cubeValues[4] -
            cubeValues[7]) /
            4,
          (cubeValues[2] + cubeValues[3] + cubeValues[6] + cubeValues[7] -
            cubeValues[0] -
            cubeValues[1] -
            cubeValues[4] -
            cubeValues[5]) /
            4,
          (cubeValues[4] + cubeValues[5] + cubeValues[6] + cubeValues[7] -
            cubeValues[0] -
            cubeValues[1] -
            cubeValues[2] -
            cubeValues[3]) /
            4,
        ];
        for (const tetrahedron of tetrahedra) {
          const points: Point[] = [];
          const high: Point[] = [];
          const low: Point[] = [];
          for (const corner of tetrahedron) {
            const point = cubeCorners[corner] as Point;
            (cubeValues[corner] >= threshold ? high : low).push(point);
          }
          for (const [first, second] of tetrahedronEdges) {
            const firstCorner = tetrahedron[first];
            const secondCorner = tetrahedron[second];
            const firstValue = cubeValues[firstCorner];
            const secondValue = cubeValues[secondCorner];
            if ((firstValue >= threshold) === (secondValue >= threshold)) continue;
            const fraction = Math.min(
              1,
              Math.max(0, (threshold - firstValue) / (secondValue - firstValue)),
            );
            const a = cubeCorners[firstCorner];
            const b = cubeCorners[secondCorner];
            points.push([
              x + a[0] + (b[0] - a[0]) * fraction,
              y + a[1] + (b[1] - a[1]) * fraction,
              z + a[2] + (b[2] - a[2]) * fraction,
            ]);
          }
          const highCenter = average(high);
          const lowCenter = average(low);
          const towardHigh =
            Math.hypot(...cubeGradient) > 1e-12
              ? cubeGradient
              : subtract(highCenter, lowCenter);
          const triangles = triangulatePolygon(points, towardHigh);
          for (const triangle of triangles) {
            for (const vertex of triangle) positions.push(...vertex);
            if (positions.length / 9 >= maxTriangles) {
              truncated = true;
              break outer;
            }
          }
        }
      }
    }
  }
  return { positions: new Float32Array(positions), truncated };
};
