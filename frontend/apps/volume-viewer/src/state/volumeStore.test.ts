import { describe, expect, it } from 'vitest';

import { matlabBridge } from '@kssolv/matlab-bridge';
import { crc32, type VolumeChunk, type VolumeSceneSpec } from '@kssolv/volume-scene';

import { useVolumeStore } from './volumeStore';

const fixture = (requestId: string): {
  scene: VolumeSceneSpec;
  bytes: Uint8Array;
} => {
  const values = new Float32Array([1, -2]);
  const bytes = new Uint8Array(values.buffer.slice(0));
  const transferId = `${requestId}:rho`;
  return {
    bytes,
    scene: {
      schemaVersion: '1.0',
      kind: 'volume',
      requestId,
      source: {
        format: 'cube',
        name: 'state fixture',
        normalization: 'source-values',
      },
      grid: {
        dimensionality: 3,
        dimensions: [2, 1, 1],
        origin: [0, 0, 0],
        voxelVectors: [
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1],
        ],
        periodic: [false, false, false],
        indexOrder: 'x-fastest',
        sampling: 'point-inclusive',
      },
      channels: [
        {
          id: 'rho',
          label: 'Density',
          units: 'arbitrary',
          signed: true,
          minimum: -2,
          maximum: 1,
          mean: -0.5,
          standardDeviation: 1.5,
          integral: null,
          transport: {
            transferId,
            valueEncoding: 'float32-le',
            elementCount: 2,
            byteLength: bytes.byteLength,
            crc32: crc32(bytes),
          },
        },
      ],
      warnings: [],
      atomicOverlay: null,
      transport: {
        protocol: 'chunked-binary',
        chunkBytes: 512 * 1024,
      },
    },
  };
};

const chunk = (
  requestId: string,
  transferId: string,
  bytes: Uint8Array,
): VolumeChunk => ({
  requestId,
  transferId,
  chunkIndex: 0,
  chunkCount: 1,
  byteOffset: 0,
  data: btoa(String.fromCharCode(...bytes)),
  crc32: crc32(bytes),
});

