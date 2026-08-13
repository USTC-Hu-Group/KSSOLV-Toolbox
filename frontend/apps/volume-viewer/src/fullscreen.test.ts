import { describe, expect, it, vi } from 'vitest';

import {
  toggleFullscreen,
  type FullscreenDocument,
  type FullscreenElement,
} from './fullscreen';

describe('fullscreen toggle', () => {
  it('enters fullscreen when fullscreen is inactive', async () => {
    const requestFullscreen = vi.fn(async () => undefined);
    const exitFullscreen = vi.fn(async () => undefined);
    const element: FullscreenElement = { requestFullscreen };
    const fullscreenDocument: FullscreenDocument = {
      fullscreenElement: null,
      exitFullscreen,
    };

    await expect(toggleFullscreen(element, fullscreenDocument)).resolves.toBe('entered');
    expect(requestFullscreen).toHaveBeenCalledOnce();
    expect(exitFullscreen).not.toHaveBeenCalled();
  });

  it('exits fullscreen when fullscreen is active', async () => {
    const requestFullscreen = vi.fn(async () => undefined);
    const exitFullscreen = vi.fn(async () => undefined);
    const element: FullscreenElement = { requestFullscreen };
    const fullscreenDocument: FullscreenDocument = {
      fullscreenElement: document.createElement('main'),
      exitFullscreen,
    };

    await expect(toggleFullscreen(element, fullscreenDocument)).resolves.toBe('exited');
    expect(exitFullscreen).toHaveBeenCalledOnce();
    expect(requestFullscreen).not.toHaveBeenCalled();
  });
});
