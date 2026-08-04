import { describe, expect, it } from 'vitest';

import { createDebugScene } from './scene/debugScene';
import { defaultViewerOptions, type CameraSnapshot } from './scene/types';
import { buildOfflineHtml, offlineHtmlBlob } from './offlineExport';

const camera: CameraSnapshot = {
  position: [8, 7, 9],
  target: [2.82, 2.82, 2.82],
  up: [0, 0, 1],
  zoom: 1,
};

const sourceDocument = (): Document =>
  new DOMParser().parseFromString(
    '<!doctype html><html><head><title>Viewer</title><style>body{margin:0}</style><script type="module">window.setup?.({})</script></head><body><div id="app" data-v-app><canvas></canvas></div></body></html>',
    'text/html',
  );

describe('offline viewer export', () => {
  it('embeds the scene and clears transient rendered markup', async () => {
    const scene = createDebugScene();
    scene.structure.formula = '</script><script>alert(1)</script>';
    const html = buildOfflineHtml(
      { scene, options: defaultViewerOptions(), camera },
      'NaCl',
      sourceDocument(),
    );

    expect(html.startsWith('<!doctype html>')).toBe(true);
    expect(html).toContain('data-kssolv-offline="true"');
    expect(html).toContain('window.__KSSOLV_OFFLINE_VIEWER__=');
    expect(html).toContain('\\u003c/script>');
    expect(html).not.toContain('<canvas>');
    expect(html).not.toContain('data-v-app');

    const blob = offlineHtmlBlob(html);
    expect(blob.type).toBe('text/html;charset=utf-8');
    expect(await blob.text()).toContain('KSSOLV Offline Viewer');
  });

  it('rejects documents that still depend on external runtime assets', () => {
    const document = new DOMParser().parseFromString(
      '<!doctype html><html><head><script type="module" src="./viewer.js"></script></head><body><div id="app"></div></body></html>',
      'text/html',
    );

    expect(() =>
      buildOfflineHtml(
        { scene: createDebugScene(), options: defaultViewerOptions(), camera },
        'NaCl',
        document,
      ),
    ).toThrow(/self-contained production viewer build/);
  });
});
