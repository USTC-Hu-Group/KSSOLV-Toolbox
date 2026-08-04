import type {
  AtomInstanceSpec,
  AtomicSceneSpec,
  BondInstanceSpec,
  BondRelationSpec,
  Matrix3Tuple,
  PolyhedronSpec,
  SceneWarning,
  SiteSpec,
  Vector3Tuple,
} from './types';

export class SceneValidationError extends Error {
  constructor(
    message: string,
    readonly path: string,
  ) {
    super(`${path}: ${message}`);
    this.name = 'SceneValidationError';
  }
}

const objectAt = (value: unknown, path: string): Record<string, unknown> => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new SceneValidationError('expected an object', path);
  }
  return value as Record<string, unknown>;
};

const arrayAt = (value: unknown, path: string): unknown[] => {
  if (!Array.isArray(value)) {
    throw new SceneValidationError('expected an array', path);
  }
  return value;
};

const stringAt = (value: unknown, path: string): string => {
  if (typeof value !== 'string') {
    throw new SceneValidationError('expected a string', path);
  }
  return value;
};

const finiteAt = (value: unknown, path: string): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new SceneValidationError('expected a finite number', path);
  }
  return value;
};

const integerAt = (value: unknown, path: string): number => {
  const number = finiteAt(value, path);
  if (!Number.isInteger(number)) {
    throw new SceneValidationError('expected an integer', path);
  }
  return number;
};

const booleanAt = (value: unknown, path: string): boolean => {
  if (typeof value !== 'boolean') {
    throw new SceneValidationError('expected a boolean', path);
  }
  return value;
};

const vectorAt = (value: unknown, path: string): Vector3Tuple => {
  const input = arrayAt(value, path);
  if (input.length !== 3) {
    throw new SceneValidationError('expected exactly three entries', path);
  }
  return input.map((entry, index) => finiteAt(entry, `${path}[${index}]`)) as Vector3Tuple;
};

const matrixAt = (value: unknown, path: string): Matrix3Tuple => {
  const input = arrayAt(value, path);
  if (input.length !== 3) {
    throw new SceneValidationError('expected exactly three rows', path);
  }
  return input.map((entry, index) => vectorAt(entry, `${path}[${index}]`)) as Matrix3Tuple;
};

const parseSite = (value: unknown, index: number): SiteSpec => {
  const path = `sites[${index}]`;
  const site = objectAt(value, path);
  const species = arrayAt(site.species, `${path}.species`).map((entry, componentIndex) => {
    const componentPath = `${path}.species[${componentIndex}]`;
    const component = objectAt(entry, componentPath);
    const occupancy = finiteAt(component.occupancy, `${componentPath}.occupancy`);
    if (occupancy <= 0 || occupancy > 1) {
      throw new SceneValidationError(
        'must be in the interval (0, 1]',
        `${componentPath}.occupancy`,
      );
    }
    return {
      symbol: stringAt(component.symbol, `${componentPath}.symbol`),
      occupancy,
      atomicNumber: integerAt(component.atomicNumber, `${componentPath}.atomicNumber`),
      colorVesta: vectorAt(component.colorVesta, `${componentPath}.colorVesta`),
      colorJmol: vectorAt(component.colorJmol, `${componentPath}.colorJmol`),
      atomicRadius: finiteAt(component.atomicRadius, `${componentPath}.atomicRadius`),
    };
  });
  if (species.length === 0) {
    throw new SceneValidationError(
      'must contain at least one species component',
      `${path}.species`,
    );
  }
  const occupancy = species.reduce((sum, component) => sum + component.occupancy, 0);
  if (occupancy > 1.000001) {
    throw new SceneValidationError('occupancies sum to more than one', `${path}.species`);
  }
  return {
    id: stringAt(site.id, `${path}.id`),
    siteIndex: integerAt(site.siteIndex, `${path}.siteIndex`),
    label: stringAt(site.label, `${path}.label`),
    species,
    ...(site.fractional === undefined
      ? {}
      : { fractional: vectorAt(site.fractional, `${path}.fractional`) }),
    cartesian: vectorAt(site.cartesian, `${path}.cartesian`),
    ...(site.magmom === undefined ? {} : { magmom: vectorAt(site.magmom, `${path}.magmom`) }),
  };
};

