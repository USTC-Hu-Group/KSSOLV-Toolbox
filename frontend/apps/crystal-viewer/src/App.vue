<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue';

import { matlabBridge } from './bridge/matlabBridge';
import AtomContextMenu from './components/AtomContextMenu.vue';
import ElementLegend from './components/ElementLegend.vue';
import FractionalCoordinatesPanel from './components/FractionalCoordinatesPanel.vue';
import HeroToolbar from './components/HeroToolbar.vue';
import SelectionInspector from './components/SelectionInspector.vue';
import SettingsPanel from './components/SettingsPanel.vue';
import ViewerToolbar from './components/ViewerToolbar.vue';
import WarningStack from './components/WarningStack.vue';
import { atomIdsForElement, siteSpeciesLabel } from './elementSelection';
import { exitFullscreenIfActive } from './fullscreen';
import { ImageSaveCoordinator, type ImageSaveDestination } from './imageSave';
import { viewerShortcutFor } from './keyboard';
import {
  expectedSelectionCount,
  measurementProgressAnnotation,
  measureScene,
  type MeasurementKind,
  type MeasurementRecord,
} from './measurement';
import {
  isContextModelingResult,
  modelingBackendAvailable,
  type ContextModelingCommandId,
  type ContextModelingParameters,
  type ContextModelingRequest,
} from './modeling';
import { buildOfflineHtml, offlineHtmlBlob } from './offlineExport';
import {
  CrystalRenderer,
  type CrystalRendererCallbacks,
  type RenderExportProgress,
} from './renderer/CrystalRenderer';
import type { CrystalCameraAxis } from './renderer/cameraAxis';
import type { ImageExportFormat } from './renderer/imageExport';
import { atomCountLabel } from './renderer/atomVisibility';
import type { HeroExportScale } from './renderer/quality';
import type {
  AtomHoverInfo,
  AtomInstanceSpec,
  CameraSnapshot,
  RendererStatistics,
  SiteSpec,
  ViewerOptions,
} from './scene/types';
import { useViewerStore } from './state/viewerStore';
import { parseStructureExportFormats, type StructureExportFormat } from './structureExport';
import { themes } from './themes/themes';

const root = ref<HTMLElement>();
const canvas = ref<HTMLCanvasElement>();
const heroProgressCanvas = ref<HTMLCanvasElement>();
const settingsOpen = ref(false);
const informationOpen = ref(false);
const minimalUi = ref(false);
const autoRotating = ref(false);
const heroShotActive = ref(false);
const heroExportScale = ref<HeroExportScale>(2.5);
const imageExporting = ref(false);
const rasterExporting = ref(false);
const exportProgress = shallowRef<RenderExportProgress>();
const viewerWorkMessage = ref('');
const heroExportStatus = ref<'idle' | 'rendering' | 'saved' | 'error'>('idle');
const heroRetainedFrameUrl = ref('');
const structureExporting = ref(false);
const structureExportFormats = ref<StructureExportFormat[]>([]);
const structureExportError = ref('');
const atomHover = shallowRef<AtomHoverInfo>();
const activeMeasurement = shallowRef<MeasurementRecord>();
const progressMeasurement = shallowRef<ReturnType<typeof measurementProgressAnnotation>>();
const measurementError = ref('');
const activeMeasurementKind = ref<MeasurementKind>();
const measurementSelections = shallowRef<Array<{ atom: AtomInstanceSpec; site: SiteSpec }>>([]);
const atomContextMenu = shallowRef<{
  selection: NonNullable<Parameters<NonNullable<CrystalRendererCallbacks['onAtomContextMenu']>>[0]>;
  x: number;
  y: number;
}>();
const modelingPending = ref(false);
const modelingError = ref('');
let measurementSerial = 0;
let rendererWorkSerial = 0;
let heroRestoreState:
  { options: ViewerOptions; camera: CameraSnapshot; minimalUi: boolean } | undefined;
