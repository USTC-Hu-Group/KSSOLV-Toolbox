export type ViewerShortcut =
  | 'center-view'
  | 'toggle-minimal-ui'
  | 'clear-selection'
  | 'delete-selection'
  | 'select-all-atoms'
  | 'undo'
  | 'redo'
  | 'box-select'
  | 'lasso-select'
  | 'move-selection'
  | 'rotate-selection'
  | 'sketch-molecule'
  | 'sketch-adsorbate'
  | 'axis-x'
  | 'axis-y'
  | 'axis-z'
  | 'content-zoom-in'
  | 'content-zoom-out'
  | 'content-zoom-reset'
  | 'show-shortcuts';

export const CONTENT_ZOOM_STEPS = [75, 100, 125, 150, 175, 200] as const;

export const nextContentZoomPercent = (
  current: number,
  direction: 'in' | 'out' | 'reset',
): number => {
  if (direction === 'reset') return 100;
  const ordered = [...CONTENT_ZOOM_STEPS];
  if (direction === 'in') {
    return ordered.find((step) => step > current) ?? ordered[ordered.length - 1]!;
  }
  return [...ordered].reverse().find((step) => step < current) ?? ordered[0]!;
};

export const DEFAULT_VIEWER_KEYMAP = {
  toggleMinimalUi: 'i',
  boxSelect: 'b',
  lassoSelect: 'l',
  moveSelection: 'g',
  rotateSelection: 'r',
  sketchMolecule: 's',
  sketchAdsorbate: 'o',
  axisX: 'x',
  axisY: 'y',
  axisZ: 'z',
  showShortcuts: '?',
} as const;

/**
 * Register the viewer shortcut listener in the capture phase. Native form
 * controls may consume Escape before it bubbles, but Escape must always be
 * able to cancel a transient modeling tool.
 */
export const registerViewerShortcutListener = (
  target: Window,
  listener: (event: KeyboardEvent) => void,
): (() => void) => {
  target.addEventListener('keydown', listener, true);
  return () => target.removeEventListener('keydown', listener, true);
};

export const registerViewerEscapeReleaseListener = (
  target: Window,
  listener: (event: KeyboardEvent) => void,
): (() => void) => {
  target.addEventListener('keyup', listener, true);
  return () => target.removeEventListener('keyup', listener, true);
};

/**
 * Observe the embedded viewer yielding focus to its host application. This is
 * a separate boundary from DOM focus changes inside the viewer: MATLAB
 * toolstrip actions take focus away from the whole WebView.
 */
export const releaseViewerControlFocus = (event: Pick<Event, 'currentTarget'>): void => {
  if (event.currentTarget instanceof HTMLElement) event.currentTarget.blur();
};

const isEditableTarget = (target: EventTarget | null): boolean => {
  if (!(target instanceof HTMLElement)) return false;
  return (
    target.isContentEditable || target.matches('input, select, textarea, button, [role="textbox"]')
  );
};

const isViewerToolbarTarget = (target: EventTarget | null): boolean =>
  target instanceof HTMLElement && target.closest('.viewer-toolbar') !== null;

export const viewerShortcutFor = (
  event: Pick<
    KeyboardEvent,
    'altKey' | 'ctrlKey' | 'key' | 'metaKey' | 'repeat' | 'shiftKey' | 'target'
  >,
): ViewerShortcut | undefined => {
  const key = event.key.toLowerCase();
  const primaryModifier = event.metaKey !== event.ctrlKey && (event.metaKey || event.ctrlKey);
  if (event.altKey) return undefined;
  // Escape is the universal cancellation path for transient modeling tools.
  // Keep it active even when a palette input/select owns focus; otherwise the
  // next canvas click can still create an atom or bond after an apparent cancel.
  if (event.key === 'Escape') return 'clear-selection';
  // MATLAB's embedded Chromium does not expose native page zoom. Handle the
  // platform-standard chords before the editable-target guard so accessibility
  // zoom remains available while a form control owns focus.
  if (primaryModifier && (event.key === '+' || event.key === '=')) return 'content-zoom-in';
  if (primaryModifier && (event.key === '-' || event.key === '_')) return 'content-zoom-out';
  if (primaryModifier && event.key === '0') return 'content-zoom-reset';
  if (isEditableTarget(event.target) && !isViewerToolbarTarget(event.target)) return undefined;
  if (primaryModifier && key === 'a') return 'select-all-atoms';
  if (primaryModifier && key === 'z') return event.shiftKey ? 'redo' : 'undo';
  if (event.ctrlKey || event.metaKey) return undefined;
  if (event.key === ' ' || event.key === 'Spacebar') {
    return 'center-view';
  }
  if (event.key === 'Backspace' || event.key === 'Delete') return 'delete-selection';
  if (event.repeat) return undefined;
  if (key === '?' || key === '/') return 'show-shortcuts';
  if (key === DEFAULT_VIEWER_KEYMAP.toggleMinimalUi) return 'toggle-minimal-ui';
  if (key === DEFAULT_VIEWER_KEYMAP.boxSelect) return 'box-select';
  if (key === DEFAULT_VIEWER_KEYMAP.lassoSelect) return 'lasso-select';
  if (key === DEFAULT_VIEWER_KEYMAP.moveSelection) return 'move-selection';
  if (key === DEFAULT_VIEWER_KEYMAP.rotateSelection) return 'rotate-selection';
  if (key === DEFAULT_VIEWER_KEYMAP.sketchMolecule) return 'sketch-molecule';
  if (key === DEFAULT_VIEWER_KEYMAP.sketchAdsorbate) return 'sketch-adsorbate';
  if (key === DEFAULT_VIEWER_KEYMAP.axisX) return 'axis-x';
  if (key === DEFAULT_VIEWER_KEYMAP.axisY) return 'axis-y';
  if (key === DEFAULT_VIEWER_KEYMAP.axisZ) return 'axis-z';
  return undefined;
};
