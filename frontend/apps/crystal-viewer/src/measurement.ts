import { Vector3 } from 'three';

import type {
  AtomInstanceSpec,
  AtomicSceneSpec,
  BondRelationSpec,
  ImageOffset,
  SiteSpec,
  Vector3Tuple,
} from './scene/types';
import type {
  MeasurementAnnotation,
  MeasurementAnnotationKind,
  MeasurementSegment,
} from './renderer/measurementAnnotations';

export type MeasurementKind = MeasurementAnnotationKind;

export interface CellMeasurementValues {
  lengths: Vector3Tuple;
  angles: Vector3Tuple;
  volume: number;
}

export interface BondStatisticsValues {
  pairLabel: string;
  count: number;
  average?: number;
  minimum?: number;
  maximum?: number;
  algorithm: string;
}

export type MeasurementDiagramPoint = [number, number];

export interface MeasurementDiagram {
  points: MeasurementDiagramPoint[];
  projection?: MeasurementDiagramPoint;
}

export interface MeasurementRecord {
  id: string;
  kind: MeasurementKind;
  title: string;
  summary: string;
  details: string;
  annotation: MeasurementAnnotation;
  cellValues?: CellMeasurementValues;
  bondStatistics?: BondStatisticsValues;
  neighbors?: NeighborMeasurement[];
  siteLabels?: string[];
  diagram?: MeasurementDiagram;
  siteIndices?: number[];
  numericValue?: number;
}

export interface NeighborMeasurement {
  siteIndex: number;
  label: string;
  image: ImageOffset;
  distance: number;
  cartesian: Vector3Tuple;
}

export const measurementKinds: MeasurementKind[] = [
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
];

export const expectedSelectionCount = (kind: MeasurementKind): number => {
  if (kind === 'cell') return 0;
  if (kind === 'atom_info' || kind === 'coordination' || kind === 'nearest_neighbors') return 1;
  if (kind === 'distance' || kind === 'bond_stats') return 2;
  if (kind === 'angle') return 3;
  if (kind === 'dihedral' || kind === 'atom_plane') return 4;
  return 6;
};

export const canMeasure = (
  scene: AtomicSceneSpec | undefined,
  kind: MeasurementKind,
  selectionCount: number,
): boolean => {
  if (!scene) return false;
  if (kind === 'cell') return scene.kind === 'crystal';
  return selectionCount === expectedSelectionCount(kind);
};

const siteMap = (scene: AtomicSceneSpec): Map<number, SiteSpec> =>
  new Map(scene.sites.map((site) => [site.siteIndex, site]));

const vector = (value: Vector3Tuple): Vector3 => new Vector3(...value);

const tuple = (value: Vector3): Vector3Tuple => value.toArray() as Vector3Tuple;

const fractionalToCartesian = (scene: AtomicSceneSpec, fractional: Vector3Tuple): Vector3Tuple => {
  if (scene.kind !== 'crystal') throw new Error('Fractional coordinates require a crystal.');
  const [a, b, c] = scene.structure.lattice.map(vector);
  return tuple(
    new Vector3()
      .addScaledVector(a, fractional[0])
      .addScaledVector(b, fractional[1])
      .addScaledVector(c, fractional[2]),
  );
};

const sitePosition = (
  scene: AtomicSceneSpec,
  site: SiteSpec,
  image: ImageOffset = [0, 0, 0],
): Vector3Tuple => {
  if (scene.kind !== 'crystal' || !site.fractional) return site.cartesian;
  return fractionalToCartesian(scene, [
    site.fractional[0] + image[0],
    site.fractional[1] + image[1],
    site.fractional[2] + image[2],
  ]);
};

const imageCandidates = (periodic: [boolean, boolean, boolean]): ImageOffset[] => {
  const axes = periodic.map((enabled) => (enabled ? [-2, -1, 0, 1, 2] : [0]));
  const images: ImageOffset[] = [];
  for (const x of axes[0]) {
    for (const y of axes[1]) {
      for (const z of axes[2]) images.push([x, y, z]);
    }
  }
  return images;
};

