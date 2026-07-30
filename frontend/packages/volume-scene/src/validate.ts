import type {
  VolumeChannelSpec,
  VolumeGridSpec,
  VolumeSceneSpec,
  VolumeValueEncoding,
} from './types';

export class VolumeSceneValidationError extends Error {
  constructor(
    message: string,
    readonly path: string,
  ) {
    super(`${path}: ${message}`);
    this.name = 'VolumeSceneValidationError';
  }
}

type ObjectValue = Record<string, unknown>;

const objectAt = (value: unknown, path: string): ObjectValue => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new VolumeSceneValidationError('expected an object', path);
  }
  return value as ObjectValue;
};

const arrayAt = (value: unknown, path: string): unknown[] => {
  if (!Array.isArray(value)) throw new VolumeSceneValidationError('expected an array', path);
  return value;
};

const stringAt = (value: unknown, path: string): string => {
  if (typeof value !== 'string') throw new VolumeSceneValidationError('expected a string', path);
  return value;
};

const finiteAt = (value: unknown, path: string): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new VolumeSceneValidationError('expected a finite number', path);
  }
  return value;
};

const integerAt = (value: unknown, path: string, minimum = 0): number => {
  const result = finiteAt(value, path);
  if (!Number.isSafeInteger(result) || result < minimum) {
    throw new VolumeSceneValidationError(`expected a safe integer >= ${minimum}`, path);
  }
  return result;
};

const booleanAt = (value: unknown, path: string): boolean => {
  if (typeof value !== 'boolean') {
    throw new VolumeSceneValidationError('expected a boolean', path);
  }
  return value;
};

const vectorAt = (value: unknown, path: string): [number, number, number] => {
  const input = arrayAt(value, path);
  if (input.length !== 3) {
    throw new VolumeSceneValidationError('expected exactly three entries', path);
  }
  return input.map((entry, index) => finiteAt(entry, `${path}[${index}]`)) as [
    number,
    number,
    number,
  ];
};

const determinant = (matrix: [number[], number[], number[]]): number =>
  matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]) -
  matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0]) +
  matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]);

