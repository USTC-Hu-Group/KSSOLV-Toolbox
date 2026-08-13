export interface FullscreenDocument {
  readonly fullscreenElement: Element | null;
  exitFullscreen(): Promise<void>;
}

export interface FullscreenElement {
  requestFullscreen(): Promise<void>;
}

export const toggleFullscreen = async (
  element: FullscreenElement,
  fullscreenDocument: FullscreenDocument = document,
): Promise<'entered' | 'exited'> => {
  if (fullscreenDocument.fullscreenElement) {
    await fullscreenDocument.exitFullscreen();
    return 'exited';
  }

  await element.requestFullscreen();
  return 'entered';
};
