import { createApp } from 'vue';

import App from './App.vue';
import { matlabBridge, type MatlabHtmlComponent } from './bridge/matlabBridge';
import { createDebugMoleculeScene, createDebugScene, createStressScene } from './scene/debugScene';
import { useViewerStore } from './state/viewerStore';
import './style.css';

declare global {
  interface Window {
    MATLAB?: MatlabHtmlComponent;
    setup: (htmlComponent: MatlabHtmlComponent) => void;
    debug: () => void;
  }
}

let mounted = false;

const mount = (): void => {
  if (mounted) return;
  mounted = true;
  createApp(App).mount('#app');
};

window.setup = (htmlComponent: MatlabHtmlComponent): void => {
  window.MATLAB = htmlComponent;
  matlabBridge.attach(htmlComponent);
  mount();
};

window.debug = (): void => {
  const debugStore = useViewerStore();
  const mock: MatlabHtmlComponent = {
    addEventListener: (_name, _handler) => undefined,
    sendEventToMATLAB: (name, data) => {
      console.info(`[MATLAB:${name}]`, data);
      if (name !== 'viewer:analysisRequested' || !debugStore.scene.value) return;
      const requestId = `debug-${Date.now()}`;
      window.setTimeout(() => {
        matlabBridge.dispatchForTesting('scene:begin', { requestId });
      }, 80);
      window.setTimeout(() => {
        if (!debugStore.scene.value) return;
        matlabBridge.dispatchForTesting('scene:set', {
          ...debugStore.scene.value,
          requestId,
        });
      }, 620);
    },
  };
  window.setup(mock);
  debugStore.setScene(createDebugScene());
};

if (import.meta.env.DEV) {
  window.debug();
  const parameters = new URLSearchParams(location.search);
  if (parameters.has('molecule')) {
    useViewerStore().setScene(createDebugMoleculeScene());
  }
  const stressCount = Number.parseInt(parameters.get('stress') ?? '', 10);
  if (Number.isFinite(stressCount) && stressCount > 0) {
    useViewerStore().setScene(createStressScene(Math.min(stressCount, 25_600)));
  }
}
