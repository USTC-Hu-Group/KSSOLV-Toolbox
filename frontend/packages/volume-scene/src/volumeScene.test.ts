import { describe, expect, it } from 'vitest';

import { crc32, validateVolumeScene, VolumeTransferAssembler } from './index';
import type { VolumeChunk, VolumeSceneSpec } from './types';

const assembledFixture = Uint8Array.from({ length: 32 }, (_, index) => index);

const manifest = (): VolumeSceneSpec => ({
  schemaVersion: '1.0',
  kind: 'volume',
  requestId: 'request-1',
  source: {
    format: 'xsf',
    name: 'density',
    normalization: 'source-values',
    dataset: 'density_3d',
  },
  grid: {
    dimensionality: 3,
    dimensions: [2, 2, 2],
    origin: [0, 0, 0],
    voxelVectors: [
      [2, 0, 0],
      [0.25, 2, 0],
      [0, 0.5, 2],
    ],
    periodic: [true, true, true],
    indexOrder: 'x-fastest',
    sampling: 'point-inclusive',
  },
  channels: [
    {
      id: 'density',
      label: 'Density',
      units: 'arbitrary',
      signed: false,
      minimum: 0,
      maximum: 7,
      mean: 3.5,
      standardDeviation: 2.449,
      integral: null,
      transport: {
        transferId: 'request-1:density',
        valueEncoding: 'float32-le',
        elementCount: 8,
        byteLength: 32,
        crc32: crc32(assembledFixture),
      },
    },
  ],
  warnings: [],
  atomicOverlay: null,
  transport: {
    protocol: 'chunked-binary',
    chunkBytes: 16,
  },
});

describe('VolumeSceneSpec 1.0', () => {
  it('validates a skew-grid manifest without voxel JSON', () => {
    const result = validateVolumeScene(manifest());
    expect(result.grid.voxelVectors[1]).toEqual([0.25, 2, 0]);
    expect(JSON.stringify(result)).not.toContain('"values"');
  });

  it('validates uint16 linear transport only with explicit scale and offset', () => {
    const value = manifest();
    value.channels[0].transport = {
      transferId: 'request-1:density',
      valueEncoding: 'uint16-linear-le',
      elementCount: 8,
      byteLength: 16,
      crc32: 0,
      scale: 7 / 65535,
      offset: 0,
    };
    expect(validateVolumeScene(value).channels[0].transport.scale).toBeGreaterThan(0);
    delete value.channels[0].transport.scale;
    expect(() => validateVolumeScene(value)).toThrow(/scale/);
  });

  it('rejects unsafe voxel and aggregate transport declarations before assembly', () => {
    const tooManyVoxels = manifest();
    tooManyVoxels.grid.dimensions = [257, 256, 256];
    expect(() => validateVolumeScene(tooManyVoxels)).toThrow(/voxel count/);

    const tooManyBytes = manifest();
    tooManyBytes.grid.dimensions = [256, 256, 256];
    const elements = 256 ** 3;
    tooManyBytes.channels = Array.from({ length: 7 }, (_, index) => ({
      ...tooManyBytes.channels[0],
      id: `channel-${index}`,
      transport: {
        ...tooManyBytes.channels[0].transport,
        transferId: `transfer-${index}`,
        elementCount: elements,
        byteLength: elements * 4,
      },
    }));
    expect(() => validateVolumeScene(tooManyBytes)).toThrow(/384 MiB/);
  });

  it.each([
    ['zero dimension', (value: VolumeSceneSpec) => (value.grid.dimensions[0] = 0)],
    [
      'singular transform',
      (value: VolumeSceneSpec) =>
        (value.grid.voxelVectors = [
          [1, 0, 0],
          [2, 0, 0],
          [0, 0, 1],
        ]),
    ],
    [
      'wrong byte length',
      (value: VolumeSceneSpec) => (value.channels[0].transport.byteLength = 28),
    ],
    [
      'duplicate channel id',
      (value: VolumeSceneSpec) => value.channels.push({ ...value.channels[0] }),
    ],
  ])('rejects %s', (_name, mutate) => {
    const value = manifest();
    mutate(value);
    expect(() => validateVolumeScene(value)).toThrow();
  });
});

describe('chunked binary transfer', () => {
  const base64 = (bytes: Uint8Array): string =>
    btoa(String.fromCharCode(...bytes));

  const chunk = (
    data: Uint8Array,
    chunkIndex: number,
    byteOffset: number,
  ): VolumeChunk => ({
    requestId: 'request-1',
    transferId: 'request-1:density',
    chunkIndex,
    chunkCount: 2,
    byteOffset,
    data: base64(data),
    crc32: crc32(data),
  });

  it('assembles out-of-order chunks and ignores duplicate delivery', () => {
    const assembler = new VolumeTransferAssembler();
    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    const second = Uint8Array.from({ length: 16 }, (_, index) => index + 16);
    const first = Uint8Array.from({ length: 16 }, (_, index) => index);

    expect(assembler.accept(chunk(second, 1, 16))).toBeUndefined();
    expect(assembler.progress).toBe(0.5);
    expect(assembler.receivedBytes).toBe(16);
    expect(assembler.totalBytes).toBe(32);
    expect(assembler.accept(chunk(second, 1, 16))).toBeUndefined();
    expect(assembler.progress).toBe(0.5);
    const complete = assembler.accept(chunk(first, 0, 0));

    expect(complete).toBeDefined();
    expect(Array.from(new Uint8Array(complete!.bytes))).toEqual(
      Array.from(assembledFixture),
    );
    expect(assembler.pendingCount).toBe(0);
    expect(assembler.progress).toBe(1);
  });

  it('drops stale requests and rejects corrupt chunks', () => {
    const assembler = new VolumeTransferAssembler();
    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    const data = new Uint8Array(16);
    const stale = { ...chunk(data, 0, 0), requestId: 'old-request' };
    expect(assembler.accept(stale)).toBeUndefined();
    expect(() => assembler.accept({ ...chunk(data, 0, 0), crc32: 7 })).toThrow(/CRC32/);
  });

  it('rejects overlapping, gapped, and mutated duplicate chunk ranges', () => {
    const assembler = new VolumeTransferAssembler();
    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    const data = new Uint8Array(16);
    assembler.accept(chunk(data, 0, 0));
    expect(() => assembler.accept(chunk(data, 1, 8))).toThrow(/gap or overlapping/);

    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    assembler.accept(chunk(data, 0, 0));
    expect(() => assembler.accept(chunk(data, 0, 1))).toThrow(/changed its declared byte range/);

    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    assembler.accept(chunk(data, 0, 0));
    expect(() =>
      assembler.accept(chunk(Uint8Array.from({ length: 16 }, () => 1), 0, 0)),
    ).toThrow(/changed its payload/);
  });

  it('rejects a complete buffer that passes every chunk CRC but not the manifest checksum', () => {
    const assembler = new VolumeTransferAssembler();
    assembler.beginRequest('request-1', [manifest().channels[0].transport]);
    const first = Uint8Array.from({ length: 16 }, (_, index) => index);
    const replacement = Uint8Array.from({ length: 16 }, (_, index) => 255 - index);
    assembler.accept(chunk(first, 0, 0));
    expect(() => assembler.accept(chunk(replacement, 1, 16))).toThrow(
      /Completed volume transfer CRC32 mismatch/,
    );
  });
});
