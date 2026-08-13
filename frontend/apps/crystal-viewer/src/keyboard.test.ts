import { describe, expect, it } from 'vitest';

import {
  registerViewerEscapeReleaseListener,
  registerViewerShortcutListener,
  releaseViewerControlFocus,
  nextContentZoomPercent,
  viewerShortcutFor,
} from './keyboard';

const keyEvent = (
  key: string,
  overrides: Partial<KeyboardEvent> = {},
): Pick<
  KeyboardEvent,
  'altKey' | 'ctrlKey' | 'key' | 'metaKey' | 'repeat' | 'shiftKey' | 'target'
> => ({
  altKey: false,
  ctrlKey: false,
  key,
  metaKey: false,
  repeat: false,
  shiftKey: false,
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

  it('maps standard selection, deletion, undo, and redo shortcuts', () => {
    expect(viewerShortcutFor(keyEvent('Escape'))).toBe('clear-selection');
    expect(viewerShortcutFor(keyEvent('Delete'))).toBe('delete-selection');
    expect(viewerShortcutFor(keyEvent('Backspace'))).toBe('delete-selection');
    expect(viewerShortcutFor(keyEvent('a', { metaKey: true }))).toBe('select-all-atoms');
    expect(viewerShortcutFor(keyEvent('z', { metaKey: true }))).toBe('undo');
    expect(viewerShortcutFor(keyEvent('z', { metaKey: true, shiftKey: true }))).toBe('redo');
  });

  it('maps platform content zoom chords even when a form field owns focus', () => {
    const input = document.createElement('input');
    expect(viewerShortcutFor(keyEvent('+', { metaKey: true }))).toBe('content-zoom-in');
    expect(viewerShortcutFor(keyEvent('=', { ctrlKey: true, target: input }))).toBe(
      'content-zoom-in',
    );
    expect(viewerShortcutFor(keyEvent('-', { metaKey: true }))).toBe('content-zoom-out');
    expect(viewerShortcutFor(keyEvent('0', { ctrlKey: true }))).toBe('content-zoom-reset');
  });

  it('steps deterministically between 75 and 200 percent', () => {
    expect(nextContentZoomPercent(100, 'in')).toBe(125);
    expect(nextContentZoomPercent(175, 'in')).toBe(200);
    expect(nextContentZoomPercent(200, 'in')).toBe(200);
    expect(nextContentZoomPercent(100, 'out')).toBe(75);
    expect(nextContentZoomPercent(75, 'out')).toBe(75);
    expect(nextContentZoomPercent(175, 'reset')).toBe(100);
  });

  it('keeps destructive and document shortcuts out of editable controls', () => {
    const input = document.createElement('input');
    expect(viewerShortcutFor(keyEvent('Delete', { target: input }))).toBeUndefined();
    expect(viewerShortcutFor(keyEvent('a', { metaKey: true, target: input }))).toBeUndefined();
    expect(viewerShortcutFor(keyEvent('z', { metaKey: true, target: input }))).toBeUndefined();
  });

  it('keeps Escape available to cancel a modeling palette with focused controls', () => {
    for (const element of [document.createElement('input'), document.createElement('select')]) {
      expect(viewerShortcutFor(keyEvent('Escape', { target: element }))).toBe('clear-selection');
    }
  });

  it('captures Escape before a focused native select consumes it', () => {
    const select = document.createElement('select');
    document.body.append(select);
    const received: string[] = [];
    const remove = registerViewerShortcutListener(window, (event) => received.push(event.key));
    select.addEventListener('keydown', (event) => event.stopPropagation());

    select.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Escape' }));

    expect(received).toEqual(['Escape']);
    remove();
    select.remove();
  });

  it('captures the Escape release as a native-select fallback', () => {
    const select = document.createElement('select');
    document.body.append(select);
    const received: string[] = [];
    const remove = registerViewerEscapeReleaseListener(window, (event) => received.push(event.key));
    select.addEventListener('keyup', (event) => event.stopPropagation());

    select.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'Escape' }));

    expect(received).toEqual(['Escape']);
    remove();
    select.remove();
  });

  it('returns keyboard focus to the viewport after a palette value is chosen', () => {
    const select = document.createElement('select');
    document.body.append(select);
    select.focus();

    releaseViewerControlFocus({ currentTarget: select });

    expect(document.activeElement).not.toBe(select);
    select.remove();
  });

  it('maps direct modeling tools and axis constraints', () => {
    expect(viewerShortcutFor(keyEvent('b'))).toBe('box-select');
    expect(viewerShortcutFor(keyEvent('L'))).toBe('lasso-select');
    expect(viewerShortcutFor(keyEvent('g'))).toBe('move-selection');
    expect(viewerShortcutFor(keyEvent('R'))).toBe('rotate-selection');
    expect(viewerShortcutFor(keyEvent('s'))).toBe('sketch-molecule');
    expect(viewerShortcutFor(keyEvent('O'))).toBe('sketch-adsorbate');
    expect(viewerShortcutFor(keyEvent('x'))).toBe('axis-x');
    expect(viewerShortcutFor(keyEvent('Y'))).toBe('axis-y');
    expect(viewerShortcutFor(keyEvent('z'))).toBe('axis-z');
    expect(viewerShortcutFor(keyEvent('?', { shiftKey: true }))).toBe('show-shortcuts');
    expect(viewerShortcutFor(keyEvent('/'))).toBe('show-shortcuts');
  });

  it('does not route modeling letters while typing', () => {
    const input = document.createElement('input');
    for (const key of ['b', 'l', 'g', 'r', 's', 'o', 'x', 'y', 'z', '?', '/']) {
      expect(viewerShortcutFor(keyEvent(key, { target: input }))).toBeUndefined();
    }
  });

  it('keeps the modeling keymap fixed', () => {
    expect(viewerShortcutFor(keyEvent('g'))).toBe('move-selection');
    expect(viewerShortcutFor(keyEvent('m'))).toBeUndefined();
  });
});
