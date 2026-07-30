import { describe, expect, it } from 'vitest';

import { viewerShortcutFor } from './keyboard';

const keyEvent = (
  key: string,
  overrides: Partial<KeyboardEvent> = {},
): Pick<KeyboardEvent, 'altKey' | 'ctrlKey' | 'key' | 'metaKey' | 'repeat' | 'target'> => ({
  altKey: false,
  ctrlKey: false,
  key,
  metaKey: false,
  repeat: false,
  target: document.body,
  ...overrides,
});

describe('viewer keyboard shortcuts', () => {
  it('maps Space to centering the current view', () => {
    expect(viewerShortcutFor(keyEvent(' '))).toBe('center-view');
    expect(viewerShortcutFor(keyEvent('Spacebar'))).toBe('center-view');
  });

  it('maps I without regard to letter case', () => {
    expect(viewerShortcutFor(keyEvent('i'))).toBe('toggle-minimal-ui');
    expect(viewerShortcutFor(keyEvent('I'))).toBe('toggle-minimal-ui');
  });

  it('keeps Space active after clicking a viewer-toolbar axis button', () => {
    const toolbar = document.createElement('nav');
    toolbar.className = 'viewer-toolbar';
    const button = document.createElement('button');
    toolbar.append(button);
    expect(viewerShortcutFor(keyEvent(' ', { target: button }))).toBe('center-view');
  });

  it('does not intercept text entry, settings button activation, or modified shortcuts', () => {
    for (const element of [
      document.createElement('input'),
      document.createElement('select'),
      document.createElement('textarea'),
      document.createElement('button'),
    ]) {
      expect(viewerShortcutFor(keyEvent(' ', { target: element }))).toBeUndefined();
      expect(viewerShortcutFor(keyEvent('i', { target: element }))).toBeUndefined();
    }
    expect(viewerShortcutFor(keyEvent('i', { metaKey: true }))).toBeUndefined();
    expect(viewerShortcutFor(keyEvent('i', { ctrlKey: true }))).toBeUndefined();
  });

  it('ignores key repeat when toggling the interface', () => {
    expect(viewerShortcutFor(keyEvent('i', { repeat: true }))).toBeUndefined();
  });
});
