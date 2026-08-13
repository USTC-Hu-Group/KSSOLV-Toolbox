import type { ConstructionBondParameterSpec, Matrix3Tuple, Vector3Tuple } from './scene/types';
import type { AdsorbateFragment } from './adsorbateFragments';

export type ModelingTool = 'orbit' | 'box' | 'lasso' | 'move' | 'rotate' | 'sketch' | 'adsorbate';
export type ModelingAxis = 'screen' | 'x' | 'y' | 'z';
export type CoordinateMode = 'cartesian' | 'fractional';

export type AdsorbateDraftStage = 'anchor' | 'orient' | 'ready';

export interface AdsorbateDraft {
  anchorSiteIndex: number;
  host: Vector3Tuple;
  fragment: AdsorbateFragment;
  coordinates: Vector3Tuple[];
  stage: AdsorbateDraftStage;
}

export interface SketchDraft {
  stage: 'place-atom' | 'drag-bond' | 'connect-atoms' | 'preview';
  start?: Vector3Tuple;
  end: Vector3Tuple;
  anchorSiteIndex?: number;
  targetSiteIndex?: number;
  element: string;
  bondOrder: number;
  formalCharge: number;
  hybridization: 'auto' | 'sp' | 'sp2' | 'sp3';
  aromatic: boolean;
}

export interface SketchChemistry {
  element: string;
  bondOrder: number;
  formalCharge?: number;
  hybridization?: SketchDraft['hybridization'];
  aromatic?: boolean;
}

export const beginSketchDraft = (
  end: Vector3Tuple,
  chemistry: SketchChemistry,
  anchor?: { position: Vector3Tuple; siteIndex: number },
): SketchDraft => ({
  stage: anchor ? 'drag-bond' : 'place-atom',
  start: anchor ? [...anchor.position] : undefined,
  end: [...end],
  anchorSiteIndex: anchor?.siteIndex,
  element: chemistry.element.trim() || 'C',
  bondOrder: chemistry.bondOrder,
  formalCharge: chemistry.formalCharge ?? 0,
  hybridization: chemistry.hybridization ?? 'auto',
  aromatic: chemistry.aromatic ?? chemistry.bondOrder === 1.5,
});

export const updateSketchDraft = (
  draft: SketchDraft,
  end: Vector3Tuple,
  targetSiteIndex?: number,
): SketchDraft => ({
  ...draft,
  stage:
    targetSiteIndex === undefined ? (draft.start ? 'drag-bond' : 'place-atom') : 'connect-atoms',
  end: [...end],
  targetSiteIndex,
});

export const constructionBondLength = (
  parameters: readonly ConstructionBondParameterSpec[],
  firstElement: string,
  secondElement: string,
  bondOrder: number,
): number | undefined =>
  parameters.find(
    (parameter) =>
      Math.abs(parameter.bondOrder - bondOrder) < 1e-12 &&
      ((parameter.firstElement === firstElement && parameter.secondElement === secondElement) ||
        (parameter.firstElement === secondElement && parameter.secondElement === firstElement)),
  )?.value;

export const applyConstructionBondLength = (
  origin: Vector3Tuple,
  pointer: Vector3Tuple,
  bondLength: number,
  fallbackDirection: Vector3Tuple,
  minimumExplicitLength = 0.6,
): Vector3Tuple =>
  length(subtract(pointer, origin)) < minimumExplicitLength
    ? pointAtBondLength(origin, pointer, bondLength, fallbackDirection)
    : [...pointer];

export const previewSketchDraft = (draft: SketchDraft): SketchDraft => ({
  ...draft,
  stage: 'preview',
});

const length = (value: Vector3Tuple): number => Math.hypot(...value);

const subtract = (left: Vector3Tuple, right: Vector3Tuple): Vector3Tuple => [
  left[0] - right[0],
  left[1] - right[1],
  left[2] - right[2],
];

const addScaled = (
  origin: Vector3Tuple,
  direction: Vector3Tuple,
  distance: number,
): Vector3Tuple => [
  origin[0] + direction[0] * distance,
  origin[1] + direction[1] * distance,
  origin[2] + direction[2] * distance,
];

export const normalizeModelingVector = (
  value: Vector3Tuple,
  fallback: Vector3Tuple = [0, 0, 1],
): Vector3Tuple => {
  const magnitude = length(value);
  if (magnitude > 1e-12) return value.map((component) => component / magnitude) as Vector3Tuple;
  const fallbackMagnitude = Math.max(length(fallback), 1e-12);
  return fallback.map((component) => component / fallbackMagnitude) as Vector3Tuple;
};

