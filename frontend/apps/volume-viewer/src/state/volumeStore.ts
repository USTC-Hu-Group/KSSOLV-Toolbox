import { computed, reactive, shallowRef } from 'vue';

import { matlabBridge } from '@kssolv/matlab-bridge';
import {
  validateVolumeScene,
  VolumeTransferAssembler,
  type VolumeChunk,
  type VolumeSceneSpec,
} from '@kssolv/volume-scene';

export type VolumeMode = 'isosurface' | 'slices' | 'volume';
export type SliceAxis = 'i' | 'j' | 'k';
export type IsovalueMode = 'absolute' | 'sigma' | 'percentile';
export type VolumeStatusPhase =
  | 'idle'
  | 'receiving'
  | 'decoding'
  | 'building'
  | 'ready'
  | 'cancelled'
  | 'error';

export interface VolumeOptions {
  mode: VolumeMode;
  isovalueMode: IsovalueMode;
  channelId: string;
  positiveThreshold: number;
  negativeThreshold: number;
  showPositive: boolean;
  showNegative: boolean;
  smoothIsosurface: boolean;
  periodicWrap: boolean;
  opacity: number;
  colormap: 'viridis' | 'coolwarm' | 'density';
  rangeMinimum: number;
  rangeMaximum: number;
  sliceAxis: SliceAxis;
  sliceIndex: number;
  interpolation: 'nearest' | 'linear';
  volumeQuality: 'fast' | 'balanced' | 'high';
  gradientOpacity: number;
  clipMinimum: [number, number, number];
  clipMaximum: [number, number, number];
  pngScale: 1 | 1.5 | 2;
  showAtoms: boolean;
  showBonds: boolean;
  showCell: boolean;
  showPolyhedra: boolean;
  showAxes: boolean;
}

const scene = shallowRef<VolumeSceneSpec>();
const buffers = shallowRef(new Map<string, ArrayBuffer>());
const assembler = new VolumeTransferAssembler();
const options = reactive<VolumeOptions>({
  mode: 'isosurface',
  isovalueMode: 'absolute',
  channelId: '',
  positiveThreshold: 0.12,
  negativeThreshold: -0.12,
  showPositive: true,
  showNegative: true,
  smoothIsosurface: true,
  periodicWrap: true,
  opacity: 0.72,
  colormap: 'coolwarm',
  rangeMinimum: -1,
  rangeMaximum: 1,
  sliceAxis: 'k',
  sliceIndex: 0,
  interpolation: 'linear',
  volumeQuality: 'balanced',
  gradientOpacity: 0.35,
  clipMinimum: [0, 0, 0],
  clipMaximum: [1, 1, 1],
  pngScale: 1.5,
  showAtoms: true,
  showBonds: true,
  showCell: true,
  showPolyhedra: true,
  showAxes: true,
});
const status = reactive({
  phase: 'idle' as VolumeStatusPhase,
  message: '',
  progress: null as number | null,
});

