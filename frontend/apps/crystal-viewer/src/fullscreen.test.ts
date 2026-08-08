import { describe, expect, it, vi } from 'vitest';

import { exitFullscreenIfActive, type FullscreenDocument } from './fullscreen';

describe('fullscreen lifecycle', () => {
  it('does nothing when the viewer is not fullscreen', async () => {
    const exitFullscreen = vi.fn(async () => undefined);
    const fullscreenDocument: FullscreenDocument = {
      fullscreenElement: null,
      exitFullscreen,
    };

    await expect(exitFullscreenIfActive(fullscreenDocument)).resolves.toBe(false);
    expect(exitFullscreen).not.toHaveBeenCalled();
  });

  it('exits fullscreen before the host closes', async () => {
    const exitFullscreen = vi.fn(async () => undefined);
    const fullscreenDocument: FullscreenDocument = {
      fullscreenElement: document.createElement('main'),
      exitFullscreen,
    };

    await expect(exitFullscreenIfActive(fullscreenDocument)).resolves.toBe(true);
    expect(exitFullscreen).toHaveBeenCalledOnce();
  });
});