// Three.js owns mutable, non-configurable matrix properties and must never be
// wrapped in Vue's deep reactive proxy.
const renderer = shallowRef<CrystalRenderer>();
const statistics = ref<RendererStatistics>();
const store = useViewerStore();
const imageSaver = new ImageSaveCoordinator(matlabBridge);
const hasModelingBackend = modelingBackendAvailable();
const informationAvailable = computed(
  () => store.scene.value?.kind === 'crystal' && store.scene.value.sites.length > 0,
);
watch(informationAvailable, (available) => {
  if (!available) informationOpen.value = false;
});
const toggleInformationPanel = (): void => {
  if (!informationAvailable.value) {
    informationOpen.value = false;
    return;
  }
  settingsOpen.value = false;
  informationOpen.value = !informationOpen.value;
};
const blankCellDimensions = computed(() => {
  const scene = store.scene.value;
  if (!store.isBlankStructure.value || scene?.kind !== 'crystal') return '';
  return scene.structure.lattice.map((vector) => Math.hypot(...vector).toFixed(2)).join(' × ');
});
const atomHoverLabel = computed(() => {
  if (!atomHover.value) return '';
  const coordinates = atomHover.value.atom.position.map((value) => value.toFixed(3)).join(', ');
  return `${siteSpeciesLabel(atomHover.value.site)} (${coordinates}) site:${atomHover.value.site.siteIndex + 1}`;
});
const atomHoverStyle = computed(() => {
  if (!atomHover.value || !root.value) return {};
  const bounds = root.value.getBoundingClientRect();
  return {
    left: `${Math.min(Math.max(atomHover.value.clientX - bounds.left + 14, 10), bounds.width - 280)}px`,
    top: `${Math.min(Math.max(atomHover.value.clientY - bounds.top, 24), bounds.height - 24)}px`,
  };
});
const sceneDetails = computed(() => {
  const scene = store.scene.value;
  if (!scene) return ['Waiting for MATLAB structure data…'];
  if (store.isBlankStructure.value) {
    return [
      'No atoms yet',
      `${blankCellDimensions.value} Å unit cell`,
      'Use Modeling → Add Atom to begin',
    ];
  }
  const atomCount = atomCountLabel(scene, store.options);
  const bondCount = statistics.value?.bonds ?? scene.bondInstances.length;
  const ordered = scene.kind === 'crystal' ? scene.structure.isOrdered : scene.molecule.isOrdered;
  if (scene.kind === 'molecule') {
    const format = scene.molecule.inputFormat
      ? scene.molecule.inputFormat.toUpperCase()
      : 'Molecule';
    return [
      `${ordered ? 'Ordered' : 'Disordered'} · ${atomCount} atoms · ${bondCount} bonds`,
      `Charge ${scene.molecule.charge} · spin ${scene.molecule.spinMultiplicity}`,
      `${format} · ${scene.analysis.algorithm}`,
    ];
  }
  const rawCell = scene.analysis.parameters.cell;
  const cell =
    typeof rawCell === 'string' && rawCell
      ? `${rawCell.charAt(0).toUpperCase()}${rawCell.slice(1)} cell`
      : 'Input cell';
  return [
    `${ordered ? 'Ordered' : 'Disordered'} · ${scene.structure.siteCount} sites · ${atomCount} atoms`,
    `${bondCount} bonds · ${scene.analysis.algorithm}`,
    `${cell} · ${scene.structure.repeat.join(' × ')}`,
  ];
});

const themeStyle = computed(() => {
  const theme = themes[store.options.theme];
  return {
    '--viewer-background': store.options.background ?? theme.background,
    '--viewer-foreground': theme.foreground,
    '--viewer-muted': theme.muted,
    '--viewer-panel': theme.panel,
    '--viewer-panel-border': theme.panelBorder,
    '--viewer-accent': theme.accent,
    '--viewer-selection': theme.selection,
  };
});

const download = (href: string, filename: string): void => {
  const anchor = document.createElement('a');
  anchor.href = href;
  anchor.download = filename;
  anchor.click();
};

const downloadBlob = (blob: Blob, filename: string): void => {
  const href = URL.createObjectURL(blob);
  download(href, filename);
  window.setTimeout(() => URL.revokeObjectURL(href), 0);
};

const updateExportProgress = (progress: RenderExportProgress): void => {
  exportProgress.value = { ...progress, value: Math.min(progress.value * 0.94, 0.94) };
};

const saveExportBlob = async (blob: Blob, destination: ImageSaveDestination): Promise<void> => {
  const savedDirectly = await imageSaver.save(blob, destination, (progress) => {
    exportProgress.value = {
      stage: 'encoding',
      value: 0.94 + progress.progress * 0.06,
      label: 'Saving image…',
      detail: `Writing block ${progress.completedChunks} of ${progress.totalChunks}`,
    };
  });
  if (!savedDirectly) downloadBlob(blob, destination.filename);
};

const showProgressBeforeBlockingWork = async (): Promise<void> => {
  await nextTick();
  await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  // MATLAB's uihtml compositor may defer a frame produced in the same event
  // turn as an HTMLEvent callback. A short macrotask lets the progress layer
  // reach the screen before scene rebuilding or path tracing monopolizes WebGL.
  await new Promise<void>((resolve) => window.setTimeout(resolve, 32));
};