let bridgeInitialized = false;
let transferTimeout: number | undefined;
let completionTimeout: number | undefined;
let loadedRequestId = '';
let senderCompletedRequestId = '';
const clearTransferTimeout = (): void => {
  if (transferTimeout !== undefined) window.clearTimeout(transferTimeout);
  transferTimeout = undefined;
};
const clearCompletionTimeout = (): void => {
  if (completionTimeout !== undefined) window.clearTimeout(completionTimeout);
  completionTimeout = undefined;
};
const completeTransferIfReady = (requestId: string): boolean => {
  if (
    requestId !== scene.value?.requestId ||
    assembler.pendingCount !== 0 ||
    buffers.value.size !== scene.value.channels.length
  ) {
    return false;
  }
  clearTransferTimeout();
  clearCompletionTimeout();
  assembler.cancel(requestId);
  // A fully assembled final chunk is not the end of the transport. Wait for
  // MATLAB's explicit complete event before acknowledging the loaded stage so
  // its one-chunk-at-a-time sender cannot advance or clear state out of order.
  if (senderCompletedRequestId !== requestId) return false;
  if (loadedRequestId !== requestId) {
    loadedRequestId = requestId;
    matlabBridge.emit('volume:loaded', {
      requestId,
      channelCount: scene.value.channels.length,
      transferId: scene.value.channels[0].transport.transferId,
    });
  }
  if (status.phase === 'receiving' || status.phase === 'decoding') {
    status.phase = 'ready';
    status.message = '';
    status.progress = 1;
  }
  return true;
};
const failTransfer = (requestId: string, message: string): void => {
  clearTransferTimeout();
  clearCompletionTimeout();
  assembler.cancel(requestId || undefined);
  senderCompletedRequestId = '';
  status.phase = 'error';
  status.message = message;
  status.progress = null;
  matlabBridge.emit('volume:client-error', { requestId, message });
};
const receiveManifest = (payload: unknown): void => {
  try {
    const next = validateVolumeScene(
      typeof payload === 'string' ? (JSON.parse(payload) as unknown) : payload,
    );
    scene.value = next;
    clearTransferTimeout();
    clearCompletionTimeout();
    loadedRequestId = '';
    senderCompletedRequestId = '';
    buffers.value = new Map();
    options.channelId = next.channels[0].id;
    options.positiveThreshold = Math.max(0, next.channels[0].maximum * 0.2);
    options.negativeThreshold = Math.min(0, next.channels[0].minimum * 0.2);
    options.rangeMinimum = next.channels[0].minimum;
    options.rangeMaximum = next.channels[0].maximum;
    if (next.grid.dimensionality === 2) options.mode = 'slices';
    options.sliceIndex = Math.floor(next.grid.dimensions[2] / 2);
    assembler.beginRequest(
      next.requestId,
      next.channels.map((channel) => channel.transport),
    );
    status.phase = 'receiving';
    status.message = 'Receiving voxel data… 0%';
    status.progress = 0;
    matlabBridge.emit('volume:manifest-ack', {
      requestId: next.requestId,
      transferId: next.channels[0].transport.transferId,
    });
    transferTimeout = window.setTimeout(() => {
      failTransfer(
        next.requestId,
        'Volume transfer timed out after 30 seconds.',
      );
      matlabBridge.emit('volume:cancel', { requestId: next.requestId });
    }, 30_000);
  } catch (error) {
    failTransfer(
      '',
      error instanceof Error ? error.message : String(error),
    );
  }
};
const initializeBridge = (): void => {
  if (bridgeInitialized) return;
  bridgeInitialized = true;
  matlabBridge.on('volume:begin', (payload) => {
    const requestId =
      typeof payload === 'object' && payload && 'requestId' in payload
        ? String(payload.requestId)
        : '';
    if (!requestId) {
      status.phase = 'error';
      status.message = 'Volume transfer begin event is missing requestId.';
      status.progress = null;
      return;
    }
    clearTransferTimeout();
    clearCompletionTimeout();
    assembler.cancel();
    buffers.value = new Map();
    loadedRequestId = '';
    senderCompletedRequestId = '';
    status.phase = 'receiving';
    status.message = 'Preparing volume transfer…';
    status.progress = 0;
  });
  matlabBridge.on('volume:manifest', receiveManifest);
  // Compatibility with development runtimes produced before protocol 1.0
  // froze the manifest event name.
  matlabBridge.on('volume:scene', receiveManifest);
  matlabBridge.on('volume:chunk', (payload) => {
    try {
      const receivedBytes = assembler.receivedBytes;
      const complete = assembler.accept(payload as VolumeChunk);
      // Ignore duplicate or late chunks after a transfer has completed. Without
      // this guard they can overwrite a newer decoding/ready status with a
      // permanent "Receiving… 100%" message.
      if (!complete && assembler.receivedBytes === receivedBytes) return;
      const chunk = payload as VolumeChunk;
      matlabBridge.emit('volume:chunk-ack', {
        requestId: chunk.requestId,
        transferId: chunk.transferId,
        chunkIndex: chunk.chunkIndex,
      });
      status.progress = assembler.progress;
      status.phase = 'receiving';
      status.message = `Receiving voxel data… ${Math.round(assembler.progress * 100)}%`;
      if (!complete) return;
      const next = new Map(buffers.value);
      next.set(complete.transferId, complete.bytes);
      buffers.value = next;
      status.progress = 1;
      if (assembler.pendingCount === 0) {
        status.phase = 'decoding';
        status.message = 'Decoding voxel data…';
      } else {
        status.phase = 'receiving';
        status.message = `Receiving voxel data… ${Math.round(assembler.progress * 100)}%`;
      }
      completeTransferIfReady(complete.requestId);
    } catch (error) {
      failTransfer(
        scene.value?.requestId ?? '',
        error instanceof Error ? error.message : String(error),
      );
    }
  });
  matlabBridge.on('volume:complete', (payload) => {
    const requestId =
      typeof payload === 'object' && payload && 'requestId' in payload
        ? String(payload.requestId)
        : '';
    if (!requestId || requestId !== scene.value?.requestId) return;
    senderCompletedRequestId = requestId;
    if (completeTransferIfReady(requestId)) return;
    clearCompletionTimeout();
    status.phase = 'receiving';
    status.message = `Finalizing volume transfer… ${buffers.value.size}/${scene.value.channels.length} channels`;
    completionTimeout = window.setTimeout(() => {
      if (completeTransferIfReady(requestId)) return;
      failTransfer(
        requestId,
        `Volume transfer ${requestId} completed with missing channel data.`,
      );
    }, 5_000);
  });
  matlabBridge.on('volume:cancel', (payload) => {
    const requestId =
      typeof payload === 'object' && payload && 'requestId' in payload
        ? String(payload.requestId)
        : '';
    if (requestId && requestId !== scene.value?.requestId) return;
    clearTransferTimeout();
    clearCompletionTimeout();
    assembler.cancel(requestId || undefined);
    senderCompletedRequestId = '';
    status.phase = 'cancelled';
    status.message = 'Volume loading cancelled';
    status.progress = null;
  });
  matlabBridge.on('volume:error', (payload) => {
    const message =
      typeof payload === 'object' && payload && 'message' in payload
        ? String(payload.message)
        : String(payload);
    failTransfer(scene.value?.requestId ?? '', message);
  });
};

