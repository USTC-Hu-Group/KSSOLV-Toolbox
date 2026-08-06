import type { ImageExportFormat } from './renderer/imageExport';

interface ImageSaveBridge {
  readonly connected: boolean;
  on(eventName: string, handler: (data: unknown) => void): () => void;
  emit(eventName: string, data?: unknown): void;
}

interface WritableFileLike {
  write(data: Blob): Promise<void>;
  close(): Promise<void>;
  abort?(): Promise<void>;
}

interface FileHandleLike {
  createWritable(): Promise<WritableFileLike>;
}

interface SaveFilePickerOptionsLike {
  suggestedName: string;
  types: Array<{
    description: string;
    accept: Record<string, string[]>;
  }>;
}

export type SaveFilePickerLike = (options: SaveFilePickerOptionsLike) => Promise<FileHandleLike>;

export type ImageSaveDestination =
  | { kind: 'matlab'; requestId: string; filename: string }
  | { kind: 'file-system'; handle: FileHandleLike; filename: string }
  | { kind: 'download'; filename: string };

export interface ImageWriteProgress {
  completedChunks: number;
  totalChunks: number;
  progress: number;
}

interface DestinationResponse {
  requestId: string;
  status: 'ready' | 'cancelled' | 'download' | 'error';
  message?: string;
}

interface ChunkResponse {
  requestId: string;
  index: number;
  status: 'success' | 'error';
  message?: string;
}

const payloadRecord = (value: unknown): Record<string, unknown> | undefined =>
  typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : undefined;

const destinationResponse = (value: unknown): DestinationResponse | undefined => {
  const payload = payloadRecord(value);
  const status = payload?.status;
  if (
    typeof payload?.requestId !== 'string' ||
    (status !== 'ready' && status !== 'cancelled' && status !== 'download' && status !== 'error')
  ) {
    return undefined;
  }
  return {
    requestId: payload.requestId,
    status,
    message: typeof payload.message === 'string' ? payload.message : undefined,
  };
};

const chunkResponse = (value: unknown): ChunkResponse | undefined => {
  const payload = payloadRecord(value);
  const status = payload?.status;
  if (
    typeof payload?.requestId !== 'string' ||
    typeof payload.index !== 'number' ||
    (status !== 'success' && status !== 'error')
  ) {
    return undefined;
  }
  return {
    requestId: payload.requestId,
    index: payload.index,
    status,
    message: typeof payload.message === 'string' ? payload.message : undefined,
  };
};

const pickerType = (format: ImageExportFormat): SaveFilePickerOptionsLike['types'][number] => {
  if (format === 'jpeg') {
    return { description: 'JPEG image', accept: { 'image/jpeg': ['.jpg', '.jpeg'] } };
  }
  if (format === 'tiff') {
    return { description: 'TIFF image', accept: { 'image/tiff': ['.tif', '.tiff'] } };
  }
  if (format === 'svg') {
    return { description: 'SVG image', accept: { 'image/svg+xml': ['.svg'] } };
  }
  if (format === 'pdf-vector' || format === 'pdf-raster') {
    return { description: 'PDF document', accept: { 'application/pdf': ['.pdf'] } };
  }
  return { description: 'PNG image', accept: { 'image/png': ['.png'] } };
};

const isAbortError = (error: unknown): boolean =>
  typeof error === 'object' && error !== null && 'name' in error && error.name === 'AbortError';

const encodeBytes = (bytes: Uint8Array): string => {
  let binary = '';
  const stride = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += stride) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + stride));
  }
  return btoa(binary);
};

const defaultPicker = (): SaveFilePickerLike | undefined => {
  const target = window as Window & { showSaveFilePicker?: SaveFilePickerLike };
  if (!target.showSaveFilePicker) return undefined;
  return (options) => target.showSaveFilePicker!.call(window, options);
};

export class ImageSaveCoordinator {
  private readonly removeDestinationListener: () => void;
  private readonly removeChunkListener: () => void;
  private pendingDestination?: {
    requestId: string;
    resolve: (value: ImageSaveDestination | undefined) => void;
    reject: (error: Error) => void;
    filename: string;
  };
  private pendingChunk?: {
    requestId: string;
    index: number;
    resolve: () => void;
    reject: (error: Error) => void;
  };
  private serial = 0;