export const crystalSurfaceNormal = (lattice: Matrix3Tuple): Vector3Tuple =>
  normalizeModelingVector(lattice[2]);

export const pointAtBondLength = (
  origin: Vector3Tuple,
  toward: Vector3Tuple,
  bondLength: number,
  fallbackDirection: Vector3Tuple = [0, 0, 1],
): Vector3Tuple =>
  addScaled(
    origin,
    normalizeModelingVector(subtract(toward, origin), fallbackDirection),
    Math.max(bondLength, 0),
  );

export const createAdsorbateDraft = (
  fragment: AdsorbateFragment,
  anchorSiteIndex: number,
  host: Vector3Tuple,
  surfaceNormal: Vector3Tuple,
  hostBondLength = fragment.defaultHostBondLength,
): AdsorbateDraft => {
  const direction = normalizeModelingVector(surfaceNormal);
  const anchor = addScaled(host, direction, hostBondLength);
  const localAnchor = fragment.coordinates[fragment.anchorAtomIndex]!;
  const coordinates = fragment.coordinates.map((point) => {
    const aligned = alignLocalDirection(
      point,
      localAnchor,
      direction,
      fragment.orientation ?? [0, 0, 1],
    );
    return addScaled(anchor, aligned, 1);
  });
  return {
    anchorSiteIndex,
    host: [...host],
    fragment,
    coordinates,
    stage: 'anchor',
  };
};

const alignLocalDirection = (
  point: Vector3Tuple,
  origin: Vector3Tuple,
  target: Vector3Tuple,
  localDirection: Vector3Tuple,
): Vector3Tuple => {
  const source = normalizeModelingVector(localDirection);
  const unitTarget = normalizeModelingVector(target);
  const axis: Vector3Tuple = [
    source[1] * unitTarget[2] - source[2] * unitTarget[1],
    source[2] * unitTarget[0] - source[0] * unitTarget[2],
    source[0] * unitTarget[1] - source[1] * unitTarget[0],
  ];
  const sine = length(axis);
  const cosine = source[0] * unitTarget[0] + source[1] * unitTarget[1] + source[2] * unitTarget[2];
  if (sine <= 1e-12) {
    if (cosine >= 0) return subtract(point, origin);
    const basis: Vector3Tuple = Math.abs(source[0]) < 0.9 ? [1, 0, 0] : [0, 1, 0];
    const perpendicular = normalizeModelingVector([
      source[1] * basis[2] - source[2] * basis[1],
      source[2] * basis[0] - source[0] * basis[2],
      source[0] * basis[1] - source[1] * basis[0],
    ]);
    return rotatePointAroundBond(point, origin, perpendicular, 180).map(
      (component, index) => component - origin[index]!,
    ) as Vector3Tuple;
  }
  const rotated = rotatePointAroundBond(
    point,
    origin,
    axis.map((component) => component / sine) as Vector3Tuple,
    (Math.atan2(sine, cosine) * 180) / Math.PI,
  );
  return subtract(rotated, origin);
};

/** Rodrigues rotation used by the bond-axis drag gesture. */
export const rotatePointAroundBond = (
  point: Vector3Tuple,
  origin: Vector3Tuple,
  axis: Vector3Tuple,
  angleDegrees: number,
): Vector3Tuple => {
  const unit = normalizeModelingVector(axis);
  const offset = subtract(point, origin);
  const radians = (angleDegrees * Math.PI) / 180;
  const cosine = Math.cos(radians);
  const sine = Math.sin(radians);
  const cross: Vector3Tuple = [
    unit[1] * offset[2] - unit[2] * offset[1],
    unit[2] * offset[0] - unit[0] * offset[2],
    unit[0] * offset[1] - unit[1] * offset[0],
  ];
  const projection = unit[0] * offset[0] + unit[1] * offset[1] + unit[2] * offset[2];
  return [
    origin[0] + offset[0] * cosine + cross[0] * sine + unit[0] * projection * (1 - cosine),
    origin[1] + offset[1] * cosine + cross[1] * sine + unit[1] * projection * (1 - cosine),
    origin[2] + offset[2] * cosine + cross[2] * sine + unit[2] * projection * (1 - cosine),
  ];
};

export const adsorbateHostBondLength = (draft: AdsorbateDraft): number =>
  length(subtract(draft.coordinates[draft.fragment.anchorAtomIndex]!, draft.host));