const measurementCoordinates = (
  scene: AtomicSceneSpec,
  indices: number[],
  selectedAtoms?: AtomInstanceSpec[],
): Vector3Tuple[] => {
  if (selectedAtoms?.length === indices.length) {
    return selectedAtoms.map((atom) => [...atom.position]);
  }
  const sites = siteMap(scene);
  const selected = indices.map((index) => {
    const site = sites.get(index);
    if (!site) throw new Error(`Site ${index + 1} is unavailable.`);
    return site;
  });
  if (scene.kind !== 'crystal') return selected.map((site) => site.cartesian);
  const first = selected[0]?.fractional;
  if (!first) return selected.map((site) => site.cartesian);
  const unwrapped: Vector3Tuple[] = [[...first]];
  const candidates = imageCandidates(scene.structure.periodic);
  for (let index = 1; index < selected.length; index += 1) {
    const fractional = selected[index].fractional;
    if (!fractional) throw new Error('Crystal sites require fractional coordinates.');
    const previous = unwrapped[index - 1];
    let closest: Vector3Tuple | undefined;
    let closestDistance = Number.POSITIVE_INFINITY;
    for (const image of candidates) {
      const candidate: Vector3Tuple = [
        fractional[0] + image[0],
        fractional[1] + image[1],
        fractional[2] + image[2],
      ];
      const difference: Vector3Tuple = [
        candidate[0] - previous[0],
        candidate[1] - previous[1],
        candidate[2] - previous[2],
      ];
      const distance = vector(fractionalToCartesian(scene, difference)).lengthSq();
      if (distance < closestDistance) {
        closest = candidate;
        closestDistance = distance;
      }
    }
    if (!closest) throw new Error('Unable to resolve the closest periodic image.');
    unwrapped.push(closest);
  }
  return unwrapped.map((fractional) => fractionalToCartesian(scene, fractional));
};

const speciesKey = (site: SiteSpec): string =>
  site.species
    .map((component) =>
      component.occupancy === 1 ? component.symbol : `${component.symbol}:${component.occupancy}`,
    )
    .sort()
    .join(', ');

const measurementSiteLabels = (scene: AtomicSceneSpec, indices: number[]): string[] => {
  const sites = siteMap(scene);
  return indices.map((index) => `#${index + 1} ${sites.get(index)?.label ?? 'Atom'}`);
};

const sitesLabel = (scene: AtomicSceneSpec, indices: number[]): string =>
  measurementSiteLabels(scene, indices).join(' – ');

const baseAnnotation = (
  id: string,
  kind: MeasurementKind,
  label: string,
  points: Vector3Tuple[],
  segments: MeasurementSegment[] = [],
  planePoints: Vector3Tuple[] = [],
  projection?: Vector3Tuple,
): MeasurementAnnotation => ({
  id,
  kind,
  label,
  points,
  segments,
  planePoints,
  projection,
});

const intrinsicMeasurementDiagram = (annotation: MeasurementAnnotation): MeasurementDiagram => {
  const coordinates = annotation.points;
  const spreads = [0, 1, 2].map((axis) => {
    const values = coordinates.map((point) => point[axis]);
    return values.length ? Math.max(...values) - Math.min(...values) : 0;
  });
  const [horizontal, vertical] = (
    [
      [0, 1],
      [0, 2],
      [1, 2],
    ] as Array<[number, number]>
  ).sort(
    ([firstHorizontal, firstVertical], [secondHorizontal, secondVertical]) =>
      spreads[secondHorizontal] * spreads[secondVertical] -
      spreads[firstHorizontal] * spreads[firstVertical],
  )[0];
  const project = (point: Vector3Tuple): MeasurementDiagramPoint => [
    point[horizontal],
    -point[vertical],
  ];
  return {
    points: coordinates.map(project),
    projection: annotation.projection ? project(annotation.projection) : undefined,
  };
};

const geometricRecord = (
  scene: AtomicSceneSpec,
  indices: number[],
  record: MeasurementRecord,
): MeasurementRecord => ({
  ...record,
  siteIndices: [...indices],
  siteLabels: measurementSiteLabels(scene, indices),
  diagram: intrinsicMeasurementDiagram(record.annotation),
});

const segment = (start: Vector3Tuple, finish: Vector3Tuple): MeasurementSegment => [
  ...start,
  ...finish,
];