const parseAtom = (value: unknown, index: number): AtomInstanceSpec => {
  const path = `atomInstances[${index}]`;
  const atom = objectAt(value, path);
  const visibility = stringAt(atom.visibility, `${path}.visibility`);
  if (!['base', 'boundary', 'bonded', 'repeat'].includes(visibility)) {
    throw new SceneValidationError('has an unsupported visibility group', `${path}.visibility`);
  }
  const imageOffset = vectorAt(atom.imageOffset, `${path}.imageOffset`);
  if (!imageOffset.every(Number.isInteger)) {
    throw new SceneValidationError('entries must be integers', `${path}.imageOffset`);
  }
  return {
    id: stringAt(atom.id, `${path}.id`),
    siteId: stringAt(atom.siteId, `${path}.siteId`),
    siteIndex: integerAt(atom.siteIndex, `${path}.siteIndex`),
    imageOffset,
    position: vectorAt(atom.position, `${path}.position`),
    visibility: visibility as AtomInstanceSpec['visibility'],
  };
};

const parseBondInstance = (value: unknown, index: number): BondInstanceSpec => {
  const path = `bondInstances[${index}]`;
  const bond = objectAt(value, path);
  const visibility = stringAt(bond.visibility, `${path}.visibility`);
  if (visibility !== 'base' && visibility !== 'bonded') {
    throw new SceneValidationError('has an unsupported visibility group', `${path}.visibility`);
  }
  const fromImage = vectorAt(bond.fromImage, `${path}.fromImage`);
  const toImage = vectorAt(bond.toImage, `${path}.toImage`);
  if (![...fromImage, ...toImage].every(Number.isInteger)) {
    throw new SceneValidationError('image entries must be integers', path);
  }
  const distance = finiteAt(bond.distance, `${path}.distance`);
  if (distance <= 0) {
    throw new SceneValidationError('must be positive', `${path}.distance`);
  }
  return {
    id: stringAt(bond.id, `${path}.id`),
    relationId: stringAt(bond.relationId, `${path}.relationId`),
    fromSiteIndex: integerAt(bond.fromSiteIndex, `${path}.fromSiteIndex`),
    toSiteIndex: integerAt(bond.toSiteIndex, `${path}.toSiteIndex`),
    fromImage,
    toImage,
    start: vectorAt(bond.start, `${path}.start`),
    end: vectorAt(bond.end, `${path}.end`),
    distance,
    visibility,
    ...(bond.order === undefined ? {} : { order: finiteAt(bond.order, `${path}.order`) }),
    ...(bond.origin === undefined
      ? {}
      : {
          origin: molecularOriginAt(bond.origin, `${path}.origin`),
        }),
  };
};

const parseBondRelation = (value: unknown, index: number): BondRelationSpec => {
  const path = `bondRelations[${index}]`;
  const relation = objectAt(value, path);
  const distance = finiteAt(relation.distance, `${path}.distance`);
  if (distance <= 0) {
    throw new SceneValidationError('must be positive', `${path}.distance`);
  }
  const weight = relation.weight === null ? null : finiteAt(relation.weight, `${path}.weight`);
  const relativeImage = vectorAt(relation.relativeImage, `${path}.relativeImage`);
  if (!relativeImage.every(Number.isInteger)) {
    throw new SceneValidationError('entries must be integers', `${path}.relativeImage`);
  }
  return {
    id: stringAt(relation.id, `${path}.id`),
    fromSiteIndex: integerAt(relation.fromSiteIndex, `${path}.fromSiteIndex`),
    toSiteIndex: integerAt(relation.toSiteIndex, `${path}.toSiteIndex`),
    relativeImage,
    distance,
    weight,
    ...(relation.order === undefined ? {} : { order: finiteAt(relation.order, `${path}.order`) }),
    ...(relation.origin === undefined
      ? {}
      : { origin: molecularOriginAt(relation.origin, `${path}.origin`) }),
  };
};

const molecularOriginAt = (value: unknown, path: string): 'source' | 'OpenBabelNN' => {
  const origin = stringAt(value, path);
  if (origin !== 'source' && origin !== 'OpenBabelNN') {
    throw new SceneValidationError('has an unsupported topology origin', path);
  }
  return origin;
};

const parsePolyhedron = (value: unknown, index: number): PolyhedronSpec => {
  const path = `polyhedra[${index}]`;
  const polyhedron = objectAt(value, path);
  const vertices = arrayAt(polyhedron.vertices, `${path}.vertices`).map((entry, vertexIndex) =>
    vectorAt(entry, `${path}.vertices[${vertexIndex}]`),
  );
  if (vertices.length < 4) {
    throw new SceneValidationError('requires at least four vertices', `${path}.vertices`);
  }
  const visibility = stringAt(polyhedron.visibility, `${path}.visibility`);
  if (visibility !== 'base' && visibility !== 'bonded') {
    throw new SceneValidationError('has an unsupported visibility group', `${path}.visibility`);
  }
  const tint = vectorAt(polyhedron.color, `${path}.color`);
  if (tint.some((entry) => entry < 0 || entry > 255)) {
    throw new SceneValidationError('entries must be between 0 and 255', `${path}.color`);
  }
  return {
    id: stringAt(polyhedron.id, `${path}.id`),
    centerSiteIndex: integerAt(polyhedron.centerSiteIndex, `${path}.centerSiteIndex`),
    center: vectorAt(polyhedron.center, `${path}.center`),
    vertices,
    color: tint,
    visibility,
  };
};

