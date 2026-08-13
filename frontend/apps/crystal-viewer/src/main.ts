import { createApp } from 'vue';

import { installEmbeddedBrowserZoomGuard } from '@kssolv/matlab-bridge';

import App from './App.vue';
import { matlabBridge, type MatlabHtmlComponent } from './bridge/matlabBridge';
import {
  createBlankDebugScene,
  createDebugMoleculeScene,
  createDebugScene,
  createStressScene,
} from './scene/debugScene';
import type { AtomicSceneSpec, CameraSnapshot, ViewerOptions } from './scene/types';
import { useViewerStore } from './state/viewerStore';
import type { StructureExportFormat } from './structureExport';
import './style.css';

declare global {
  interface Window {
    MATLAB?: MatlabHtmlComponent;
    __KSSOLV_PENDING_MATLAB_COMPONENT__?: MatlabHtmlComponent;
    setup: (htmlComponent: MatlabHtmlComponent) => void;
    debug: () => void;
    __KSSOLV_OFFLINE_VIEWER__?: {
      scene: AtomicSceneSpec;
      options: ViewerOptions;
      camera: CameraSnapshot;
    };
  }
}

let mounted = false;

installEmbeddedBrowserZoomGuard();

const debugCrystalExportFormats: StructureExportFormat[] = [
  { format: 'cif', label: 'CIF', extension: 'cif', detail: '.cif' },
  { format: 'poscar', label: 'VASP POSCAR', extension: 'poscar', detail: '.poscar' },
  { format: 'vasp', label: 'VASP', extension: 'vasp', detail: '.vasp' },
  { format: 'xyz', label: 'XYZ', extension: 'xyz', detail: '.xyz' },
  { format: 'config', label: 'CONFIG', extension: 'config', detail: '.config' },
  { format: 'cssr', label: 'CSSR', extension: 'cssr', detail: '.cssr' },
  { format: 'exciting', label: 'exciting XML', extension: 'xml', detail: '.xml' },
  { format: 'json', label: 'JSON', extension: 'json', detail: '.json' },
  { format: 'lmto', label: 'LMTO CTRL', extension: 'ctrl', detail: '.ctrl' },
  { format: 'mcsqs', label: 'ATAT MCSQS', extension: 'in', detail: '.in' },
  { format: 'mson', label: 'MSON', extension: 'mson', detail: '.mson' },
  { format: 'prismatic', label: 'Prismatic XYZ', extension: 'xyz', detail: '.xyz' },
  { format: 'pwmat', label: 'PWmat CONFIG', extension: 'config', detail: '.config' },
  { format: 'yaml', label: 'YAML', extension: 'yaml', detail: '.yaml' },
];

const debugMoleculeExportFormats: StructureExportFormat[] = [
  { format: 'xyz', label: 'XYZ', extension: 'xyz', detail: '.xyz' },
  { format: 'cml', label: 'CML', extension: 'cml', detail: '.cml' },
  { format: 'gaussian', label: 'Gaussian input', extension: 'gjf', detail: '.gjf' },
  { format: 'json', label: 'JSON', extension: 'json', detail: '.json' },
  { format: 'mdl', label: 'MDL', extension: 'mdl', detail: '.mdl' },
  { format: 'mol2', label: 'MOL2', extension: 'mol2', detail: '.mol2' },
  { format: 'mrv', label: 'MRV', extension: 'mrv', detail: '.mrv' },
  { format: 'mson', label: 'MSON', extension: 'mson', detail: '.mson' },
  { format: 'pdb', label: 'PDB', extension: 'pdb', detail: '.pdb' },
  { format: 'sdf', label: 'SDF', extension: 'sdf', detail: '.sdf' },
  { format: 'yaml', label: 'YAML', extension: 'yaml', detail: '.yaml' },
];

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

const pendingMatlabComponent = window.__KSSOLV_PENDING_MATLAB_COMPONENT__;
if (pendingMatlabComponent) {
  delete window.__KSSOLV_PENDING_MATLAB_COMPONENT__;
  window.setup(pendingMatlabComponent);
}

window.debug = (): void => {
  const debugStore = useViewerStore();
  const mock: MatlabHtmlComponent = {
    addEventListener: (_name, _handler) => undefined,
    sendEventToMATLAB: (name, data) => {
      console.info(`[MATLAB:${name}]`, data);
      if (name === 'viewer:ready') {
        matlabBridge.dispatchForTesting('structure:exportFormats', {
          formats:
            debugStore.scene.value?.kind === 'molecule'
              ? debugMoleculeExportFormats
              : debugCrystalExportFormats,
        });
        return;
      }
      if (name === 'viewer:exportStructure') {
        matlabBridge.dispatchForTesting('structure:exportResult', {
          ...(typeof data === 'object' && data !== null ? data : {}),
          status: 'success',
          message: '',
        });
        return;
      }
      if (name === 'viewer:chooseImageExport') {
        matlabBridge.dispatchForTesting('image:exportDestination', {
          ...(typeof data === 'object' && data !== null ? data : {}),
          status: 'download',
        });
        return;
      }
      if (name === 'viewer:modelingCommandRequested') {
        window.setTimeout(() => {
          matlabBridge.dispatchForTesting('modeling:result', {
            commandId:
              typeof data === 'object' && data !== null && 'commandId' in data
                ? data.commandId
                : '',
            status: 'error',
            message: 'Modeling commands require a running KSSOLV Toolbox session.',
          });
        }, 0);
        return;
      }
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

const offline = window.__KSSOLV_OFFLINE_VIEWER__;
if (offline) {
  const listeners = new Map<string, (event: { Data?: unknown }) => void>();
  const offlineComponent: MatlabHtmlComponent = {
    addEventListener: (name, handler) => {
      listeners.set(name, handler);
    },
    sendEventToMATLAB: (name, data) => {
      if (name === 'viewer:chooseImageExport') {
        window.setTimeout(() => {
          listeners.get('image:exportDestination')?.({
            Data: {
              ...(typeof data === 'object' && data !== null ? data : {}),
              status: 'download',
            },
          });
        }, 0);
        return;
      }
      if (name !== 'viewer:analysisRequested') return;
      window.setTimeout(() => {
        listeners.get('scene:error')?.({
          Data: { message: 'Scientific analysis is unavailable in an offline HTML export.' },
        });
      }, 0);
    },
  };
  const offlineStore = useViewerStore();
  offlineStore.updateOptions(offline.options);
  offlineStore.setScene(offline.scene);
  window.setup(offlineComponent);
  listeners.get('viewer:command')?.({
    Data: { command: 'camera', camera: offline.camera },
  });
} else if (import.meta.env.DEV || new URLSearchParams(location.search).has('debug')) {
  window.debug();
  const parameters = new URLSearchParams(location.search);
  if (parameters.has('molecule')) {
    useViewerStore().setScene(createDebugMoleculeScene());
  }
  if (parameters.has('blank')) {
    useViewerStore().setScene(createBlankDebugScene());
  }
  if (parameters.has('warning')) {
    const warningScene = createDebugScene();
    warningScene.warnings = [
      {
        code: 'CONNECTIVITY_FALLBACK',
        message:
          'CrystalNN could not resolve this geometry; VESTA cutoff connectivity is shown instead.',
        severity: 'warning',
      },
    ];
    useViewerStore().setScene(warningScene);
  }
  const stressCount = Number.parseInt(parameters.get('stress') ?? '', 10);
  if (Number.isFinite(stressCount) && stressCount > 0) {
    useViewerStore().setScene(createStressScene(Math.min(stressCount, 25_600)));
  }
}
