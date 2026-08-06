import { describe, expect, it, vi } from 'vitest';

import { ImageSaveCoordinator } from './imageSave';

class TestBridge {
  connected = true;
  readonly emit = vi.fn();
  private readonly handlers = new Map<string, (value: unknown) => void>();

  on(name: string, handler: (value: unknown) => void): () => void {
    this.handlers.set(name, handler);
    return () => this.handlers.delete(name);
  }

  dispatch(name: string, value: unknown): void {
    this.handlers.get(name)?.(value);
  }
}

describe('image save coordinator', () => {
  it('chooses a MATLAB destination before any image data is sent', async () => {
    const bridge = new TestBridge();
    const coordinator = new ImageSaveCoordinator(bridge);
    const choice = coordinator.choose('Si-hero.png', 'png');
    const request = bridge.emit.mock.calls[0]?.[1] as { requestId: string };

    expect(bridge.emit.mock.calls[0]?.[0]).toBe('viewer:chooseImageExport');
    expect(bridge.emit).toHaveBeenCalledTimes(1);
    bridge.dispatch('image:exportDestination', { requestId: request.requestId, status: 'ready' });

    await expect(choice).resolves.toEqual({
      kind: 'matlab',
      requestId: request.requestId,
      filename: 'Si-hero.png',
    });
    coordinator.dispose();
  });

  it('does no rendering work after the save dialog is cancelled', async () => {
    const bridge = new TestBridge();
    const coordinator = new ImageSaveCoordinator(bridge);
    const choice = coordinator.choose('Si.png', 'png');
    const request = bridge.emit.mock.calls[0]?.[1] as { requestId: string };

    bridge.dispatch('image:exportDestination', {
      requestId: request.requestId,
      status: 'cancelled',
    });

    await expect(choice).resolves.toBeUndefined();
    expect(bridge.emit).toHaveBeenCalledTimes(1);
    coordinator.dispose();
  });

  it('streams large blobs in acknowledged chunks', async () => {
    const bridge = new TestBridge();
    const coordinator = new ImageSaveCoordinator(bridge, undefined, 3);
    const progress = vi.fn();
    bridge.emit.mockImplementation((name, payload) => {
      if (name !== 'viewer:imageExportChunk') return;
      const chunk = payload as { requestId: string; index: number };
      bridge.dispatch('image:exportChunkResult', { ...chunk, status: 'success' });
    });

    await expect(
      coordinator.save(
        new Blob([new Uint8Array([1, 2, 3, 4, 5, 6, 7])]),
        { kind: 'matlab', requestId: 'request-1', filename: 'Si.png' },
        progress,
      ),
    ).resolves.toBe(true);

    const chunks = bridge.emit.mock.calls.filter(([name]) => name === 'viewer:imageExportChunk');
    expect(chunks).toHaveLength(3);
    expect(chunks.map(([, payload]) => (payload as { final: boolean }).final)).toEqual([
      false,
      false,
      true,
    ]);
    expect(progress).toHaveBeenLastCalledWith({ completedChunks: 3, totalChunks: 3, progress: 1 });
    coordinator.dispose();
  });

  it('uses a browser file handle when MATLAB is unavailable', async () => {
    const bridge = new TestBridge();
    bridge.connected = false;
    const writable = { write: vi.fn(), close: vi.fn() };
    const picker = vi.fn().mockResolvedValue({ createWritable: async () => writable });
    const coordinator = new ImageSaveCoordinator(bridge, picker);

    const destination = await coordinator.choose('render.jpg', 'jpeg');
    expect(picker).toHaveBeenCalledWith({
      suggestedName: 'render.jpg',
      types: [{ description: 'JPEG image', accept: { 'image/jpeg': ['.jpg', '.jpeg'] } }],
    });
    expect(destination?.kind).toBe('file-system');
    if (destination) await coordinator.save(new Blob(['image']), destination);
    expect(writable.write).toHaveBeenCalledTimes(1);
    expect(writable.close).toHaveBeenCalledTimes(1);
    coordinator.dispose();
  });
});
