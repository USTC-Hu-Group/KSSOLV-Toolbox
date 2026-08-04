import { computed, reactive, readonly, shallowRef } from 'vue';

import { matlabBridge } from '../bridge/matlabBridge';
import {
  defaultViewerOptions,
  type AtomInstanceSpec,
  type AtomicSceneSpec,
  type CameraSnapshot,
  type SelectionInfo,
  type SiteSpec,
  type ThemeId,
  type ViewerOptions,
} from '../scene/types';
import { SceneValidationError, validateScene } from '../scene/validate';

export type SceneActivityPhase = 'idle' | 'queued' | 'building' | 'success' | 'error';
type AtomSelectionInfo = SelectionInfo & {
  kind: 'atom';
  atom: AtomInstanceSpec;
  site: SiteSpec;
};

const scene = shallowRef<AtomicSceneSpec>();
const selection = shallowRef<SelectionInfo>();
const selectedSiteIndices = shallowRef<number[]>([]);
const selectedAtomIds = shallowRef<string[]>([]);
const selectedAtomSites = new Map<string, number>();
const camera = shallowRef<CameraSnapshot>();
const options = reactive<ViewerOptions>(defaultViewerOptions());
const status = reactive({
  ready: false,
  loading: false,
  error: '',
  lastRequestId: '',
  expectedRequestId: '',
  activityPhase: 'idle' as SceneActivityPhase,
  activityMessage: '',
});

let bridgeInstalled = false;
let activityStartedAt = 0;
let userRequestedRebuild = false;
let acknowledgementTimer: number | undefined;
let buildTimer: number | undefined;

const clearRequestTimers = (): void => {
  if (acknowledgementTimer !== undefined) window.clearTimeout(acknowledgementTimer);
  if (buildTimer !== undefined) window.clearTimeout(buildTimer);
  acknowledgementTimer = undefined;
  buildTimer = undefined;
};

const failActivity = (message: string): void => {
  clearRequestTimers();
  status.error = message;
  status.loading = false;
  status.activityPhase = 'error';
  status.activityMessage = message;
  userRequestedRebuild = false;
  activityStartedAt = 0;
};

const elapsedLabel = (): string => {
  if (!activityStartedAt) return '';
  const elapsed = Math.max(Date.now() - activityStartedAt, 0);
  return elapsed < 1000 ? `${elapsed} ms` : `${(elapsed / 1000).toFixed(1)} s`;
};

const acceptScene = (payload: unknown): void => {
  status.error = '';
  try {
    const next = validateScene(payload);
    if (status.expectedRequestId && next.requestId !== status.expectedRequestId) {
      return;
    }
    clearRequestTimers();
    status.loading = true;
    scene.value = next;
    status.lastRequestId = next.requestId;
    selection.value = undefined;
    selectedSiteIndices.value = [];
    selectedAtomIds.value = [];
    selectedAtomSites.clear();
    status.loading = false;
    if (status.activityPhase !== 'idle') {
      const elapsed = elapsedLabel();
      status.activityPhase = 'success';
      status.activityMessage = userRequestedRebuild
        ? `Scene rebuilt${elapsed ? ` in ${elapsed}` : ''}.`
        : `Scene ready${elapsed ? ` in ${elapsed}` : ''}.`;
    }
    userRequestedRebuild = false;
    activityStartedAt = 0;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    failActivity(`Scene update failed: ${message}`);
    matlabBridge.emit('viewer:error', {
      requestId: status.lastRequestId,
      code: error instanceof SceneValidationError ? 'SCENE_VALIDATION' : 'SCENE_SET',
      message,
    });
  }
};

const updateOptions = (patch: Partial<ViewerOptions>): void => {
  Object.assign(options, patch);
};

const installBridge = (): void => {
  if (bridgeInstalled) return;
  bridgeInstalled = true;
  matlabBridge.on('scene:set', acceptScene);
  matlabBridge.on('scene:begin', (payload) => {
    if (typeof payload !== 'object' || payload === null) return;
    const requestId = (payload as { requestId?: unknown }).requestId;
    if (typeof requestId !== 'string') return;
    status.expectedRequestId = requestId;
    status.loading = true;
    status.error = '';
    status.activityPhase = 'building';
    status.activityMessage = userRequestedRebuild
      ? 'Computing bonds and rebuilding the scene…'
      : 'Computing the scientific scene…';
    if (!activityStartedAt) activityStartedAt = Date.now();
    if (acknowledgementTimer !== undefined) window.clearTimeout(acknowledgementTimer);
    acknowledgementTimer = undefined;
    if (buildTimer !== undefined) window.clearTimeout(buildTimer);
    buildTimer = window.setTimeout(() => {
      failActivity('Scene rebuild timed out in MATLAB. Please retry.');
    }, 120_000);
  });
  matlabBridge.on('scene:error', (payload) => {
    if (typeof payload !== 'object' || payload === null) return;
    const message = (payload as { message?: unknown }).message;
    failActivity(
      `Scene rebuild failed: ${
        typeof message === 'string' ? message : 'Unable to build the crystal scene.'
      }`,
    );
  });
  matlabBridge.on('scene:patch', (payload) => {
    if (!scene.value || typeof payload !== 'object' || payload === null) return;
    acceptScene({ ...scene.value, ...(payload as Partial<AtomicSceneSpec>) });
  });
  matlabBridge.on('theme:set', (payload) => {
    const theme = typeof payload === 'string' ? payload : '';
    if (theme === 'pretty' || theme === 'materials') updateOptions({ theme });
  });
};

