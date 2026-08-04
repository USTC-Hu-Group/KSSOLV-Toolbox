import type { AtomicSceneSpec, CameraSnapshot, ViewerOptions } from './scene/types';

export interface OfflineViewerPayload {
  scene: AtomicSceneSpec;
  options: ViewerOptions;
  camera: CameraSnapshot;
}

const payloadScript = (payload: OfflineViewerPayload): string =>
  `window.__KSSOLV_OFFLINE_VIEWER__=${JSON.stringify(payload).replace(/</g, '\\u003c')};`;

export const buildOfflineHtml = (
  payload: OfflineViewerPayload,
  title: string,
  sourceDocument: Document = document,
): string => {
  const root = sourceDocument.documentElement.cloneNode(true) as HTMLElement;
  const externalAssets = root.querySelectorAll(
    'script[src], link[rel="stylesheet"][href], link[rel="modulepreload"][href]',
  );
  if (externalAssets.length > 0) {
    throw new Error('Offline HTML export requires the self-contained production viewer build.');
  }

  root.querySelectorAll('script[data-kssolv-offline-payload]').forEach((element) => {
    element.remove();
  });
  const app = root.querySelector('#app');
  if (!app) throw new Error('Unable to locate the viewer application root.');
  app.replaceChildren();
  app.removeAttribute('data-v-app');

  const titleElement = root.querySelector('title') ?? sourceDocument.createElement('title');
  titleElement.textContent = `${title} · KSSOLV Offline Viewer`;
  if (!titleElement.parentElement) root.querySelector('head')?.append(titleElement);

  const bootstrap = sourceDocument.createElement('script');
  bootstrap.dataset.kssolvOfflinePayload = '';
  bootstrap.textContent = payloadScript(payload);
  const head = root.querySelector('head');
  if (!head) throw new Error('Unable to locate the viewer document head.');
  head.insertBefore(bootstrap, head.firstChild);

  root.dataset.kssolvOffline = 'true';
  return `<!doctype html>\n${root.outerHTML}`;
};

export const offlineHtmlBlob = (html: string): Blob =>
  new Blob([html], { type: 'text/html;charset=utf-8' });