export const useVolumeStore = () => {
  initializeBridge();
  const activeChannel = computed(() =>
    scene.value?.channels.find((channel) => channel.id === options.channelId),
  );
  const activeBuffer = computed(() => {
    const transferId = activeChannel.value?.transport.transferId;
    return transferId ? buffers.value.get(transferId) : undefined;
  });
  return {
    scene,
    buffers,
    options,
    status,
    activeChannel,
    activeBuffer,
    setScene(next: VolumeSceneSpec): void {
      scene.value = validateVolumeScene(next);
      options.channelId = next.channels[0].id;
      options.positiveThreshold = Math.max(0, next.channels[0].maximum * 0.2);
      options.negativeThreshold = Math.min(0, next.channels[0].minimum * 0.2);
      options.rangeMinimum = next.channels[0].minimum;
      options.rangeMaximum = next.channels[0].maximum;
      if (next.grid.dimensionality === 2) options.mode = 'slices';
      options.sliceIndex = Math.floor(next.grid.dimensions[2] / 2);
    },
    setChannelBytes(transferId: string, value: ArrayBuffer): void {
      const next = new Map(buffers.value);
      next.set(transferId, value);
      buffers.value = next;
      status.phase = 'ready';
      status.message = 'Volume ready';
      status.progress = 1;
    },
  };
};