  constructor(
    private readonly bridge: ImageSaveBridge,
    private readonly picker: SaveFilePickerLike | undefined = defaultPicker(),
    private readonly chunkBytes = 192 * 1024,
  ) {
    this.removeDestinationListener = bridge.on('image:exportDestination', (value) => {
      this.receiveDestination(value);
    });
    this.removeChunkListener = bridge.on('image:exportChunkResult', (value) => {
      this.receiveChunk(value);
    });
  }

  async choose(
    filename: string,
    format: ImageExportFormat,
  ): Promise<ImageSaveDestination | undefined> {
    if (this.bridge.connected) {
      if (this.pendingDestination) throw new Error('Another save-location dialog is already open.');
      const requestId = `image-export-${Date.now()}-${++this.serial}`;
      return await new Promise<ImageSaveDestination | undefined>((resolve, reject) => {
        this.pendingDestination = { requestId, resolve, reject, filename };
        this.bridge.emit('viewer:chooseImageExport', { requestId, filename, format });
      });
    }
    if (!this.picker) return { kind: 'download', filename };
    try {
      const handle = await this.picker({ suggestedName: filename, types: [pickerType(format)] });
      return { kind: 'file-system', handle, filename };
    } catch (error) {
      if (isAbortError(error)) return undefined;
      throw error;
    }
  }

  async save(
    blob: Blob,
    destination: ImageSaveDestination,
    onProgress?: (progress: ImageWriteProgress) => void,
  ): Promise<boolean> {
    if (destination.kind === 'download') return false;
    if (destination.kind === 'file-system') {
      const writable = await destination.handle.createWritable();
      try {
        await writable.write(blob);
        await writable.close();
        onProgress?.({ completedChunks: 1, totalChunks: 1, progress: 1 });
      } catch (error) {
        await writable.abort?.();
        throw error;
      }
      return true;
    }
    const totalChunks = Math.max(Math.ceil(blob.size / this.chunkBytes), 1);
    try {
      for (let index = 0; index < totalChunks; index += 1) {
        const start = index * this.chunkBytes;
        const bytes = new Uint8Array(
          await blob.slice(start, Math.min(start + this.chunkBytes, blob.size)).arrayBuffer(),
        );
        await this.sendChunk(destination.requestId, index, totalChunks, encodeBytes(bytes));
        onProgress?.({
          completedChunks: index + 1,
          totalChunks,
          progress: (index + 1) / totalChunks,
        });
      }
    } catch (error) {
      this.cancel(destination);
      throw error;
    }
    return true;
  }

  cancel(destination: ImageSaveDestination | undefined): void {
    if (destination?.kind === 'matlab') {
      this.bridge.emit('viewer:cancelImageExport', { requestId: destination.requestId });
    }
  }

  dispose(): void {
    this.removeDestinationListener();
    this.removeChunkListener();
    this.pendingDestination?.reject(
      new Error('Image save was cancelled because the viewer closed.'),
    );
    this.pendingChunk?.reject(new Error('Image save was cancelled because the viewer closed.'));
    this.pendingDestination = undefined;
    this.pendingChunk = undefined;
  }

  private receiveDestination(value: unknown): void {
    const response = destinationResponse(value);
    const pending = this.pendingDestination;
    if (!response || !pending || response.requestId !== pending.requestId) return;
    this.pendingDestination = undefined;
    if (response.status === 'cancelled') {
      pending.resolve(undefined);
    } else if (response.status === 'download') {
      pending.resolve({ kind: 'download', filename: pending.filename });
    } else if (response.status === 'ready') {
      pending.resolve({
        kind: 'matlab',
        requestId: response.requestId,
        filename: pending.filename,
      });
    } else {
      pending.reject(new Error(response.message || 'Unable to choose an image export location.'));
    }
  }

  private receiveChunk(value: unknown): void {
    const response = chunkResponse(value);
    const pending = this.pendingChunk;
    if (
      !response ||
      !pending ||
      response.requestId !== pending.requestId ||
      response.index !== pending.index
    ) {
      return;
    }
    this.pendingChunk = undefined;
    if (response.status === 'success') pending.resolve();
    else pending.reject(new Error(response.message || 'Unable to write the exported image.'));
  }

  private async sendChunk(
    requestId: string,
    index: number,
    totalChunks: number,
    data: string,
  ): Promise<void> {
    if (this.pendingChunk) throw new Error('An image data chunk is still being written.');
    await new Promise<void>((resolve, reject) => {
      this.pendingChunk = { requestId, index, resolve, reject };
      this.bridge.emit('viewer:imageExportChunk', {
        requestId,
        index,
        totalChunks,
        final: index === totalChunks - 1,
        data,
      });
    });
  }
}