const clearHeroRetainedFrame = (): void => {
  if (!heroRetainedFrameUrl.value) return;
  URL.revokeObjectURL(heroRetainedFrameUrl.value);
  heroRetainedFrameUrl.value = '';
  if (heroExportStatus.value === 'saved') heroExportStatus.value = 'idle';
};

const retainHeroFrame = (blob: Blob): void => {
  clearHeroRetainedFrame();
  heroRetainedFrameUrl.value = URL.createObjectURL(blob);
};

const clearHeroTransientState = (): void => {
  if (autoRotating.value) {
    autoRotating.value = false;
    renderer.value?.setAutoRotation(false);
  }
  activeMeasurement.value = undefined;
  progressMeasurement.value = undefined;
  measurementError.value = '';
  activeMeasurementKind.value = undefined;
  measurementSelections.value = [];
  atomHover.value = undefined;
  atomContextMenu.value = undefined;
  modelingPending.value = false;
  modelingError.value = '';
  store.setSelection();
  renderer.value?.clearTransientOverlays();
};

const exportImage = async (format: ImageExportFormat): Promise<void> => {
  if (!renderer.value || imageExporting.value) return;
  const extension =
    format === 'jpeg'
      ? 'jpg'
      : format === 'tiff'
        ? 'tif'
        : format.startsWith('pdf-')
          ? 'pdf'
          : format;
  const suffix = format === 'pdf-vector' ? '-vector' : format === 'pdf-raster' ? '-raster' : '';
  const filename = `${store.formula.value || 'crystal'}${suffix}.${extension}`;
  let destination: ImageSaveDestination | undefined;
  imageExporting.value = true;
  try {
    destination = await imageSaver.choose(filename, format);
    if (!destination) return;
    rasterExporting.value = format !== 'svg' && format !== 'pdf-vector';
    if (rasterExporting.value) {
      exportProgress.value = {
        stage: 'preparing',
        value: 0.01,
        label: 'Starting high-quality export…',
        detail: 'Preparing the renderer',
      };
      await showProgressBeforeBlockingWork();
    }
    const blob = await renderer.value.exportImage(
      format,
      rasterExporting.value ? updateExportProgress : undefined,
    );
    await saveExportBlob(blob, destination);
  } catch (error) {
    imageSaver.cancel(destination);
    matlabBridge.emit('viewer:error', {
      requestId: store.scene.value?.requestId ?? '',
      code: 'IMAGE_EXPORT',
      message: error instanceof Error ? error.message : String(error),
    });
  } finally {
    rasterExporting.value = false;
    exportProgress.value = undefined;
    imageExporting.value = false;
  }
};

const exportHeroShot = async (scale: HeroExportScale = heroExportScale.value): Promise<void> => {
  if (
    !renderer.value ||
    imageExporting.value ||
    !heroShotActive.value ||
    store.options.theme !== 'gleamoe-premiror'
  ) {
    return;
  }
  heroExportScale.value = scale;
  const filename = `${store.formula.value || 'crystal'}-hero.png`;
  let destination: ImageSaveDestination | undefined;
  imageExporting.value = true;
  rasterExporting.value = true;
  heroExportStatus.value = 'rendering';
  exportProgress.value = {
    stage: 'preparing',
    value: 0.01,
    label: 'Choose where to save the Hero Shot…',
    detail: 'Rendering starts after the location is selected',
  };
  try {
    // Paint before asking MATLAB to open its blocking native file dialog. The
    // overlay is therefore already composited when the dialog closes.
    await showProgressBeforeBlockingWork();
    destination = await imageSaver.choose(filename, 'png');
    if (!destination) {
      heroExportStatus.value = 'idle';
      return;
    }
    matlabBridge.emit('viewer:bringToFront', { reason: 'hero-export' });
    exportProgress.value = {
      stage: 'preparing',
      value: 0.015,
      label: 'Starting Hero Shot export…',
      detail: 'Preparing the cinematic renderer',
    };
    await showProgressBeforeBlockingWork();
    const blob = await renderer.value.exportHeroShot(
      scale,
      updateExportProgress,
      heroProgressCanvas.value,
    );
    await saveExportBlob(blob, destination);
    retainHeroFrame(blob);
    heroExportStatus.value = 'saved';
  } catch (error) {
    imageSaver.cancel(destination);
    heroExportStatus.value = 'error';
    matlabBridge.emit('viewer:error', {
      requestId: store.scene.value?.requestId ?? '',
      code: 'HERO_SHOT_EXPORT',
      message: error instanceof Error ? error.message : String(error),
    });
  } finally {
    rasterExporting.value = false;
    exportProgress.value = undefined;
    imageExporting.value = false;
    if (heroExportStatus.value === 'rendering') heroExportStatus.value = 'idle';
    window.setTimeout(() => {
      if (heroExportStatus.value !== 'rendering') heroExportStatus.value = 'idle';
    }, 15_000);
  }
};