export const adsorbateDraftIssue = (
  draft: AdsorbateDraft,
  otherAtoms: readonly Vector3Tuple[] = [],
  minimumContact = 0.35,
): string => {
  if (adsorbateHostBondLength(draft) < minimumContact) return 'Host–adsorbate bond is too short';
  const shortBond = draft.fragment.bonds.some(
    ([first, second]) =>
      length(subtract(draft.coordinates[first]!, draft.coordinates[second]!)) < minimumContact,
  );
  if (shortBond) return 'An internal adsorbate bond is too short';
  const closest = otherAtoms.reduce(
    (minimum, atom) =>
      Math.min(
        minimum,
        ...draft.coordinates.map((coordinate) => length(subtract(atom, coordinate))),
      ),
    Number.POSITIVE_INFINITY,
  );
  return closest < minimumContact ? `Close contact ${closest.toFixed(2)} Å` : '';
};

export const moveAdsorbateAnchor = (
  draft: AdsorbateDraft,
  anchor: Vector3Tuple,
): AdsorbateDraft => {
  const current = draft.coordinates[draft.fragment.anchorAtomIndex]!;
  const delta = subtract(anchor, current);
  return {
    ...draft,
    coordinates: draft.coordinates.map((point) => addScaled(point, delta, 1)),
  };
};

export const rotateAdsorbateAroundHostBond = (
  draft: AdsorbateDraft,
  angleDegrees: number,
): AdsorbateDraft => {
  const anchor = draft.coordinates[draft.fragment.anchorAtomIndex]!;
  const axis = subtract(anchor, draft.host);
  return {
    ...draft,
    coordinates: draft.coordinates.map((point, index) =>
      index === draft.fragment.anchorAtomIndex
        ? [...point]
        : rotatePointAroundBond(point, anchor, axis, angleDegrees),
    ),
  };
};

export const sketchDraftLength = (draft: Pick<SketchDraft, 'start' | 'end'>): number | undefined =>
  draft.start ? length(subtract(draft.end, draft.start)) : undefined;

export const sketchDraftIssue = (draft: SketchDraft, minimumBondLength = 0.6): string => {
  if (draft.anchorSiteIndex !== undefined && draft.targetSiteIndex === draft.anchorSiteIndex) {
    return 'Choose a different target atom';
  }
  const bondLength = sketchDraftLength(draft);
  if (bondLength !== undefined && bondLength < minimumBondLength) return 'Bond is too short';
  if (!draft.element.trim()) return 'Choose an element';
  return '';
};

export type LiveGeometryKind = 'distance' | 'angle' | 'dihedral';

/** Calculate geometry continuously from draft/hover coordinates without requiring a scene commit. */
export const liveGeometryValue = (
  kind: LiveGeometryKind,
  points: readonly Vector3Tuple[],
): number | undefined => {
  const required = kind === 'distance' ? 2 : kind === 'angle' ? 3 : 4;
  if (points.length !== required) return undefined;
  const dot = (a: Vector3Tuple, b: Vector3Tuple): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a: Vector3Tuple, b: Vector3Tuple): Vector3Tuple => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
  const angle = (a: Vector3Tuple, b: Vector3Tuple): number | undefined => {
    const denominator = length(a) * length(b);
    if (denominator <= 1e-12) return undefined;
    return (Math.acos(Math.max(-1, Math.min(1, dot(a, b) / denominator))) * 180) / Math.PI;
  };
  if (kind === 'distance') return length(subtract(points[1], points[0]));
  if (kind === 'angle') {
    return angle(subtract(points[0], points[1]), subtract(points[2], points[1]));
  }
  const b0 = subtract(points[0], points[1]);
  const b1 = subtract(points[2], points[1]);
  const b2 = subtract(points[3], points[2]);
  const b1Length = length(b1);
  if (b1Length <= 1e-12) return undefined;
  const axis = b1.map((component) => component / b1Length) as Vector3Tuple;
  const first = subtract(b0, axis.map((component) => component * dot(b0, axis)) as Vector3Tuple);
  const second = subtract(b2, axis.map((component) => component * dot(b2, axis)) as Vector3Tuple);
  if (length(first) <= 1e-12 || length(second) <= 1e-12) return undefined;
  return (Math.atan2(dot(cross(axis, first), second), dot(first, second)) * 180) / Math.PI;
};

export type CompatibleMouseTransform = 'move' | 'rotate';

/**
 * Materials Studio-style object transforms that do not replace the existing
 * KSSOLV camera controls or single-letter modeling tools.
 */
export const compatibleMouseTransformFor = (
  event: Pick<PointerEvent, 'button' | 'ctrlKey' | 'metaKey' | 'pointerType' | 'shiftKey'>,
): CompatibleMouseTransform | undefined => {
  if (event.pointerType !== 'mouse' || !event.shiftKey || event.ctrlKey || event.metaKey) {
    return undefined;
  }
  if (event.button === 1) return 'move';
  if (event.button === 2) return 'rotate';
  return undefined;
};