const relationSegment = (
  scene: AtomicSceneSpec,
  relation: BondRelationSpec,
  sites: Map<number, SiteSpec>,
): MeasurementSegment => {
  const start = sites.get(relation.fromSiteIndex);
  const finish = sites.get(relation.toSiteIndex);
  if (!start || !finish) throw new Error('A bond references an unavailable site.');
  return segment(sitePosition(scene, start), sitePosition(scene, finish, relation.relativeImage));
};

const validateSelection = (
  scene: AtomicSceneSpec,
  kind: MeasurementKind,
  selectedSiteIndices: number[],
  selectedAtoms?: AtomInstanceSpec[],
): number[] => {
  const indices = selectedAtoms ? [...selectedSiteIndices] : [...new Set(selectedSiteIndices)];
  const expected = expectedSelectionCount(kind);
  if (kind !== 'cell' && indices.length !== expected) {
    throw new Error(`${measurementTitle(kind)} requires exactly ${expected} selected atoms.`);
  }
  const sites = siteMap(scene);
  if (indices.some((index) => !sites.has(index))) throw new Error('The selection is out of date.');
  if (
    selectedAtoms &&
    (selectedAtoms.length !== indices.length ||
      selectedAtoms.some((atom, index) => atom.siteIndex !== indices[index]))
  ) {
    throw new Error('The selected atom instances are out of date.');
  }
  return kind === 'cell' ? [] : indices;
};

export const measurementTitle = (kind: MeasurementKind): string => {
  const titles: Record<MeasurementKind, string> = {
    distance: 'Atom-to-atom distance',
    angle: 'Bond angle',
    dihedral: 'Dihedral angle',
    atom_info: 'Atom information',
    cell: 'Cell parameters',
    bond_stats: 'Bond statistics',
    atom_plane: 'Atom-to-plane distance',
    plane_plane: 'Plane-to-plane angle',
    coordination: 'Coordination number',
    nearest_neighbors: 'Nearest neighbors',
  };
  return titles[kind];
};

export const measurementPrompt = (kind: MeasurementKind, selectionCount: number): string => {
  const steps: Partial<Record<MeasurementKind, string[]>> = {
    distance: ['the first atom', 'the second atom'],
    angle: ['the first arm atom', 'the vertex atom', 'the second arm atom'],
    dihedral: ['terminal atom A', 'central atom B', 'central atom C', 'terminal atom D'],
    atom_plane: [
      'the atom to measure',
      'the first plane atom',
      'the second plane atom',
      'the third plane atom',
    ],
    plane_plane: [
      'the first atom of plane 1',
      'the second atom of plane 1',
      'the third atom of plane 1',
      'the first atom of plane 2',
      'the second atom of plane 2',
      'the third atom of plane 2',
    ],
    bond_stats: ['the first atom type', 'the second atom type'],
    coordination: ['the central atom'],
    nearest_neighbors: ['the central atom'],
  };
  const expected = expectedSelectionCount(kind);
  const step = steps[kind]?.[selectionCount] ?? 'the next atom';
  return `Click ${step} (${Math.min(selectionCount + 1, expected)} of ${expected}). Hover to preview.`;
};

export const measurementStopHint = 'Click the stop button at any time to end measurement mode.';

const planeNormal = (points: Vector3Tuple[]): Vector3 => {
  const normal = vector(points[1])
    .sub(vector(points[0]))
    .cross(vector(points[2]).sub(vector(points[0])));
  if (normal.lengthSq() < 1e-20) throw new Error('Plane atoms must not be collinear.');
  return normal.normalize();
};