const toggleHeroShot = async (): Promise<void> => {
  if (!renderer.value || !store.scene.value || imageExporting.value) return;
  if (heroShotActive.value) {
    heroShotActive.value = false;
    clearHeroRetainedFrame();
    await renderer.value.setHeroShot(false, false);
    const restore = heroRestoreState;
    heroRestoreState = undefined;
    if (restore) {
      store.updateOptions(restore.options);
      await nextTick();
      renderer.value?.setCameraSnapshot(restore.camera);
      minimalUi.value = restore.minimalUi;
    }
    return;
  }

  heroRestoreState = {
    options: { ...store.options },
    camera: renderer.value.cameraSnapshot(),
    minimalUi: minimalUi.value,
  };
  clearHeroTransientState();
  clearHeroRetainedFrame();
  settingsOpen.value = false;
  informationOpen.value = false;
  minimalUi.value = true;
  store.updateOptions({
    ...store.options,
    theme: 'gleamoe-premiror',
    renderMode: 'fast',
    renderQuality: 'balanced',
  });
  await nextTick();
  heroShotActive.value = true;
  await renderer.value?.setHeroShot(true, true);
};

const exportScene = (): void => {
  if (!store.scene.value) return;
  const blob = new Blob([JSON.stringify(store.scene.value, null, 2)], {
    type: 'application/json',
  });
  const href = URL.createObjectURL(blob);
  download(href, `${store.formula.value || 'crystal'}-scene.json`);
  URL.revokeObjectURL(href);
};

const exportOfflineHtml = (): void => {
  const scene = store.scene.value;
  if (!scene || !renderer.value) return;
  try {
    const html = buildOfflineHtml(
      {
        scene,
        options: { ...store.options },
        camera: renderer.value.cameraSnapshot(),
      },
      store.formula.value || 'Atomic structure',
    );
    downloadBlob(offlineHtmlBlob(html), `${store.formula.value || 'crystal'}-offline.html`);
  } catch (error) {
    matlabBridge.emit('viewer:error', {
      requestId: scene.requestId,
      code: 'OFFLINE_HTML_EXPORT',
      message: error instanceof Error ? error.message : String(error),
    });
  }
};

const exportStructure = (format: string): void => {
  if (
    structureExporting.value ||
    !structureExportFormats.value.some((item) => item.format === format)
  ) {
    return;
  }
  structureExporting.value = true;
  structureExportError.value = '';
  matlabBridge.emit('viewer:exportStructure', {
    format,
    filename: store.formula.value || 'structure',
  });
};

const toggleFullscreen = async (): Promise<void> => {
  if (!root.value) return;
  if (document.fullscreenElement) await exitFullscreenIfActive();
  else await root.value.requestFullscreen();
};

const exitFullscreenForToolboxClose = async (): Promise<void> => {
  try {
    await exitFullscreenIfActive();
  } catch (error: unknown) {
    matlabBridge.emit('viewer:error', {
      requestId: store.scene.value?.requestId ?? '',
      code: 'FULLSCREEN_EXIT',
      message: error instanceof Error ? error.message : String(error),
    });
  } finally {
    matlabBridge.emit('viewer:fullscreenExitComplete');
  }
};

const toggleAutoRotation = (): void => {
  autoRotating.value = !autoRotating.value;
  renderer.value?.setAutoRotation(autoRotating.value);
};

const updateMeasurementAnnotations = (): void => {
  renderer.value?.setMeasurementAnnotations([
    ...(activeMeasurement.value ? [activeMeasurement.value.annotation] : []),
    ...(progressMeasurement.value ? [progressMeasurement.value] : []),
  ]);
};

