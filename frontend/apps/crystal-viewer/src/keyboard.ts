export type ViewerShortcut = 'center-view' | 'toggle-minimal-ui';

const isEditableTarget = (target: EventTarget | null): boolean => {
  if (!(target instanceof HTMLElement)) return false;
  return (
    target.isContentEditable || target.matches('input, select, textarea, button, [role="textbox"]')
  );
};

const isViewerToolbarTarget = (target: EventTarget | null): boolean =>
  target instanceof HTMLElement && target.closest('.viewer-toolbar') !== null;

export const viewerShortcutFor = (
  event: Pick<KeyboardEvent, 'altKey' | 'ctrlKey' | 'key' | 'metaKey' | 'repeat' | 'target'>,
): ViewerShortcut | undefined => {
  if (event.altKey || event.ctrlKey || event.metaKey) {
    return undefined;
  }
  if (event.key === ' ' || event.key === 'Spacebar') {
    if (isEditableTarget(event.target) && !isViewerToolbarTarget(event.target)) return undefined;
    return 'center-view';
  }
  if (isEditableTarget(event.target)) return undefined;
  if (!event.repeat && event.key.toLowerCase() === 'i') return 'toggle-minimal-ui';
  return undefined;
};
