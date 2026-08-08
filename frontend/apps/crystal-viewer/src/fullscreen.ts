export interface FullscreenDocument {
  readonly fullscreenElement: Element | null;
  exitFullscreen(): Promise<void>;
}

export const exitFullscreenIfActive = async (
  fullscreenDocument: FullscreenDocument = document,
): Promise<boolean> => {
  if (!fullscreenDocument.fullscreenElement) return false;
  await fullscreenDocument.exitFullscreen();
  return true;
};