const performMeasurement = (
  kind: MeasurementKind,
  selections = measurementSelections.value,
): void => {
  const scene = store.scene.value;
  if (!scene) return;
  progressMeasurement.value = undefined;
  measurementError.value = '';
  try {
    measurementSerial += 1;
    const record = measureScene(
      scene,
      kind,
      selections.map((selection) => selection.site.siteIndex),
      `measurement-${measurementSerial}`,
      selections.map((selection) => selection.atom),
    );
    const diagram = renderer.value?.projectMeasurementGeometry(record.annotation);
    activeMeasurement.value = diagram ? { ...record, diagram } : record;
    updateMeasurementAnnotations();
  } catch (error) {
    activeMeasurement.value = undefined;
    measurementError.value = error instanceof Error ? error.message : String(error);
    updateMeasurementAnnotations();
  }
};

const resetMeasurementResult = (): void => {
  activeMeasurement.value = undefined;
  progressMeasurement.value = undefined;
  measurementError.value = '';
  updateMeasurementAnnotations();
};

const closeMeasurementResult = (): void => {
  activeMeasurement.value = undefined;
  measurementError.value = '';
  updateMeasurementAnnotations();
};

const updateMeasurementProgress = (hover?: AtomHoverInfo): void => {
  const kind = activeMeasurementKind.value;
  const selected = measurementSelections.value;
  if (!kind) {
    progressMeasurement.value = undefined;
    updateMeasurementAnnotations();
    return;
  }
  const validHover =
    hover && !selected.some((selection) => selection.atom.id === hover.atom.id)
      ? hover.atom.position
      : undefined;
  progressMeasurement.value = measurementProgressAnnotation(
    kind,
    selected.map((selection) => selection.atom.position),
    validHover,
  );
  updateMeasurementAnnotations();
};

const stopMeasurement = (): void => {
  activeMeasurementKind.value = undefined;
  progressMeasurement.value = undefined;
  atomHover.value = undefined;
  measurementSelections.value = [];
  store.setSelection();
  renderer.value?.setMeasurementMode(false);
  updateMeasurementAnnotations();
};

const startMeasurement = (kind: MeasurementKind): void => {
  if (!store.scene.value || store.isBlankStructure.value) return;
  closeMeasurementResult();
  progressMeasurement.value = undefined;
  measurementSelections.value = [];
  store.setSelection();
  renderer.value?.clearMeasurementSelection();
  if (kind === 'cell') {
    performMeasurement(kind, []);
    return;
  }
  activeMeasurementKind.value = kind;
  atomHover.value = undefined;
  renderer.value?.setMeasurementMode(true);
  updateMeasurementAnnotations();
};

const handleRendererSelection: NonNullable<CrystalRendererCallbacks['onSelection']> = (
  selection,
  gesture,
) => {
  atomContextMenu.value = undefined;
  modelingPending.value = false;
  modelingError.value = '';
  const kind = activeMeasurementKind.value;
  if (!kind) {
    closeMeasurementResult();
    store.setSelection(selection, gesture);
    return;
  }
  if (!selection) {
    measurementSelections.value = [];
    store.setSelection();
    renderer.value?.clearMeasurementSelection();
    updateMeasurementProgress();
    return;
  }
  if (selection.kind !== 'atom' || !selection.site || !selection.atom) return;
  closeMeasurementResult();
  progressMeasurement.value = undefined;
  const existingIndex = measurementSelections.value.findIndex(
    (candidate) => candidate.atom.id === selection.atom!.id,
  );
  measurementSelections.value =
    existingIndex >= 0
      ? measurementSelections.value.filter((_, index) => index !== existingIndex)
      : [...measurementSelections.value, { atom: selection.atom, site: selection.site }];
  store.setSelection(selection);
  const selected = measurementSelections.value;
  if (selected.length === expectedSelectionCount(kind)) {
    performMeasurement(kind, selected);
    if (store.options.continuousMeasurement) {
      measurementSelections.value = [];
      store.setSelection();
      renderer.value?.clearMeasurementSelection();
      atomHover.value = undefined;
    } else {
      stopMeasurement();
    }
    return;
  }
  updateMeasurementProgress();
};

const handleAtomContextMenu: NonNullable<CrystalRendererCallbacks['onAtomContextMenu']> = (
  selection,
) => {
  modelingPending.value = false;
  modelingError.value = '';
  if (
    !selection?.site ||
    !selection.atom ||
    activeMeasurementKind.value ||
    store.status.loading ||
    store.scene.value?.kind !== 'crystal'
  ) {
    atomContextMenu.value = undefined;
    return;
  }
  atomContextMenu.value = {
    selection,
    x: selection.clientX,
    y: selection.clientY,
  };
};

const closeAtomContextMenu = (): void => {
  if (modelingPending.value) return;
  atomContextMenu.value = undefined;
  modelingError.value = '';
};

