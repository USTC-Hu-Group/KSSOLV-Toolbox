import { crc32 } from './crc32';
import type { VolumeChannelTransport, VolumeChunk, VolumeTransferComplete } from './types';

interface ActiveTransfer {
  requestId: string;
  descriptor: VolumeChannelTransport;
  bytes: Uint8Array;
  received: Set<number>;
  ranges: Map<number, [number, number]>;
  chunkCrcs: Map<number, number>;
  chunkCount?: number;
}

const decodeBase64 = (value: string): Uint8Array => {
  const decoded = atob(value);
  const bytes = new Uint8Array(decoded.length);
  for (let index = 0; index < decoded.length; index += 1) {
    bytes[index] = decoded.charCodeAt(index);
  }
  return bytes;
};

export class VolumeTransferAssembler {
  private readonly active = new Map<string, ActiveTransfer>();
  private currentRequestId = '';
  private requestTotalBytes = 0;
  private requestReceivedBytes = 0;

  beginRequest(requestId: string, channels: VolumeChannelTransport[]): void {
    this.cancel();
    this.currentRequestId = requestId;
    this.requestTotalBytes = channels.reduce(
      (total, descriptor) => total + descriptor.byteLength,
      0,
    );
    for (const descriptor of channels) {
      this.active.set(descriptor.transferId, {
        requestId,
        descriptor,
        bytes: new Uint8Array(descriptor.byteLength),
        received: new Set(),
        ranges: new Map(),
        chunkCrcs: new Map(),
      });
    }
  }

  accept(chunk: VolumeChunk): VolumeTransferComplete | undefined {
    if (chunk.requestId !== this.currentRequestId) return undefined;
    const transfer = this.active.get(chunk.transferId);
    if (!transfer || transfer.requestId !== chunk.requestId) return undefined;
    if (
      !Number.isSafeInteger(chunk.chunkIndex) ||
      !Number.isSafeInteger(chunk.chunkCount) ||
      !Number.isSafeInteger(chunk.byteOffset) ||
      chunk.chunkIndex < 0 ||
      chunk.chunkIndex >= chunk.chunkCount ||
      chunk.byteOffset < 0
    ) {
      throw new Error('Invalid volume chunk coordinates.');
    }
    const bytes = decodeBase64(chunk.data);
    if (bytes.byteLength > 16 * 1024 * 1024) {
      throw new Error('Volume chunk exceeds the client safety limit.');
    }
    if (crc32(bytes) !== chunk.crc32 >>> 0) throw new Error('Volume chunk CRC32 mismatch.');
    if (chunk.byteOffset + bytes.byteLength > transfer.bytes.byteLength) {
      throw new Error('Volume chunk exceeds the declared byte length.');
    }
    if (transfer.chunkCount !== undefined && transfer.chunkCount !== chunk.chunkCount) {
      throw new Error('Volume chunk count changed during transfer.');
    }
    transfer.chunkCount = chunk.chunkCount;
    const range: [number, number] = [chunk.byteOffset, chunk.byteOffset + bytes.byteLength];
    const previousRange = transfer.ranges.get(chunk.chunkIndex);
    if (
      previousRange &&
      (previousRange[0] !== range[0] || previousRange[1] !== range[1])
    ) {
      throw new Error('Duplicate volume chunk changed its declared byte range.');
    }
    const previousCrc = transfer.chunkCrcs.get(chunk.chunkIndex);
    if (previousCrc !== undefined && previousCrc !== (chunk.crc32 >>> 0)) {
      throw new Error('Duplicate volume chunk changed its payload.');
    }
    if (!transfer.received.has(chunk.chunkIndex)) {
      transfer.bytes.set(bytes, chunk.byteOffset);
      transfer.received.add(chunk.chunkIndex);
      transfer.ranges.set(chunk.chunkIndex, range);
      transfer.chunkCrcs.set(chunk.chunkIndex, chunk.crc32 >>> 0);
      this.requestReceivedBytes += bytes.byteLength;
    }
    if (transfer.received.size !== chunk.chunkCount) return undefined;
    const orderedRanges = [...transfer.ranges.values()].sort(
      (first, second) => first[0] - second[0],
    );
    let cursor = 0;
    for (const [start, end] of orderedRanges) {
      if (start !== cursor) {
        throw new Error('Volume chunks contain a gap or overlapping byte range.');
      }
      cursor = end;
    }
    if (cursor !== transfer.bytes.byteLength) {
      throw new Error('Volume chunks do not cover the declared byte length.');
    }
    if (crc32(transfer.bytes) !== transfer.descriptor.crc32 >>> 0) {
      throw new Error('Completed volume transfer CRC32 mismatch.');
    }
    this.active.delete(chunk.transferId);
    return {
      requestId: chunk.requestId,
      transferId: chunk.transferId,
      bytes: transfer.bytes.slice().buffer as ArrayBuffer,
    };
  }

  cancel(requestId?: string): void {
    if (requestId && requestId !== this.currentRequestId) return;
    this.active.clear();
    this.currentRequestId = '';
    this.requestTotalBytes = 0;
    this.requestReceivedBytes = 0;
  }

  get pendingCount(): number {
    return this.active.size;
  }

  get receivedBytes(): number {
    return this.requestReceivedBytes;
  }

  get totalBytes(): number {
    return this.requestTotalBytes;
  }

  get progress(): number {
    if (this.requestTotalBytes === 0) return this.pendingCount === 0 ? 1 : 0;
    return Math.min(1, this.requestReceivedBytes / this.requestTotalBytes);
  }
}
