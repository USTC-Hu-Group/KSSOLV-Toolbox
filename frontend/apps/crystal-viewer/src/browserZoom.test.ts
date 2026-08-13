import { installEmbeddedBrowserZoomGuard } from '@kssolv/matlab-bridge';
import { describe, expect, it } from 'vitest';

describe('embedded browser zoom guard', () => {
  it('blocks browser zoom gestures without consuming ordinary scrolling', () => {
    const remove = installEmbeddedBrowserZoomGuard(window);
    const scroll = new WheelEvent('wheel', { cancelable: true, deltaY: 40 });
    const pinch = new WheelEvent('wheel', { cancelable: true, deltaY: -40 });
    Object.defineProperty(pinch, 'ctrlKey', { value: true });
    const gesture = new Event('gesturestart', { cancelable: true });
    const zoomChord = new KeyboardEvent('keydown', {
      cancelable: true,
      ctrlKey: true,
      key: '+',
    });

    window.dispatchEvent(scroll);
    window.dispatchEvent(pinch);
    window.dispatchEvent(gesture);
    window.dispatchEvent(zoomChord);

    expect(scroll.defaultPrevented).toBe(false);
    expect(pinch.defaultPrevented).toBe(true);
    expect(gesture.defaultPrevented).toBe(true);
    expect(zoomChord.defaultPrevented).toBe(true);
    remove();
  });
});