export const measurementProgressAnnotation = (
  kind: MeasurementKind,
  selectedPoints: Vector3Tuple[],
  hoverPoint?: Vector3Tuple,
): MeasurementAnnotation | undefined => {
  const points = [...selectedPoints.map((point) => [...point] as Vector3Tuple)];
  if (hoverPoint) points.push([...hoverPoint]);
  const segments: MeasurementSegment[] = [];
  const planePoints: Vector3Tuple[] = [];
  const candidatePlaneIndices: number[] = [];
  let projection: Vector3Tuple | undefined;
  const hoveringIndex = hoverPoint ? points.length - 1 : -1;
  const appendPlane = (indices: number[]): void => {
    const triangle = indices.map((index) => points[index]);
    if (triangle.some((point) => !point)) return;
    const planeIndex = planePoints.length / 3;
    planePoints.push(...triangle);
    if (indices.includes(hoveringIndex)) candidatePlaneIndices.push(planeIndex);
  };
  const appendChain = (): void => {
    for (let index = 1; index < points.length; index += 1) {
      segments.push(segment(points[index - 1], points[index]));
    }
  };

  if (kind === 'distance' && points.length >= 2) {
    segments.push(segment(points[0], points[1]));
  } else if (kind === 'angle') {
    appendChain();
  } else if (kind === 'dihedral') {
    appendChain();
    if (points.length >= 3) appendPlane([0, 1, 2]);
    if (points.length >= 4) appendPlane([1, 2, 3]);
  } else if (kind === 'atom_plane' && points.length >= 4) {
    const plane = points.slice(1, 4);
    try {
      const normal = planeNormal(plane);
      const signedDistance = vector(points[0]).sub(vector(plane[0])).dot(normal);
      projection = tuple(vector(points[0]).addScaledVector(normal, -signedDistance));
      segments.push(segment(points[0], projection));
      appendPlane([1, 2, 3]);
    } catch {
      return undefined;
    }
  } else if (kind === 'plane_plane') {
    if (points.length >= 3) appendPlane([0, 1, 2]);
    if (points.length >= 6) appendPlane([3, 4, 5]);
  }

  if (!segments.length && !planePoints.length) return undefined;
  return {
    ...baseAnnotation(
      'measurement-progress',
      kind,
      `${measurementTitle(kind)} preview`,
      points,
      segments,
      planePoints,
      projection,
    ),
    candidatePlaneIndices,
  };
};

const neighborsFor = (scene: AtomicSceneSpec, centerIndex: number): NeighborMeasurement[] => {
  const sites = siteMap(scene);
  const entries: NeighborMeasurement[] = [];
  const append = (siteIndex: number, image: ImageOffset, distance: number): void => {
    const site = sites.get(siteIndex);
    if (!site) return;
    entries.push({
      siteIndex,
      label: site.label,
      image,
      distance,
      cartesian: sitePosition(scene, site, image),
    });
  };
  for (const relation of scene.bondRelations) {
    const { fromSiteIndex: from, toSiteIndex: to, relativeImage: image, distance } = relation;
    if (from === centerIndex && to === centerIndex && image.some((value) => value !== 0)) {
      append(to, image, distance);
      append(from, [-image[0], -image[1], -image[2]], distance);
    } else if (from === centerIndex) {
      append(to, image, distance);
    } else if (to === centerIndex) {
      append(from, [-image[0], -image[1], -image[2]], distance);
    }
  }
  return entries.sort((first, second) => first.distance - second.distance);
};

const coordinationRecord = (
  scene: AtomicSceneSpec,
  kind: 'coordination' | 'nearest_neighbors',
  index: number,
  id: string,
): MeasurementRecord => {
  const site = siteMap(scene).get(index)!;
  const center = sitePosition(scene, site);
  const neighbors = neighborsFor(scene, index);
  const summary =
    kind === 'coordination'
      ? `Atom #${index + 1} ${site.label} · coordination ${neighbors.length}`
      : `Atom #${index + 1} ${site.label} · ${neighbors.length} nearest neighbors`;
  const details = neighbors.length
    ? neighbors
        .map(
          (neighbor, position) =>
            `${position + 1}. #${neighbor.siteIndex + 1} ${neighbor.label} · image [${neighbor.image.join(', ')}] · ${neighbor.distance.toFixed(5)} Å`,
        )
        .join('\n')
    : 'No bonded nearest neighbors were found by the active algorithm.';
  return {
    id,
    kind,
    title: measurementTitle(kind),
    summary,
    details,
    neighbors,
    annotation: baseAnnotation(
      id,
      kind,
      summary,
      [center],
      neighbors.map((neighbor) => segment(center, neighbor.cartesian)),
    ),
  };
};