const parseGrid = (value: unknown): VolumeGridSpec => {
  const grid = objectAt(value, 'grid');
  const dimensionality = integerAt(grid.dimensionality, 'grid.dimensionality', 2);
  if (dimensionality !== 2 && dimensionality !== 3) {
    throw new VolumeSceneValidationError('expected 2 or 3', 'grid.dimensionality');
  }
  const dimensions = vectorAt(grid.dimensions, 'grid.dimensions');
  dimensions.forEach((entry, index) => {
    if (!Number.isSafeInteger(entry) || entry < 1) {
      throw new VolumeSceneValidationError(
        'expected a positive safe integer',
        `grid.dimensions[${index}]`,
      );
    }
  });
  const rows = arrayAt(grid.voxelVectors, 'grid.voxelVectors');
  if (rows.length !== 3) {
    throw new VolumeSceneValidationError('expected three rows', 'grid.voxelVectors');
  }
  const voxelVectors = rows.map((row, index) =>
    vectorAt(row, `grid.voxelVectors[${index}]`),
  ) as VolumeGridSpec['voxelVectors'];
  if (dimensionality === 3 && Math.abs(determinant(voxelVectors)) < 1e-14) {
    throw new VolumeSceneValidationError('matrix is singular', 'grid.voxelVectors');
  }
  if (dimensionality === 2) {
    const [a, b] = voxelVectors;
    const cross = [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
    if (Math.hypot(...cross) < 1e-14) {
      throw new VolumeSceneValidationError('first two vectors are collinear', 'grid.voxelVectors');
    }
  }
  const periodicInput = arrayAt(grid.periodic, 'grid.periodic');
  if (periodicInput.length !== 3) {
    throw new VolumeSceneValidationError('expected three entries', 'grid.periodic');
  }
  const periodic = periodicInput.map((entry, index) =>
    booleanAt(entry, `grid.periodic[${index}]`),
  ) as [boolean, boolean, boolean];
  const sampling = stringAt(grid.sampling, 'grid.sampling');
  if (sampling !== 'cell-periodic' && sampling !== 'point-inclusive') {
    throw new VolumeSceneValidationError('unsupported sampling convention', 'grid.sampling');
  }
  if (grid.indexOrder !== 'x-fastest') {
    throw new VolumeSceneValidationError('must be x-fastest', 'grid.indexOrder');
  }
  return {
    dimensionality,
    dimensions,
    origin: vectorAt(grid.origin, 'grid.origin'),
    voxelVectors,
    periodic,
    indexOrder: 'x-fastest',
    sampling,
  };
};

const parseChannel = (
  value: unknown,
  index: number,
  elementCount: number,
): VolumeChannelSpec => {
  const path = `channels[${index}]`;
  const channel = objectAt(value, path);
  const transport = objectAt(channel.transport, `${path}.transport`);
  const encoding = stringAt(
    transport.valueEncoding,
    `${path}.transport.valueEncoding`,
  ) as VolumeValueEncoding;
  if (
    encoding !== 'float32-le' &&
    encoding !== 'float64-le' &&
    encoding !== 'uint16-linear-le'
  ) {
    throw new VolumeSceneValidationError(
      'unsupported value encoding',
      `${path}.transport.valueEncoding`,
    );
  }
  const bytesPerElement =
    encoding === 'float32-le' ? 4 : encoding === 'float64-le' ? 8 : 2;
  if (integerAt(transport.elementCount, `${path}.transport.elementCount`) !== elementCount) {
    throw new VolumeSceneValidationError(
      'does not match grid dimensions',
      `${path}.transport.elementCount`,
    );
  }
  if (
    integerAt(transport.byteLength, `${path}.transport.byteLength`) !==
    elementCount * bytesPerElement
  ) {
    throw new VolumeSceneValidationError(
      'does not match encoding and dimensions',
      `${path}.transport.byteLength`,
    );
  }
  const checksum = integerAt(transport.crc32, `${path}.transport.crc32`);
  if (checksum > 0xffffffff) {
    throw new VolumeSceneValidationError(
      'must be an unsigned 32-bit integer',
      `${path}.transport.crc32`,
    );
  }
  const minimum = finiteAt(channel.minimum, `${path}.minimum`);
  const maximum = finiteAt(channel.maximum, `${path}.maximum`);
  if (minimum > maximum) {
    throw new VolumeSceneValidationError('cannot exceed maximum', `${path}.minimum`);
  }
  const scale =
    encoding === 'uint16-linear-le'
      ? finiteAt(transport.scale, `${path}.transport.scale`)
      : undefined;
  const offset =
    encoding === 'uint16-linear-le'
      ? finiteAt(transport.offset, `${path}.transport.offset`)
      : undefined;
  if (scale !== undefined && scale <= 0) {
    throw new VolumeSceneValidationError(
      'must be positive for uint16 linear encoding',
      `${path}.transport.scale`,
    );
  }
  return {
    id: stringAt(channel.id, `${path}.id`),
    label: stringAt(channel.label, `${path}.label`),
    units: stringAt(channel.units, `${path}.units`),
    signed: booleanAt(channel.signed, `${path}.signed`),
    minimum,
    maximum,
    mean: finiteAt(channel.mean, `${path}.mean`),
    standardDeviation: finiteAt(channel.standardDeviation, `${path}.standardDeviation`),
    integral:
      channel.integral === null || channel.integral === undefined
        ? null
        : finiteAt(channel.integral, `${path}.integral`),
    transport: {
      transferId: stringAt(transport.transferId, `${path}.transport.transferId`),
      valueEncoding: encoding,
      elementCount,
      byteLength: elementCount * bytesPerElement,
      crc32: checksum,
      ...(scale === undefined ? {} : { scale }),
      ...(offset === undefined ? {} : { offset }),
    },
  };
};

export const validateVolumeScene = (value: unknown): VolumeSceneSpec => {
  const scene = objectAt(value, 'scene');
  if (scene.schemaVersion !== '1.0') {
    throw new VolumeSceneValidationError('unsupported schema version', 'schemaVersion');
  }
  if (scene.kind !== 'volume') {
    throw new VolumeSceneValidationError('expected volume', 'kind');
  }
  const requestId = stringAt(scene.requestId, 'requestId');
  if (!requestId) throw new VolumeSceneValidationError('cannot be empty', 'requestId');
  const source = objectAt(scene.source, 'source');
  const format = stringAt(source.format, 'source.format');
  if (!['chgcar', 'cube', 'xsf'].includes(format)) {
    throw new VolumeSceneValidationError('unsupported source format', 'source.format');
  }
  const grid = parseGrid(scene.grid);
  const elementCount = grid.dimensions.reduce((product, value) => product * value, 1);
  if (!Number.isSafeInteger(elementCount)) {
    throw new VolumeSceneValidationError('dimension product overflows', 'grid.dimensions');
  }
  if (elementCount > 256 ** 3) {
    throw new VolumeSceneValidationError('voxel count exceeds safety limit', 'grid.dimensions');
  }
  const channels = arrayAt(scene.channels, 'channels').map((channel, index) =>
    parseChannel(channel, index, elementCount),
  );
  if (channels.length === 0) {
    throw new VolumeSceneValidationError('requires at least one channel', 'channels');
  }
  if (channels.length > 64) {
    throw new VolumeSceneValidationError('channel count exceeds safety limit', 'channels');
  }
  const totalBytes = channels.reduce(
    (sum, channel) => sum + channel.transport.byteLength,
    0,
  );
  if (!Number.isSafeInteger(totalBytes) || totalBytes > 384 * 1024 * 1024) {
    throw new VolumeSceneValidationError(
      'total channel transport exceeds 384 MiB safety limit',
      'channels',
    );
  }
  const ids = new Set(channels.map((channel) => channel.id));
  const transfers = new Set(channels.map((channel) => channel.transport.transferId));
  if (ids.size !== channels.length || transfers.size !== channels.length) {
    throw new VolumeSceneValidationError(
      'channel and transfer identifiers must be unique',
      'channels',
    );
  }
  const transport = objectAt(scene.transport, 'transport');
  if (transport.protocol !== 'chunked-binary') {
    throw new VolumeSceneValidationError('unsupported protocol', 'transport.protocol');
  }
  const chunkBytes = integerAt(transport.chunkBytes, 'transport.chunkBytes', 1);
  if (chunkBytes > 16 * 1024 * 1024) {
    throw new VolumeSceneValidationError('chunk size exceeds safety limit', 'transport.chunkBytes');
  }
  const warnings = arrayAt(scene.warnings, 'warnings').map((value, index) => {
    const warning = objectAt(value, `warnings[${index}]`);
    const severity = stringAt(warning.severity, `warnings[${index}].severity`);
    if (!['info', 'warning', 'error'].includes(severity)) {
      throw new VolumeSceneValidationError(
        'unsupported severity',
        `warnings[${index}].severity`,
      );
    }
    return {
      code: stringAt(warning.code, `warnings[${index}].code`),
      message: stringAt(warning.message, `warnings[${index}].message`),
      severity: severity as 'info' | 'warning' | 'error',
    };
  });
  const atomicOverlay =
    scene.atomicOverlay === null || scene.atomicOverlay === undefined
      ? null
      : validateScene(scene.atomicOverlay);
  let structure: VolumeSceneSpec['structure'];
  if (scene.structure !== undefined) {
    const input = objectAt(scene.structure, 'structure');
    structure = {
      formula: stringAt(input.formula, 'structure.formula'),
      numSites: integerAt(input.numSites, 'structure.numSites'),
    };
  }
  return {
    schemaVersion: '1.0',
    kind: 'volume',
    requestId,
    source: {
      format: format as VolumeSceneSpec['source']['format'],
      name: stringAt(source.name, 'source.name'),
      normalization: stringAt(source.normalization, 'source.normalization'),
      ...(source.dataset === undefined
        ? {}
        : { dataset: stringAt(source.dataset, 'source.dataset') }),
    },
    grid,
    channels,
    warnings,
    ...(structure === undefined ? {} : { structure }),
    atomicOverlay,
    transport: { protocol: 'chunked-binary', chunkBytes },
  };
};
import { validateScene } from '@kssolv/atomic-scene';