export const useViewerStore = () => {
  installBridge();
  const isBlankStructure = computed(
    () => scene.value?.kind === 'crystal' && scene.value.structure.siteCount === 0,
  );

  return {
    scene,
    selection,
    selectedSiteIndices,
    selectedAtomIds,
    camera,
    options,
    status: readonly(status),
    isBlankStructure,
    formula: computed(() => {
      if (!scene.value) return 'Atomic structure';
      if (isBlankStructure.value) return 'Blank structure';
      return scene.value.kind === 'crystal'
        ? scene.value.structure.formula
        : scene.value.molecule.formula;
    }),
    warnings: computed(() =>
      (scene.value?.warnings ?? []).filter(
        (warning) => !(isBlankStructure.value && warning.code === 'EMPTY_STRUCTURE'),
      ),
    ),
    setScene: acceptScene,
    setSelection(value?: SelectionInfo, gesture: { additive?: boolean } = {}): void {
      selection.value = value;
      if (!value) {
        selectedSiteIndices.value = [];
        selectedAtomIds.value = [];
        selectedAtomSites.clear();
        matlabBridge.emit('viewer:selection', {
          requestId: scene.value?.requestId ?? '',
          kind: 'none',
          id: '',
          siteIndex: null,
          siteIndices: [],
          atomIds: [],
        });
        return;
      }

      if (value.kind === 'atom' && value.site && value.atom) {
        const atomId = value.atom.id;
        const removing = gesture.additive && selectedAtomSites.has(atomId);
        if (!gesture.additive) {
          selectedAtomSites.clear();
          selectedAtomSites.set(atomId, value.site.siteIndex);
        } else if (removing) {
          selectedAtomSites.delete(atomId);
        } else {
          selectedAtomSites.set(atomId, value.site.siteIndex);
        }
        selectedAtomIds.value = [...selectedAtomSites.keys()];
        selectedSiteIndices.value = [...new Set(selectedAtomSites.values())];
        if (removing) {
          const fallbackId = selectedAtomIds.value[selectedAtomIds.value.length - 1];
          const fallbackAtom = scene.value?.atomInstances.find((atom) => atom.id === fallbackId);
          const fallbackSite = fallbackAtom
            ? scene.value?.sites.find((site) => site.siteIndex === fallbackAtom.siteIndex)
            : undefined;
          selection.value =
            fallbackAtom && fallbackSite
              ? {
                  kind: 'atom',
                  id: fallbackAtom.id,
                  atom: fallbackAtom,
                  site: fallbackSite,
                  clientX: value.clientX,
                  clientY: value.clientY,
                }
              : undefined;
        }
      } else {
        selectedAtomSites.clear();
        selectedAtomIds.value = [];
        selectedSiteIndices.value =
          value.kind === 'bond' && value.bond
            ? [...new Set([value.bond.fromSiteIndex, value.bond.toSiteIndex])]
            : [];
      }
      matlabBridge.emit('viewer:selection', {
        requestId: scene.value?.requestId ?? '',
        kind: selection.value?.kind ?? 'none',
        id: selection.value?.id ?? '',
        siteIndex: selection.value?.site?.siteIndex ?? null,
        siteIndices: selectedSiteIndices.value,
        atomIds: selectedAtomIds.value,
      });
    },
    setAtomSelections(values: AtomSelectionInfo[], focusAtomId?: string): void {
      selectedAtomSites.clear();
      const selections = new Map<string, AtomSelectionInfo>();
      for (const value of values) {
        selections.set(value.atom.id, value);
        selectedAtomSites.set(value.atom.id, value.site.siteIndex);
      }
      selectedAtomIds.value = [...selections.keys()];
      selectedSiteIndices.value = [...new Set(selectedAtomSites.values())];
      selection.value =
        (focusAtomId ? selections.get(focusAtomId) : undefined) ?? values[values.length - 1];
      matlabBridge.emit('viewer:selection', {
        requestId: scene.value?.requestId ?? '',
        kind: selection.value?.kind ?? 'none',
        id: selection.value?.id ?? '',
        siteIndex: selection.value?.site?.siteIndex ?? null,
        siteIndices: selectedSiteIndices.value,
        atomIds: selectedAtomIds.value,
      });
    },
    setCamera(value: CameraSnapshot): void {
      camera.value = value;
      matlabBridge.emit('viewer:cameraChanged', {
        requestId: scene.value?.requestId ?? '',
        ...value,
      });
    },
    updateOptions,
    requestAnalysis(payload: {
      requestId: string;
      algorithm: string;
      cell: string;
      repeat: [number, number, number];
    }): void {
      clearRequestTimers();
      userRequestedRebuild = true;
      activityStartedAt = Date.now();
      status.loading = true;
      status.error = '';
      status.activityPhase = 'queued';
      status.activityMessage = 'Request sent to MATLAB…';
      matlabBridge.emit('viewer:analysisRequested', {
        ...payload,
        repeat: [payload.repeat[0], payload.repeat[1], payload.repeat[2]],
      });
      acknowledgementTimer = window.setTimeout(() => {
        failActivity('MATLAB did not acknowledge the rebuild request. Please retry.');
      }, 5_000);
    },
    clearActivity(): void {
      if (status.loading) return;
      status.activityPhase = 'idle';
      status.activityMessage = '';
    },
    setTheme(theme: ThemeId): void {
      updateOptions({ theme });
    },
    markReady(): void {
      status.ready = true;
      matlabBridge.emit('viewer:ready', {
        schemaVersion: '2.0',
        capabilities: {
          batchedMesh: true,
          webgl2: true,
          themes: ['pretty', 'materials'],
        },
      });
    },
  };
};
