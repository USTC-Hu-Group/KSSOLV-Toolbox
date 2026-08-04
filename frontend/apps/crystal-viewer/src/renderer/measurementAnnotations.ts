import { Vector3 } from 'three';

import type { Vector3Tuple } from '../scene/types';

export type MeasurementAnnotationKind =
  | 'distance'
  | 'angle'
  | 'dihedral'
  | 'atom_info'
  | 'cell'
  | 'bond_stats'
  | 'atom_plane'
  | 'plane_plane'
  | 'coordination'
  | 'nearest_neighbors';

export type MeasurementSegment = [number, number, number, number, number, number];

export interface MeasurementAnnotation {
  id: string;
  kind: MeasurementAnnotationKind;
  label: string;
  points: Vector3Tuple[];
  segments: MeasurementSegment[];
  planePoints: Vector3Tuple[];
  projection?: Vector3Tuple;
  candidatePlaneIndices?: number[];
}

const kinds = new Set<MeasurementAnnotationKind>([
  'distance',
  'angle',
  'dihedral',
  'atom_info',
  'cell',
  'bond_stats',
  'atom_plane',
  'plane_plane',
  'coordination',
  'nearest_neighbors',
]);

const finiteRow = <T extends number[]>(value: unknown, length: number): T | undefined => {
  if (!Array.isArray(value) || value.length !== length) return undefined;
  const numbers = value.map(Number);
  return numbers.every(Number.isFinite) ? (numbers as T) : undefined;
};

const rows = <T extends number[]>(value: unknown, length: number): T[] => {
  if (!Array.isArray(value) || value.length === 0) return [];
  const single = finiteRow<T>(value, length);
  if (single) return [single];
  return value.map((entry) => finiteRow<T>(entry, length)).filter((entry): entry is T => !!entry);
};

export const parseMeasurementAnnotations = (payload: unknown): MeasurementAnnotation[] => {
  let value = payload;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value) as unknown;
    } catch {
      return [];
    }
  }
  if (typeof value !== 'object' || value === null) return [];
  const annotations = (value as { annotations?: unknown }).annotations;
  if (!Array.isArray(annotations)) return [];
  return annotations.flatMap((entry) => {
    if (typeof entry !== 'object' || entry === null) return [];
    const source = entry as Record<string, unknown>;
    if (
      typeof source.id !== 'string' ||
      typeof source.kind !== 'string' ||
      !kinds.has(source.kind as MeasurementAnnotationKind)
    ) {
      return [];
    }
    return [
      {
        id: source.id,
        kind: source.kind as MeasurementAnnotationKind,
        label: typeof source.label === 'string' ? source.label : '',
        points: rows<Vector3Tuple>(source.points, 3),
        segments: rows<MeasurementSegment>(source.segments, 6),
        planePoints: rows<Vector3Tuple>(source.planePoints, 3),
        projection: finiteRow<Vector3Tuple>(source.projection, 3),
        candidatePlaneIndices: Array.isArray(source.candidatePlaneIndices)
          ? source.candidatePlaneIndices.map(Number).filter(Number.isInteger)
          : undefined,
      },
    ];
  });
};

export const angleArcPoints = (annotation: MeasurementAnnotation, samples = 32): Vector3Tuple[] => {
  if (annotation.kind !== 'angle' || annotation.points.length < 3) return [];
  const start = new Vector3(...annotation.points[0]);
  const center = new Vector3(...annotation.points[1]);
  const finish = new Vector3(...annotation.points[2]);
  const first = start.sub(center);
  const second = finish.sub(center);
  if (first.lengthSq() < 1e-16 || second.lengthSq() < 1e-16) return [];
  const firstDirection = first.clone().normalize();
  const normal = first.clone().cross(second).normalize();
  if (normal.lengthSq() < 1e-16) return [];
  const perpendicular = normal.clone().cross(firstDirection).normalize();
  const angle = Math.acos(Math.max(-1, Math.min(1, firstDirection.dot(second.normalize()))));
  const radius = Math.min(first.length(), second.length()) * 0.32;
  return Array.from({ length: Math.max(samples, 2) }, (_, index) => {
    const progress = index / (Math.max(samples, 2) - 1);
    return center
      .clone()
      .addScaledVector(firstDirection, Math.cos(angle * progress) * radius)
      .addScaledVector(perpendicular, Math.sin(angle * progress) * radius)
      .toArray() as Vector3Tuple;
  });
};