export const measureScene = (
  scene: AtomicSceneSpec,
  kind: MeasurementKind,
  selectedSiteIndices: number[],
  id: string,
  selectedAtoms?: AtomInstanceSpec[],
): MeasurementRecord => {
  const indices = validateSelection(scene, kind, selectedSiteIndices, selectedAtoms);
  const title = measurementTitle(kind);
  const sites = siteMap(scene);

  if (kind === 'atom_info') {
    const index = indices[0];
    const site = sites.get(index)!;
    const summary = `Atom #${index + 1} ${site.label} · ${speciesKey(site)}`;
    const details = [
      site.fractional
        ? `Fractional: (${site.fractional.map((value) => value.toFixed(6)).join(', ')})`
        : undefined,
      `Cartesian: (${site.cartesian.map((value) => value.toFixed(6)).join(', ')}) Å`,
    ]
      .filter(Boolean)
      .join('\n');
    return {
      id,
      kind,
      title,
      summary,
      details,
      annotation: baseAnnotation(id, kind, summary, [site.cartesian]),
    };
  }

  if (kind === 'cell') {
    if (scene.kind !== 'crystal') throw new Error('Cell measurements require a crystal.');
    const [a, b, c] = scene.structure.lattice.map(vector);
    const lengths = [a.length(), b.length(), c.length()];
    const angle = (first: Vector3, second: Vector3): number =>
      (Math.acos(Math.max(-1, Math.min(1, first.dot(second) / first.length() / second.length()))) *
        180) /
      Math.PI;
    const angles = [angle(b, c), angle(a, c), angle(a, b)];
    const volume = Math.abs(a.dot(b.clone().cross(c)));
    const summary = `a ${lengths[0].toFixed(5)} · b ${lengths[1].toFixed(5)} · c ${lengths[2].toFixed(5)} Å`;
    const details = `α ${angles[0].toFixed(3)}° · β ${angles[1].toFixed(3)}° · γ ${angles[2].toFixed(3)}°\nVolume: ${volume.toFixed(5)} Å³`;
    const center = tuple(a.add(b).add(c).multiplyScalar(0.5));
    return {
      id,
      kind,
      title,
      summary,
      details,
      annotation: baseAnnotation(id, kind, summary, [center]),
      cellValues: {
        lengths: lengths as Vector3Tuple,
        angles: angles as Vector3Tuple,
        volume,
      },
    };
  }

  if (kind === 'bond_stats') {
    const pair = indices.map((index) => speciesKey(sites.get(index)!)).sort();
    const relations = scene.bondRelations.filter((relation) => {
      const relationPair = [
        speciesKey(sites.get(relation.fromSiteIndex)!),
        speciesKey(sites.get(relation.toSiteIndex)!),
      ].sort();
      return relationPair[0] === pair[0] && relationPair[1] === pair[1];
    });
    const distances = relations.map((relation) => relation.distance);
    const pairLabel = pair.join('–');
    const average = distances.length
      ? distances.reduce((sum, value) => sum + value, 0) / distances.length
      : undefined;
    const minimum = distances.length ? Math.min(...distances) : undefined;
    const maximum = distances.length ? Math.max(...distances) : undefined;
    const summary = distances.length
      ? `${pairLabel}: ${distances.length} bonds · average ${average!.toFixed(5)} Å`
      : `${pairLabel}: no bonds found`;
    const details = distances.length
      ? `Minimum: ${minimum!.toFixed(5)} Å · Maximum: ${maximum!.toFixed(5)} Å\nAlgorithm: ${scene.analysis.algorithm}`
      : `The active ${scene.analysis.algorithm} algorithm found no matching bonds.`;
    return {
      id,
      kind,
      title,
      summary,
      details,
      annotation: baseAnnotation(
        id,
        kind,
        summary,
        indices.map((index) => sites.get(index)!.cartesian),
        relations.map((relation) => relationSegment(scene, relation, sites)),
      ),
      bondStatistics: {
        pairLabel,
        count: distances.length,
        average,
        minimum,
        maximum,
        algorithm: scene.analysis.algorithm,
      },
    };
  }

  if (kind === 'coordination' || kind === 'nearest_neighbors') {
    return coordinationRecord(scene, kind, indices[0], id);
  }

  const coordinates = measurementCoordinates(scene, indices, selectedAtoms);
  const siteText = `Sites: ${sitesLabel(scene, indices)}`;
  if (kind === 'distance') {
    const value = vector(coordinates[1]).distanceTo(vector(coordinates[0]));
    const summary = `Distance: ${value.toFixed(5)} Å`;
    return geometricRecord(scene, indices, {
      id,
      kind,
      title,
      summary,
      numericValue: value,
      details: siteText,
      annotation: baseAnnotation(id, kind, summary, coordinates, [
        segment(coordinates[0], coordinates[1]),
      ]),
    });
  }

  if (kind === 'angle') {
    const first = vector(coordinates[0]).sub(vector(coordinates[1]));
    const third = vector(coordinates[2]).sub(vector(coordinates[1]));
    if (first.lengthSq() < 1e-20 || third.lengthSq() < 1e-20) {
      throw new Error('An angle cannot use coincident atoms.');
    }
    const value = (first.angleTo(third) * 180) / Math.PI;
    const summary = `Angle: ${value.toFixed(3)}°`;
    return geometricRecord(scene, indices, {
      id,
      kind,
      title,
      summary,
      numericValue: value,
      details: siteText,
      annotation: baseAnnotation(id, kind, summary, coordinates, [
        segment(coordinates[1], coordinates[0]),
        segment(coordinates[1], coordinates[2]),
      ]),
    });
  }

  if (kind === 'dihedral') {
    const b0 = vector(coordinates[0]).sub(vector(coordinates[1]));
    const b1 = vector(coordinates[2]).sub(vector(coordinates[1]));
    const b2 = vector(coordinates[3]).sub(vector(coordinates[2]));
    if (b1.lengthSq() < 1e-20) throw new Error('The central bond must be nonzero.');
    b1.normalize();
    const first = b0.sub(b1.clone().multiplyScalar(b0.dot(b1)));
    const second = b2.sub(b1.clone().multiplyScalar(b2.dot(b1)));
    if (first.lengthSq() < 1e-20 || second.lengthSq() < 1e-20) {
      throw new Error('A dihedral angle is undefined for collinear atoms.');
    }
    const value =
      (Math.atan2(b1.clone().cross(first).dot(second), first.dot(second)) * 180) / Math.PI;
    const summary = `Dihedral: ${value.toFixed(3)}°`;
    return geometricRecord(scene, indices, {
      id,
      kind,
      title,
      summary,
      numericValue: value,
      details: siteText,
      annotation: baseAnnotation(
        id,
        kind,
        summary,
        coordinates,
        [
          segment(coordinates[0], coordinates[1]),
          segment(coordinates[1], coordinates[2]),
          segment(coordinates[2], coordinates[3]),
        ],
        [
          coordinates[0],
          coordinates[1],
          coordinates[2],
          coordinates[1],
          coordinates[2],
          coordinates[3],
        ],
      ),
    });
  }

  if (kind === 'atom_plane') {
    const plane = coordinates.slice(1, 4);
    const normal = planeNormal(plane);
    const signedDistance = vector(coordinates[0]).sub(vector(plane[0])).dot(normal);
    const projection = tuple(vector(coordinates[0]).addScaledVector(normal, -signedDistance));
    const summary = `Atom-to-plane distance: ${Math.abs(signedDistance).toFixed(5)} Å`;
    return geometricRecord(scene, indices, {
      id,
      kind,
      title,
      summary,
      details: siteText,
      annotation: baseAnnotation(
        id,
        kind,
        summary,
        coordinates,
        [segment(coordinates[0], projection)],
        plane,
        projection,
      ),
    });
  }

  const firstPlane = coordinates.slice(0, 3);
  const secondPlane = coordinates.slice(3, 6);
  const firstNormal = planeNormal(firstPlane);
  const secondNormal = planeNormal(secondPlane);
  const value =
    (Math.acos(Math.max(-1, Math.min(1, Math.abs(firstNormal.dot(secondNormal))))) * 180) / Math.PI;
  const summary = `Plane angle: ${value.toFixed(3)}°`;
  return geometricRecord(scene, indices, {
    id,
    kind,
    title,
    summary,
    details: siteText,
    annotation: baseAnnotation(id, kind, summary, coordinates, [], coordinates),
  });
};