const selectSameElement = (symbol: string): void => {
  const scene = store.scene.value;
  const context = atomContextMenu.value;
  if (!context || !renderer.value || !scene) return;
  const selectedIds = renderer.value.selectAtomInstances(atomIdsForElement(scene, symbol));
  const selectedIdSet = new Set(selectedIds);
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  const selections = scene.atomInstances.flatMap((atom) => {
    const site = sites.get(atom.siteIndex);
    return selectedIdSet.has(atom.id) && site
      ? [
          {
            kind: 'atom' as const,
            id: atom.id,
            atom,
            site,
            clientX: context.x,
            clientY: context.y,
          },
        ]
      : [];
  });
  store.setAtomSelections(selections, context.selection.atom?.id);
  atomContextMenu.value = undefined;
  modelingError.value = '';
};

const requestContextModeling = (
  commandId: ContextModelingCommandId,
  parameters: ContextModelingParameters,
): void => {
  const scene = store.scene.value;
  if (!atomContextMenu.value || scene?.kind !== 'crystal' || !hasModelingBackend) return;
  const siteIndices = [...store.selectedSiteIndices.value];
  if (siteIndices.length === 0) return;
  modelingPending.value = true;
  modelingError.value = '';
  const request: ContextModelingRequest = {
    requestId: scene.requestId,
    commandId,
    siteIndices,
    parameters,
  };
  matlabBridge.emit('viewer:modelingCommandRequested', request);
};

const handleAtomHover = (value?: AtomHoverInfo): void => {
  atomHover.value = value;
  if (activeMeasurementKind.value) updateMeasurementProgress(value);
};

const applyOptions = (options: ViewerOptions): void => {
  store.updateOptions(options);
};

const runRendererWorkAfterPaint = async (message: string, work: () => void): Promise<void> => {
  rendererWorkSerial += 1;
  const serial = rendererWorkSerial;
  viewerWorkMessage.value = message;
  await nextTick();
  await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  if (serial !== rendererWorkSerial) return;
  try {
    work();
  } finally {
    if (serial === rendererWorkSerial) viewerWorkMessage.value = '';
  }
};

const handleShortcut = (event: KeyboardEvent): void => {
  const shortcut = viewerShortcutFor(event);
  if (!shortcut) return;
  event.preventDefault();
  if (shortcut === 'center-view') {
    clearHeroRetainedFrame();
    renderer.value?.centerView();
  } else minimalUi.value = !minimalUi.value;
};

const resetHeroCamera = (): void => {
  clearHeroRetainedFrame();
  renderer.value?.resetView();
};

const setHeroCameraAxis = (axis: CrystalCameraAxis): void => {
  clearHeroRetainedFrame();
  renderer.value?.setCameraAxis(axis);
};