describe('volume bridge state machine', () => {
  it('accepts normal delivery and tolerates complete before the final chunk', () => {
    const store = useVolumeStore();
    const first = fixture('request-state-1');

    matlabBridge.dispatchForTesting('volume:begin', {
      requestId: first.scene.requestId,
      transferCount: 1,
      totalBytes: first.bytes.byteLength,
    });
    expect(store.status.phase).toBe('receiving');
    expect(store.status.progress).toBe(0);

    matlabBridge.dispatchForTesting('volume:manifest', JSON.stringify(first.scene));
    expect(store.status.message).toContain('0%');

    matlabBridge.dispatchForTesting(
      'volume:chunk',
      chunk(
        first.scene.requestId,
        first.scene.channels[0].transport.transferId,
        first.bytes,
      ),
    );
    expect(store.status.phase).toBe('decoding');
    expect(store.activeBuffer.value).toBeInstanceOf(ArrayBuffer);

    // The renderer may finish synchronously after the final buffer becomes
    // reactive but before MATLAB's explicit complete event arrives.
    store.status.phase = 'ready';
    store.status.message = 'Isosurface ready';
    matlabBridge.dispatchForTesting('volume:complete', {
      requestId: first.scene.requestId,
      transferCount: 1,
    });
    expect(store.status.phase).toBe('ready');
    expect(store.status.message).toBe('Isosurface ready');

    matlabBridge.dispatchForTesting(
      'volume:chunk',
      chunk(
        first.scene.requestId,
        first.scene.channels[0].transport.transferId,
        first.bytes,
      ),
    );
    expect(store.status.phase).toBe('ready');
    expect(store.status.message).not.toContain('Receiving voxel data');

    const second = fixture('request-state-2');
    matlabBridge.dispatchForTesting('volume:begin', {
      requestId: second.scene.requestId,
      transferCount: 1,
      totalBytes: second.bytes.byteLength,
    });
    matlabBridge.dispatchForTesting('volume:manifest', second.scene);
    matlabBridge.dispatchForTesting('volume:complete', {
      requestId: second.scene.requestId,
      transferCount: 1,
    });
    expect(store.status.phase).toBe('receiving');
    expect(store.status.message).toContain('Finalizing volume transfer');
    matlabBridge.dispatchForTesting(
      'volume:chunk',
      chunk(
        second.scene.requestId,
        second.scene.channels[0].transport.transferId,
        second.bytes,
      ),
    );
    expect(store.status.phase).toBe('ready');
    expect(store.status.message).toBe('');
    expect(store.status.message).not.toContain('missing channel data');
  });

  it('replaces a same-request LOD preview with full-resolution data', () => {
    const store = useVolumeStore();
    const preview = fixture('request-progressive');
    const send = (item: ReturnType<typeof fixture>): void => {
      matlabBridge.dispatchForTesting('volume:begin', {
        requestId: item.scene.requestId,
        transferCount: 1,
        totalBytes: item.bytes.byteLength,
      });
      matlabBridge.dispatchForTesting('volume:manifest', item.scene);
      matlabBridge.dispatchForTesting(
        'volume:chunk',
        chunk(
          item.scene.requestId,
          item.scene.channels[0].transport.transferId,
          item.bytes,
        ),
      );
      matlabBridge.dispatchForTesting('volume:complete', {
        requestId: item.scene.requestId,
        transferCount: 1,
      });
    };
    send(preview);
    expect(store.scene.value?.grid.dimensions).toEqual([2, 1, 1]);

    const fullValues = new Float32Array([1, -2, 3, -4]);
    const fullBytes = new Uint8Array(fullValues.buffer.slice(0));
    const full: ReturnType<typeof fixture> = {
      scene: structuredClone(preview.scene),
      bytes: fullBytes,
    };
    full.scene.grid.dimensions = [4, 1, 1];
    full.scene.channels[0].transport = {
      ...full.scene.channels[0].transport,
      elementCount: 4,
      byteLength: fullBytes.byteLength,
      crc32: crc32(fullBytes),
    };
    send(full);
    expect(store.scene.value?.requestId).toBe('request-progressive');
    expect(store.scene.value?.grid.dimensions).toEqual([4, 1, 1]);
    expect(store.activeBuffer.value?.byteLength).toBe(16);
    expect(store.status.phase).toBe('ready');
    expect(store.status.message).toBe('');
  });

  it('clears the decoding status after every channel in a multichannel volume arrives', () => {
    const store = useVolumeStore();
    const first = fixture('request-multichannel');
    const secondValues = new Float32Array([-3, 4]);
    const secondBytes = new Uint8Array(secondValues.buffer.slice(0));
    const secondChannel = structuredClone(first.scene.channels[0]);
    secondChannel.id = 'difference';
    secondChannel.label = 'Difference';
    secondChannel.transport = {
      ...secondChannel.transport,
      transferId: 'request-multichannel:difference',
      crc32: crc32(secondBytes),
    };
    first.scene.channels.push(secondChannel);

    matlabBridge.dispatchForTesting('volume:begin', {
      requestId: first.scene.requestId,
      transferCount: 2,
      totalBytes: first.bytes.byteLength + secondBytes.byteLength,
    });
    matlabBridge.dispatchForTesting('volume:manifest', first.scene);
    matlabBridge.dispatchForTesting(
      'volume:chunk',
      chunk(
        first.scene.requestId,
        first.scene.channels[0].transport.transferId,
        first.bytes,
      ),
    );
    expect(store.status.phase).toBe('receiving');
    expect(store.status.message).toContain('50%');

    matlabBridge.dispatchForTesting(
      'volume:chunk',
      chunk(
        first.scene.requestId,
        secondChannel.transport.transferId,
        secondBytes,
      ),
    );
    expect(store.status.phase).toBe('decoding');

    matlabBridge.dispatchForTesting('volume:complete', {
      requestId: first.scene.requestId,
      transferCount: 2,
    });
    expect(store.buffers.value.size).toBe(2);
    expect(store.status.phase).toBe('ready');
    expect(store.status.message).toBe('');
    expect(store.status.progress).toBe(1);
  });
});
