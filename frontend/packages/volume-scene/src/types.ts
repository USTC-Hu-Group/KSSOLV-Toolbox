import type { AtomicSceneSpec, Matrix3Tuple, SceneWarning, Vector3Tuple } from '@kssolv/atomic-scene';

export type VolumeSampling = 'cell-periodic' | 'point-inclusive';
export type VolumeValueEncoding =
  | 'float32-le'
  | 'float64-le'
  | 'uint16-linear-le';

export interface VolumeGridSpec {
  dimensionality: 2 | 3;
  dimensions: Vector3Tuple;
  origin: Vector3Tuple;
  voxelVectors: Matrix3Tuple;
  periodic: [boolean, boolean, boolean];
  indexOrder: 'x-fastest';
  sampling: VolumeSampling;
}

export interface VolumeChannelTransport {
  transferId: string;
  valueEncoding: VolumeValueEncoding;
  elementCount: number;
  byteLength: number;
  crc32: number;
  scale?: number;
  offset?: number;
}

export interface VolumeChannelSpec {
  id: string;
  label: string;
  units: string;
  signed: boolean;
  minimum: number;
  maximum: number;
  mean: number;
  standardDeviation: number;
  integral: number | null;
  transport: VolumeChannelTransport;
}

export interface VolumeSceneSpec {
  schemaVersion: '1.0';
  kind: 'volume';
  requestId: string;
  source: {
    format: 'chgcar' | 'cube' | 'xsf';
    name: string;
    normalization: string;
    dataset?: string;
  };
  grid: VolumeGridSpec;
  channels: VolumeChannelSpec[];
  warnings: SceneWarning[];
  structure?: {
    formula: string;
    numSites: number;
  };
  atomicOverlay: AtomicSceneSpec | null;
  transport: {
    protocol: 'chunked-binary';
    chunkBytes: number;
  };
}

export interface VolumeChunk {
  requestId: string;
  transferId: string;
  chunkIndex: number;
  chunkCount: number;
  byteOffset: number;
  data: string;
  crc32: number;
}

export interface VolumeTransferComplete {
  requestId: string;
  transferId: string;
  bytes: ArrayBuffer;
}