onMounted(async () => {
  window.addEventListener('keydown', handleShortcut);
  await nextTick();
  if (!canvas.value) return;
  try {
    renderer.value = new CrystalRenderer(
      canvas.value,
      { ...store.options },
      {
        onSelection: handleRendererSelection,
        onAtomContextMenu: handleAtomContextMenu,
        onAtomHover: handleAtomHover,
        onCameraSettled: (snapshot) => {
          store.setCamera(snapshot);
          if (heroShotActive.value && !imageExporting.value) clearHeroRetainedFrame();
        },
        onStatistics: (value) => {
          statistics.value = value;
        },
        onError: (error) => {
          matlabBridge.emit('viewer:error', {
            requestId: store.scene.value?.requestId ?? '',
            code: 'WEBGL',
            message: error.message,
          });
        },
      },
    );
    if (store.scene.value) renderer.value.setScene(store.scene.value);
    store.markReady();
  } catch (error) {
    matlabBridge.emit('viewer:error', {
      requestId: store.scene.value?.requestId ?? '',
      code: 'RENDERER_INIT',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

const stopSceneWatch = watch(
  () => store.scene.value,
  (scene) => {
    if (scene && renderer.value) {
      atomContextMenu.value = undefined;
      modelingPending.value = false;
      modelingError.value = '';
      stopMeasurement();
      void runRendererWorkAfterPaint('Building structure graphics…', () => {
        renderer.value?.setScene(scene, true);
        resetMeasurementResult();
      });
    }
  },
);

const stopOptionsWatch = watch(
  store.options,
  () => {
    const nextOptions = { ...store.options };
    void runRendererWorkAfterPaint('Updating interactive preview…', () =>
      renderer.value?.setOptions(nextOptions),
    );
  },
  { deep: true },
);

const removeCommandListener = matlabBridge.on('viewer:command', (payload) => {
  if (typeof payload !== 'object' || payload === null) return;
  const command = (payload as { command?: string; axis?: CrystalCameraAxis }).command;
  if (command === 'reset') renderer.value?.resetView();
  if (command === 'axis') {
    const axis = (payload as { axis?: CrystalCameraAxis }).axis;
    if (axis) renderer.value?.setCameraAxis(axis);
  }
  if (command === 'camera') {
    const camera = (payload as { camera?: Parameters<CrystalRenderer['setCameraSnapshot']>[0] })
      .camera;
    if (camera) renderer.value?.setCameraSnapshot(camera);
  }
  if (command === 'screenshot') void exportImage('png');
  if (command === 'exit-fullscreen') void exitFullscreenForToolboxClose();
});

const removeExportFormatsListener = matlabBridge.on('structure:exportFormats', (payload) => {
  structureExportFormats.value = parseStructureExportFormats(payload);
});

const removeExportResultListener = matlabBridge.on('structure:exportResult', (payload) => {
  structureExporting.value = false;
  if (typeof payload !== 'object' || payload === null) return;
  const status = (payload as { status?: unknown }).status;
  const message = (payload as { message?: unknown }).message;
  if (status === 'error') {
    structureExportError.value =
      typeof message === 'string' ? message : 'Unable to export the structure file.';
  }
});

const removeModelingResultListener = matlabBridge.on('modeling:result', (payload) => {
  if (!isContextModelingResult(payload)) return;
  modelingPending.value = false;
  if (payload.status === 'success') {
    atomContextMenu.value = undefined;
    modelingError.value = '';
  } else {
    modelingError.value = payload.message || 'Unable to update the structure.';
  }
});

onBeforeUnmount(() => {
  rendererWorkSerial += 1;
  stopSceneWatch();
  stopOptionsWatch();
  removeCommandListener();
  removeExportFormatsListener();
  removeExportResultListener();
  removeModelingResultListener();
  imageSaver.dispose();
  clearHeroRetainedFrame();
  window.removeEventListener('keydown', handleShortcut);
  renderer.value?.dispose();
});
</script>

<template>
  <main
    ref="root"
    class="crystal-viewer"
    :class="[
      `theme-${store.options.theme}`,
      { 'minimal-ui': minimalUi, 'hero-shot': heroShotActive },
    ]"
    :data-minimal-ui="minimalUi ? 'true' : 'false'"
    :style="themeStyle"
  >
    <canvas
      ref="canvas"
      :aria-label="
        store.scene.value?.kind === 'molecule'
          ? 'Interactive molecule viewport'
          : 'Interactive crystal structure viewport'
      "
      @pointerdown="clearHeroRetainedFrame"
      @wheel.passive="clearHeroRetainedFrame"
    />

    <div v-if="heroShotActive && rasterExporting" class="hero-progress-surface" aria-hidden="true">
      <canvas ref="heroProgressCanvas" class="hero-progress-frame" />
      <div class="hero-progress-grid"></div>
    </div>

    <img
      v-if="heroShotActive && heroRetainedFrameUrl && !rasterExporting"
      class="hero-retained-frame"
      :src="heroRetainedFrameUrl"
      alt="Completed Hero Shot preview"
    />

    <AtomContextMenu
      v-if="atomContextMenu"
      :x="atomContextMenu.x"
      :y="atomContextMenu.y"
      :site="atomContextMenu.selection.site!"
      :selection-count="store.selectedAtomIds.value.length"
      :selected-site-count="store.selectedSiteIndices.value.length"
      :backend-available="hasModelingBackend"
      :pending="modelingPending"
      :error="modelingError"
      @close="closeAtomContextMenu"
      @command="requestContextModeling"
      @select-same-element="selectSameElement"
    />

    <section class="structure-card">
      <div class="eyebrow">
        {{ store.scene.value?.kind === 'molecule' ? 'Molecular structure' : 'Crystal structure' }}
      </div>
      <h1>{{ store.formula.value }}</h1>
      <div class="structure-details">
        <p v-for="detail in sceneDetails" :key="detail">{{ detail }}</p>
      </div>
    </section>

    <HeroToolbar
      v-if="heroShotActive"
      :crystal="store.scene.value?.kind === 'crystal'"
      :export-scale="heroExportScale"
      :exporting="imageExporting"
      @reset="resetHeroCamera"
      @axis="setHeroCameraAxis"
      @update:export-scale="heroExportScale = $event"
      @export="exportHeroShot"
      @exit="toggleHeroShot"
    />

    <ViewerToolbar
      v-else
      :settings-open="settingsOpen"
      :information-open="informationOpen"
      :information-available="informationAvailable"
      :crystal="store.scene.value?.kind === 'crystal'"
      :auto-rotating="autoRotating"
      :image-exporting="imageExporting"
      :structure-exporting="structureExporting"
      :structure-export-formats="structureExportFormats"
      :scene-available="!!store.scene.value && !store.isBlankStructure.value"
      :active-measurement-kind="activeMeasurementKind"
      @reset="renderer?.resetView()"
      @toggle-auto-rotation="toggleAutoRotation"
      @axis="renderer?.setCameraAxis($event)"
      @toggle-settings="
        informationOpen = false;
        settingsOpen = !settingsOpen;
      "
      @toggle-information="toggleInformationPanel"
      @export-image="exportImage"
      @export-scene="exportScene"
      @export-offline-html="exportOfflineHtml"
      @export-structure="exportStructure"
      @fullscreen="toggleFullscreen"
      @measure="startMeasurement"
      @stop-measurement="stopMeasurement"
    />

    <SettingsPanel
      v-if="settingsOpen && !heroShotActive"
      :model-value="{ ...store.options }"
      :scene="store.scene.value"
      :rebuild-phase="store.status.activityPhase"
      :rebuild-message="store.status.activityMessage"
      :rebuilding="store.status.loading"
      :image-exporting="imageExporting"
      :scene-available="!!store.scene.value && !store.isBlankStructure.value"
      @update:model-value="applyOptions"
      @toggle-hero-shot="toggleHeroShot"
      @rebuild="store.requestAnalysis"
      @close="settingsOpen = false"
    />

    <FractionalCoordinatesPanel
      v-if="informationOpen && informationAvailable"
      :scene="store.scene.value"
      @close="informationOpen = false"
    />

    <ElementLegend :scene="store.scene.value" :color-mode="store.options.colorMode" />
    <div
      v-if="viewerWorkMessage && !rasterExporting"
      class="viewer-work-progress"
      role="status"
      aria-live="polite"
    >
      <span>{{ viewerWorkMessage }}</span>
      <progress :aria-label="viewerWorkMessage"></progress>
    </div>
    <div
      v-if="rasterExporting && exportProgress"
      class="render-progress-overlay"
      role="status"
      aria-live="polite"
      aria-busy="true"
    >
      <div class="render-progress">
        <div class="render-progress-kicker">
          {{ heroExportStatus === 'rendering' ? 'HERO SHOT' : 'HIGH QUALITY EXPORT' }}
        </div>
        <div class="render-progress-heading">
          <span>{{ exportProgress.label }}</span>
          <strong>{{ Math.round(exportProgress.value * 100) }}%</strong>
        </div>
        <progress
          :value="exportProgress.value"
          max="1"
          :aria-label="`${exportProgress.label} ${Math.round(exportProgress.value * 100)}%`"
        ></progress>
        <span class="render-progress-detail">{{ exportProgress.detail }}</span>
        <span class="render-progress-note">Keep this window open while rendering completes</span>
      </div>
    </div>
    <div
      v-if="heroExportStatus === 'saved' || heroExportStatus === 'error'"
      class="hero-export-status"
      :class="`is-${heroExportStatus}`"
      role="status"
      aria-live="polite"
    >
      {{ heroExportStatus === 'saved' ? 'Hero Shot PNG saved' : 'Hero Shot export failed' }}
    </div>
    <SelectionInspector
      :selection="store.selection.value"
      :measurement="activeMeasurement"
      :measurement-error="measurementError"
      :measurement-kind="activeMeasurementKind"
      :measurement-selection-count="measurementSelections.length"
      @close-measurement="closeMeasurementResult"
    />
    <div
      v-if="atomHover && !minimalUi"
      class="atom-hover-tooltip"
      :style="atomHoverStyle"
      role="tooltip"
    >
      {{ atomHoverLabel }}
    </div>

    <WarningStack
      :warnings="store.warnings.value"
      :scope-key="store.scene.value?.requestId ?? ''"
    />

    <div v-if="store.status.error" class="error-banner" role="alert">
      {{ store.status.error }}
    </div>

    <div v-else-if="structureExportError" class="error-banner" role="alert">
      {{ structureExportError }}
    </div>

    <div v-if="statistics && store.options.showStatistics" class="performance-badge">
      {{ statistics.atoms }} atoms · {{ statistics.bonds }} bonds · {{ statistics.drawCalls }} draws
      · p95 {{ statistics.p95FrameMilliseconds.toFixed(1) }} ms
    </div>
  </main>
</template>