const parseWarning = (value: unknown, index: number): SceneWarning => {
  const path = `warnings[${index}]`;
  const warning = objectAt(value, path);
  const severity = stringAt(warning.severity, `${path}.severity`);
  if (!['info', 'warning', 'error'].includes(severity)) {
    throw new SceneValidationError('has an unsupported severity', `${path}.severity`);
  }
  return {
    code: stringAt(warning.code, `${path}.code`),
    message: stringAt(warning.message, `${path}.message`),
    severity: severity as SceneWarning['severity'],
  };
};

export const validateScene = (value: unknown): AtomicSceneSpec => {
  const scene = objectAt(value, 'scene');
  if (scene.schemaVersion !== '2.0') {
    throw new SceneValidationError('unsupported schema version', 'schemaVersion');
  }
  const kind = stringAt(scene.kind, 'kind');
  if (kind !== 'crystal' && kind !== 'molecule') {
    throw new SceneValidationError('unsupported atomic scene kind', 'kind');
  }
  const analysis = objectAt(scene.analysis, 'analysis');
  stringAt(scene.requestId, 'requestId');
  const sites = arrayAt(scene.sites, 'sites').map(parseSite);
  const atoms = arrayAt(scene.atomInstances, 'atomInstances').map(parseAtom);
  const relations = arrayAt(scene.bondRelations, 'bondRelations').map(parseBondRelation);
  const bonds = arrayAt(scene.bondInstances, 'bondInstances').map(parseBondInstance);
  const polyhedra = arrayAt(scene.polyhedra, 'polyhedra').map(parsePolyhedron);
  arrayAt(scene.warnings, 'warnings').map(parseWarning);
  let declaredSiteCount: number;
  if (kind === 'crystal') {
    if (scene.molecule !== undefined) {
      throw new SceneValidationError('crystal scenes cannot contain molecule metadata', 'molecule');
    }
    const structure = objectAt(scene.structure, 'structure');
    stringAt(structure.formula, 'structure.formula');
    matrixAt(structure.lattice, 'structure.lattice');
    const periodic = arrayAt(structure.periodic, 'structure.periodic');
    if (periodic.length !== 3) {
      throw new SceneValidationError('expected exactly three entries', 'structure.periodic');
    }
    periodic.forEach((entry, index) => booleanAt(entry, `structure.periodic[${index}]`));
    const repeat = vectorAt(structure.repeat, 'structure.repeat');
    if (repeat.some((entry) => !Number.isInteger(entry) || entry < 1 || entry > 8)) {
      throw new SceneValidationError('entries must be integers from 1 to 8', 'structure.repeat');
    }
    declaredSiteCount = integerAt(structure.siteCount, 'structure.siteCount');
    booleanAt(structure.isOrdered, 'structure.isOrdered');
    sites.forEach((site, index) => {
      if (!site.fractional) {
        throw new SceneValidationError(
          'crystal sites require fractional coordinates',
          `sites[${index}]`,
        );
      }
    });
  } else {
    if (scene.structure !== undefined) {
      throw new SceneValidationError(
        'molecule scenes cannot contain crystal metadata',
        'structure',
      );
    }
    const molecule = objectAt(scene.molecule, 'molecule');
    stringAt(molecule.formula, 'molecule.formula');
    declaredSiteCount = integerAt(molecule.atomCount, 'molecule.atomCount');
    booleanAt(molecule.isOrdered, 'molecule.isOrdered');
    finiteAt(molecule.charge, 'molecule.charge');
    if (integerAt(molecule.spinMultiplicity, 'molecule.spinMultiplicity') < 1) {
      throw new SceneValidationError('must be positive', 'molecule.spinMultiplicity');
    }
    stringAt(molecule.inputFormat, 'molecule.inputFormat');
    const frameIndex = integerAt(molecule.frameIndex, 'molecule.frameIndex');
    const frameCount = integerAt(molecule.frameCount, 'molecule.frameCount');
    if (frameIndex < 1 || frameCount < frameIndex) {
      throw new SceneValidationError('frame index is outside the input', 'molecule.frameIndex');
    }
    if (polyhedra.length) {
      throw new SceneValidationError('molecule scenes cannot contain polyhedra', 'polyhedra');
    }
  }
  if (declaredSiteCount !== sites.length) {
    throw new SceneValidationError('does not match the sites array', 'siteCount');
  }
  const algorithm = stringAt(analysis.algorithm, 'analysis.algorithm');
  const algorithms =
    kind === 'crystal'
      ? [
          'CrystalNN',
          'CutOffDictNN',
          'JmolNN',
          'MinimumDistanceNN',
          'MinimumOKeeffeNN',
          'EconNN',
          'BrunnerNNReciprocal',
          ...(declaredSiteCount === 0 ? ['None'] : []),
        ]
      : ['Source', 'OpenBabelNN', 'None'];
  if (!algorithms.includes(algorithm)) {
    throw new SceneValidationError('uses an unsupported algorithm', 'analysis.algorithm');
  }
  if (
    kind === 'crystal' &&
    declaredSiteCount === 0 &&
    (atoms.length > 0 || relations.length > 0 || bonds.length > 0 || polyhedra.length > 0)
  ) {
    throw new SceneValidationError('cannot contain atomic geometry', 'structure.siteCount');
  }
  objectAt(analysis.parameters, 'analysis.parameters');
  if (analysis.source !== 'matgenlab') {
    throw new SceneValidationError('must be matgenlab', 'analysis.source');
  }
  stringAt(analysis.sourceVersion, 'analysis.sourceVersion');
  if (finiteAt(analysis.elapsedMilliseconds, 'analysis.elapsedMilliseconds') < 0) {
    throw new SceneValidationError('must be nonnegative', 'analysis.elapsedMilliseconds');
  }
  const siteIds = new Set(sites.map((site) => site.id));
  const siteIndices = new Set(sites.map((site) => site.siteIndex));
  if (siteIds.size !== sites.length || siteIndices.size !== sites.length) {
    throw new SceneValidationError('site identifiers and indices must be unique', 'sites');
  }
  atoms.forEach((atom, index) => {
    if (!siteIds.has(atom.siteId) || !siteIndices.has(atom.siteIndex)) {
      throw new SceneValidationError('references an unknown site', `atomInstances[${index}]`);
    }
  });
  const atomIds = new Set(atoms.map((atom) => atom.id));
  if (atomIds.size !== atoms.length) {
    throw new SceneValidationError('atom identifiers must be unique', 'atomInstances');
  }
  const relationIds = new Set(relations.map((relation) => relation.id));
  const relationKeys = new Set(
    relations.map(
      (relation) =>
        `${relation.fromSiteIndex}:${relation.toSiteIndex}:${relation.relativeImage.join(',')}`,
    ),
  );
  if (relationIds.size !== relations.length || relationKeys.size !== relations.length) {
    throw new SceneValidationError('scientific bond relations must be unique', 'bondRelations');
  }
  bonds.forEach((bond, index) => {
    if (!siteIndices.has(bond.fromSiteIndex) || !siteIndices.has(bond.toSiteIndex)) {
      throw new SceneValidationError('references an unknown site', `bondInstances[${index}]`);
    }
    if (!relationIds.has(bond.relationId)) {
      throw new SceneValidationError(
        'references an unknown scientific relation',
        `bondInstances[${index}].relationId`,
      );
    }
    const measured = Math.hypot(
      bond.end[0] - bond.start[0],
      bond.end[1] - bond.start[1],
      bond.end[2] - bond.start[2],
    );
    if (Math.abs(measured - bond.distance) > 1e-8) {
      throw new SceneValidationError(
        'distance does not match endpoints',
        `bondInstances[${index}]`,
      );
    }
  });
  const bondIds = new Set(bonds.map((bond) => bond.id));
  if (bondIds.size !== bonds.length) {
    throw new SceneValidationError('bond instance identifiers must be unique', 'bondInstances');
  }
  polyhedra.forEach((polyhedron, index) => {
    if (!siteIndices.has(polyhedron.centerSiteIndex)) {
      throw new SceneValidationError('references an unknown site', `polyhedra[${index}]`);
    }
  });
  return value as AtomicSceneSpec;
};

export const scientificSceneFingerprint = (scene: AtomicSceneSpec): string =>
  JSON.stringify({
    kind: scene.kind,
    model: scene.kind === 'crystal' ? scene.structure : scene.molecule,
    sites: scene.sites.map(({ siteIndex, fractional, cartesian, species }) => ({
      siteIndex,
      fractional,
      cartesian,
      species: species.map(({ symbol, occupancy }) => ({ symbol, occupancy })),
    })),
    relations: scene.bondRelations.map(
      ({ fromSiteIndex, toSiteIndex, relativeImage, distance, weight }) => ({
        fromSiteIndex,
        toSiteIndex,
        relativeImage,
        distance,
        weight,
      }),
    ),
  });
