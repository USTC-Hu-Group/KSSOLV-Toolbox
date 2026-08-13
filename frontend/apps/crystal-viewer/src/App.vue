<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue';

import { matlabBridge } from './bridge/matlabBridge';
import AtomContextMenu from './components/AtomContextMenu.vue';
import ElementLegend from './components/ElementLegend.vue';
import FractionalCoordinatesPanel from './components/FractionalCoordinatesPanel.vue';
import HeroToolbar from './components/HeroToolbar.vue';
import SelectionInspector from './components/SelectionInspector.vue';
import ShortcutHelpDialog from './components/ShortcutHelpDialog.vue';
import SettingsPanel from './components/SettingsPanel.vue';
import ViewerToolbar from './components/ViewerToolbar.vue';
import WarningStack from './components/WarningStack.vue';
import { atomIdsForElement, connectedSiteIndices, siteSpeciesLabel } from './elementSelection';
import { directAdsorbateFragments, type AdsorbateFragment } from './adsorbateFragments';
import { exitFullscreenIfActive } from './fullscreen';
import { ImageSaveCoordinator, type ImageSaveDestination } from './imageSave';
import {
  registerViewerEscapeReleaseListener,
  registerViewerShortcutListener,
  releaseViewerControlFocus,
  nextContentZoomPercent,
  viewerShortcutFor,
} from './keyboard';
import { atomIdsInPolygon, rectanglePolygon, type ScreenPoint } from './selectionGeometry';
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
  modelingResultAwaitsScene,
  type ContextModelingCommandId,
  type ContextModelingParameters,
  type ContextModelingRequest,
} from './modeling';
import {
  adsorbateDraftIssue,
  adsorbateHostBondLength,
  applyConstructionBondLength,
  beginSketchDraft,
  compatibleMouseTransformFor,
  constructionBondLength,
  createAdsorbateDraft,
  crystalSurfaceNormal,
  liveGeometryValue,
  moveAdsorbateAnchor,
  rotateAdsorbateAroundHostBond,
  sketchDraftIssue,
  sketchDraftLength,
  updateSketchDraft,
  type AdsorbateDraft,
  type AdsorbateDraftStage,
  type CoordinateMode,
  type ModelingAxis,
  type ModelingTool,
  type SketchDraft,
} from './modelingInteraction';
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
  AtomicSceneSpec,
  CameraSnapshot,
  RendererStatistics,
  SiteSpec,
  Vector3Tuple,
  ViewerOptions,
} from './scene/types';
import { shouldAutoFitAfterConnectivity } from './sceneFraming';
import { useViewerStore } from './state/viewerStore';
import { parseStructureExportFormats, type StructureExportFormat } from './structureExport';
import { themes } from './themes/themes';
import { shouldShowReciprocalAxes } from './toolbarState';

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
let pendingMeasurementEdit:
  | {
      kind: 'distance' | 'angle' | 'dihedral';
      siteIndices: number[];
      value: number;
      referenceCoordinates: Array<[number, number, number]>;
    }
  | undefined;
const atomContextMenu = shallowRef<{
  selection: NonNullable<Parameters<NonNullable<CrystalRendererCallbacks['onAtomContextMenu']>>[0]>;
  x: number;
  y: number;
}>();
const modelingPending = ref(false);
const modelingError = ref('');
const modelingTool = ref<ModelingTool>('orbit');
const modelingAxis = ref<ModelingAxis>('screen');
const coordinateMode = ref<CoordinateMode>('cartesian');
const transformSnap = ref(0.1);
const sketchElement = ref('C');
const sketchBondOrder = ref(1);
const sketchFormalCharge = ref(0);
const sketchHybridization = ref<'auto' | 'sp' | 'sp2' | 'sp3'>('auto');
const selectedAdsorbateId = ref(directAdsorbateFragments[0]?.id ?? '');
const hostAdsorbateLength = ref(2);
const adsorbateDraft = shallowRef<AdsorbateDraft>();
const sketchDraft = shallowRef<SketchDraft>();
const shortcutHelpOpen = ref(false);
const shortcutHelpInitialTier = ref<'common' | 'advanced'>('common');
const viewerLocale = ref<'en-US' | 'zh-CN'>('en-US');
const contentZoomPercent = ref(100);
const interactionPoints = shallowRef<ScreenPoint[]>([]);
const interactionActive = ref(false);
const interactionAdditive = ref(false);
const compatibleMouseTransformActive = ref(false);
const activeInteractionTool = ref<ModelingTool>();
let interactionPointerId: number | undefined;
let interactionStart: ScreenPoint = { x: 0, y: 0 };
let pendingProgrammaticSiteSelection: number[] | undefined;
let suppressCompatibleContextMenu = false;
let adsorbateGesture: 'anchor' | 'orient' | 'rotate' | undefined;
let adsorbateGestureStart: AdsorbateDraft | undefined;
const previewTranslation = ref<[number, number, number]>([0, 0, 0]);
const previewAngleDegrees = ref(0);
let measurementSerial = 0;
let rendererWorkSerial = 0;
let heroRestoreState:
  { options: ViewerOptions; camera: CameraSnapshot; minimalUi: boolean } | undefined;
// Three.js owns mutable, non-configurable matrix properties and must never be
// wrapped in Vue's deep reactive proxy.
const renderer = shallowRef<CrystalRenderer>();
const statistics = ref<RendererStatistics>();
const store = useViewerStore();
const showReciprocalAxes = computed(() => shouldShowReciprocalAxes(store.scene.value?.kind));
const imageSaver = new ImageSaveCoordinator(matlabBridge);
const hasModelingBackend = modelingBackendAvailable();
const availableAdsorbateFragments = computed<AdsorbateFragment[]>(() => {
  const userFragments = store.scene.value?.modeling?.adsorbateFragments ?? [];
  const combined = [...directAdsorbateFragments, ...userFragments];
  return combined.filter(
    (fragment, index) => combined.findIndex((candidate) => candidate.id === fragment.id) === index,
  );
});
const selectedAdsorbateFragment = computed(
  () =>
    availableAdsorbateFragments.value.find(
      (fragment) => fragment.id === selectedAdsorbateId.value,
    ) ?? availableAdsorbateFragments.value[0]!,
);
watch(availableAdsorbateFragments, (fragments) => {
  if (!fragments.some((fragment) => fragment.id === selectedAdsorbateId.value)) {
    selectedAdsorbateId.value = fragments[0]?.id ?? '';
  }
});
const adsorbateOtherAtoms = computed<Vector3Tuple[]>(() => {
  const scene = store.scene.value;
  const draft = adsorbateDraft.value;
  if (!scene || !draft) return [];
  return scene.sites
    .filter((site) => site.siteIndex !== draft.anchorSiteIndex)
    .map((site) => site.cartesian);
});
const adsorbateIssue = computed(() =>
  adsorbateDraft.value ? adsorbateDraftIssue(adsorbateDraft.value, adsorbateOtherAtoms.value) : '',
);
const liveMeasurementReadout = computed(() => {
  const kind = activeMeasurementKind.value;
  if (!(kind === 'distance' || kind === 'angle' || kind === 'dihedral')) return '';
  const points = measurementSelections.value.map((selection) => selection.atom.position);
  const hover = atomHover.value?.atom.position;
  if (
    hover &&
    !measurementSelections.value.some((selection) => selection.atom.id === atomHover.value?.atom.id)
  ) {
    points.push(hover);
  }
  const value = liveGeometryValue(kind, points);
  if (value === undefined) return '';
  return kind === 'distance'
    ? `Live distance ${value.toFixed(5)} Å`
    : `Live ${kind} ${value.toFixed(3)}°`;
});
const selectedGeometryReadout = computed(() => {
  if (activeMeasurementKind.value || interactionActive.value) return '';
  const scene = store.scene.value;
  const selected = store.selectedAtomIds.value;
  if (!scene || selected.length < 2 || selected.length > 4) return '';
  const atoms = new Map(scene.atomInstances.map((atom) => [atom.id, atom]));
  const points = selected.flatMap((id) => {
    const atom = atoms.get(id);
    return atom ? [atom.position] : [];
  });
  const kind = points.length === 2 ? 'distance' : points.length === 3 ? 'angle' : 'dihedral';
  const value = liveGeometryValue(kind, points);
  if (value === undefined) return '';
  return kind === 'distance'
    ? `Distance ${value.toFixed(5)} Å`
    : `${kind === 'angle' ? 'Angle' : 'Dihedral'} ${value.toFixed(3)}°`;
});
const informationAvailable = computed(
  () => store.scene.value?.kind === 'crystal' && store.scene.value.sites.length > 0,
);
const interactionOverlayPoints = computed(() => {
  const bounds = root.value?.getBoundingClientRect();
  if (!bounds) return '';
  return interactionPoints.value
    .map((point) => `${point.x - bounds.left},${point.y - bounds.top}`)
    .join(' ');
});
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
    if (scene.kind === 'molecule') {
      return [
        'No atoms yet',
        'Molecular sketch document',
        'Choose Sketch and click to place an atom',
      ];
    }
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
  const zoom = contentZoomPercent.value / 100;
  return {
    '--viewer-background': store.options.background ?? theme.background,
    '--viewer-foreground': theme.foreground,
    '--viewer-muted': theme.muted,
    '--viewer-panel': theme.panel,
    '--viewer-panel-border': theme.panelBorder,
    '--viewer-accent': theme.accent,
    '--viewer-selection': theme.selection,
    width: `${100 / zoom}%`,
    height: `${100 / zoom}%`,
    transform: `scale(${zoom})`,
    transformOrigin: 'top left',
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

const editedMeasurementSelections = (
  scene: AtomicSceneSpec,
  edit: NonNullable<typeof pendingMeasurementEdit>,
): Array<{ atom: AtomInstanceSpec; site: SiteSpec }> => {
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  const fixed = edit.siteIndices.slice(0, -1).map((siteIndex, index) => {
    const site = sites.get(siteIndex);
    const candidates = scene.atomInstances.filter((atom) => atom.siteIndex === siteIndex);
    if (!site || candidates.length === 0) throw new Error(`Site ${siteIndex + 1} is unavailable.`);
    const target = edit.referenceCoordinates[index];
    const atom = candidates.reduce((best, candidate) => {
      const distance = candidate.position.reduce(
        (sum, value, axis) => sum + (value - target[axis]) ** 2,
        0,
      );
      const bestDistance = best.position.reduce(
        (sum, value, axis) => sum + (value - target[axis]) ** 2,
        0,
      );
      return distance < bestDistance ? candidate : best;
    });
    return { atom, site };
  });
  const movingIndex = edit.siteIndices[edit.siteIndices.length - 1];
  const movingSite = sites.get(movingIndex);
  const movingCandidates = scene.atomInstances.filter((atom) => atom.siteIndex === movingIndex);
  if (!movingSite || movingCandidates.length === 0) {
    throw new Error(`Site ${movingIndex + 1} is unavailable.`);
  }
  const errorFor = (candidate: AtomInstanceSpec): number => {
    const selections = [...fixed, { atom: candidate, site: movingSite }];
    const measurement = measureScene(
      scene,
      edit.kind,
      edit.siteIndices,
      'edited-measurement-candidate',
      selections.map((selection) => selection.atom),
    );
    const difference = (measurement.numericValue ?? Number.POSITIVE_INFINITY) - edit.value;
    return edit.kind === 'dihedral'
      ? Math.abs(((difference + 180) % 360) - 180)
      : Math.abs(difference);
  };
  const movingAtom = movingCandidates.reduce((best, candidate) =>
    errorFor(candidate) < errorFor(best) ? candidate : best,
  );
  return [...fixed, { atom: movingAtom, site: movingSite }];
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
  if (!selection?.site || !selection.atom || activeMeasurementKind.value || store.status.loading) {
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

const selectConnectedSites = (
  siteIndex: number,
  focusAtomId?: string,
  clientX = 0,
  clientY = 0,
): void => {
  const scene = store.scene.value;
  if (!scene || !renderer.value) return;
  const siteIndices = new Set(connectedSiteIndices(scene, siteIndex));
  const selectedIds = renderer.value.selectAtomInstances(
    scene.atomInstances.filter((atom) => siteIndices.has(atom.siteIndex)).map((atom) => atom.id),
  );
  const selectedIdSet = new Set(selectedIds);
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  store.setAtomSelections(
    scene.atomInstances.flatMap((atom) => {
      const site = sites.get(atom.siteIndex);
      return selectedIdSet.has(atom.id) && site
        ? [
            {
              kind: 'atom' as const,
              id: atom.id,
              atom,
              site,
              clientX,
              clientY,
            },
          ]
        : [];
    }),
    focusAtomId,
  );
};

const selectConnectedComponent = (siteIndex: number): void => {
  const context = atomContextMenu.value;
  if (!context) return;
  selectConnectedSites(siteIndex, context.selection.atom?.id, context.x, context.y);
  atomContextMenu.value = undefined;
};

const handleCanvasDoubleClick = (event: MouseEvent): void => {
  if (
    event.button !== 0 ||
    event.shiftKey ||
    event.ctrlKey ||
    event.metaKey ||
    activeMeasurementKind.value ||
    modelingTool.value !== 'orbit'
  ) {
    return;
  }
  const selection = store.selection.value;
  const siteIndex = selection?.site?.siteIndex ?? selection?.bond?.fromSiteIndex;
  if (siteIndex === undefined) return;
  event.preventDefault();
  selectConnectedSites(siteIndex, selection?.atom?.id, event.clientX, event.clientY);
};

const selectSites = (siteIndices: readonly number[]): void => {
  const scene = store.scene.value;
  if (!scene || !renderer.value) {
    pendingProgrammaticSiteSelection = [...siteIndices];
    return;
  }
  pendingProgrammaticSiteSelection = undefined;
  const requested = new Set(siteIndices);
  const selectedIds = renderer.value.selectAtomInstances(
    scene.atomInstances.filter((atom) => requested.has(atom.siteIndex)).map((atom) => atom.id),
  );
  const selectedIdSet = new Set(selectedIds);
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  store.setAtomSelections(
    scene.atomInstances.flatMap((atom) => {
      const site = sites.get(atom.siteIndex);
      return selectedIdSet.has(atom.id) && site
        ? [{ kind: 'atom' as const, id: atom.id, atom, site, clientX: 0, clientY: 0 }]
        : [];
    }),
  );
};

const selectAtomIds = (atomIds: readonly string[], additive = false): void => {
  const scene = store.scene.value;
  if (!scene || !renderer.value) return;
  const requested = new Set(additive ? [...store.selectedAtomIds.value, ...atomIds] : atomIds);
  const selectedIds = renderer.value.selectAtomInstances([...requested]);
  const selectedIdSet = new Set(selectedIds);
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  store.setAtomSelections(
    scene.atomInstances.flatMap((atom) => {
      const site = sites.get(atom.siteIndex);
      return selectedIdSet.has(atom.id) && site
        ? [{ kind: 'atom' as const, id: atom.id, atom, site, clientX: 0, clientY: 0 }]
        : [];
    }),
  );
};

const cloneAdsorbateDraft = (draft: AdsorbateDraft): AdsorbateDraft => ({
  ...draft,
  host: [...draft.host],
  coordinates: draft.coordinates.map((coordinate) => [...coordinate]),
});

const renderAdsorbateDraft = (): void => {
  const draft = adsorbateDraft.value;
  if (!draft) {
    renderer.value?.clearAdsorbatePreview();
    return;
  }
  renderer.value?.previewAdsorbate(
    draft.host,
    draft.fragment.species,
    draft.coordinates,
    draft.fragment.bonds,
    draft.fragment.anchorAtomIndex,
    adsorbateIssue.value === '',
  );
};

const updateAdsorbateHostBondLength = (): void => {
  const draft = adsorbateDraft.value;
  if (!draft) return;
  const anchor = draft.coordinates[draft.fragment.anchorAtomIndex]!;
  const vector: Vector3Tuple = [
    anchor[0] - draft.host[0],
    anchor[1] - draft.host[1],
    anchor[2] - draft.host[2],
  ];
  const magnitude = Math.max(Math.hypot(...vector), 1e-12);
  const target = vector.map(
    (component, index) => draft.host[index]! + (component / magnitude) * hostAdsorbateLength.value,
  ) as Vector3Tuple;
  adsorbateDraft.value = moveAdsorbateAnchor(draft, target);
  renderAdsorbateDraft();
};

const cancelAdsorbateDraft = (): void => {
  adsorbateDraft.value = undefined;
  adsorbateGesture = undefined;
  adsorbateGestureStart = undefined;
  renderer.value?.clearAdsorbatePreview();
};

watch(selectedAdsorbateId, () => {
  hostAdsorbateLength.value = selectedAdsorbateFragment.value.defaultHostBondLength;
  cancelAdsorbateDraft();
});

const renderSketchDraft = (): void => {
  const draft = sketchDraft.value;
  if (!draft) {
    renderer.value?.clearSketchPreview();
    return;
  }
  renderer.value?.previewSketch(
    draft.start,
    draft.end,
    currentSketchDraftIssue(draft) === '',
    draft.targetSiteIndex === undefined,
  );
};

const sketchDefaultBondLength = (anchorSiteIndex: number): number | undefined => {
  const scene = store.scene.value;
  if (!scene) return undefined;
  const host = scene.sites
    .find((site) => site.siteIndex === anchorSiteIndex)
    ?.species.find((species) => species.occupancy > 0)?.symbol;
  if (!host) return undefined;
  return constructionBondLength(
    scene.modeling?.constructionBonds ?? [],
    host,
    sketchElement.value,
    sketchBondOrder.value,
  );
};

const currentSketchDraftIssue = (draft: SketchDraft): string => {
  const idealLength =
    draft.anchorSiteIndex === undefined
      ? undefined
      : sketchDefaultBondLength(draft.anchorSiteIndex);
  const minimumLength = idealLength === undefined ? 0.6 : Math.max(0.6, idealLength * 0.65);
  return sketchDraftIssue(draft, minimumLength);
};

const cancelSketchDraft = (): void => {
  sketchDraft.value = undefined;
  renderer.value?.clearSketchPreview();
};

const setModelingTool = (tool: ModelingTool): void => {
  if (modelingTool.value === 'adsorbate' && tool !== 'adsorbate') cancelAdsorbateDraft();
  if (modelingTool.value === 'sketch' && tool !== 'sketch') cancelSketchDraft();
  cancelInteraction();
  modelingTool.value = tool;
};

const finishPointerInteraction = (): void => {
  interactionActive.value = false;
  activeInteractionTool.value = undefined;
  interactionPointerId = undefined;
  interactionPoints.value = [];
};

const snapVector = (value: [number, number, number], step: number): [number, number, number] =>
  step > 0
    ? (value.map((component) => Math.round(component / step) * step) as [number, number, number])
    : value;

const transformAxisVector = (): [number, number, number] => {
  if (!renderer.value) return [0, 0, 1];
  return modelingAxis.value === 'screen'
    ? renderer.value.cameraViewAxis()
    : renderer.value.modelingAxisVector(modelingAxis.value, coordinateMode.value);
};

const cancelInteraction = (): void => {
  renderer.value?.clearAtomTransformPreview();
  if (modelingTool.value === 'adsorbate') cancelAdsorbateDraft();
  if (modelingTool.value === 'sketch') cancelSketchDraft();
  interactionActive.value = false;
  compatibleMouseTransformActive.value = false;
  activeInteractionTool.value = undefined;
  interactionPointerId = undefined;
  interactionPoints.value = [];
  previewTranslation.value = [0, 0, 0];
  previewAngleDegrees.value = 0;
};

const beginPointerInteraction = (event: PointerEvent, tool: ModelingTool): void => {
  atomContextMenu.value = undefined;
  interactionActive.value = true;
  activeInteractionTool.value = tool;
  interactionAdditive.value = event.shiftKey || event.ctrlKey || event.metaKey;
  interactionPointerId = event.pointerId;
  interactionStart = { x: event.clientX, y: event.clientY };
  interactionPoints.value = [interactionStart];
  (event.currentTarget as HTMLElement).setPointerCapture?.(event.pointerId);
};

const eventTargetsModelingControl = (event: PointerEvent): boolean =>
  event
    .composedPath()
    .some((target) => target instanceof HTMLElement && target.classList.contains('sketch-palette'));

const releaseModelingControlFocus = (): void => {
  const active = document.activeElement;
  if (active instanceof HTMLElement && active.closest('.sketch-palette')) active.blur();
};

const handleModelingPointerDown = (event: PointerEvent): void => {
  // MATLAB's embedded Chromium can still bubble pointer events from native form
  // controls even when Vue's `.stop` modifier is present.  Do not let those
  // events become canvas gestures or call preventDefault(), otherwise selects
  // and numeric inputs cannot receive focus in the production WebWindow.
  if (eventTargetsModelingControl(event)) return;
  releaseModelingControlFocus();

  if (modelingTool.value === 'adsorbate') {
    if (!renderer.value || store.scene.value?.kind !== 'crystal' || modelingPending.value) return;
    if (event.button === 2 && adsorbateDraft.value?.stage === 'ready') {
      event.preventDefault();
      suppressCompatibleContextMenu = true;
      adsorbateGesture = 'rotate';
      adsorbateGestureStart = cloneAdsorbateDraft(adsorbateDraft.value);
      beginPointerInteraction(event, 'adsorbate');
      return;
    }
    if (event.button !== 0) return;
    event.preventDefault();
    if (!adsorbateDraft.value) {
      const picked = renderer.value.pickAtomAt(event.clientX, event.clientY);
      if (!picked) {
        modelingError.value = 'Start the adsorbate gesture on a surface atom.';
        return;
      }
      const normal = crystalSurfaceNormal(store.scene.value.structure.lattice);
      adsorbateDraft.value = createAdsorbateDraft(
        selectedAdsorbateFragment.value,
        picked.site.siteIndex,
        picked.atom.position,
        normal,
        hostAdsorbateLength.value,
      );
      adsorbateGesture = 'anchor';
      modelingError.value = '';
      renderAdsorbateDraft();
    } else {
      adsorbateGesture = 'orient';
    }
    adsorbateGestureStart = cloneAdsorbateDraft(adsorbateDraft.value);
    beginPointerInteraction(event, 'adsorbate');
    return;
  }
  if (modelingTool.value === 'sketch') {
    if (
      event.button !== 0 ||
      !renderer.value ||
      store.scene.value?.kind !== 'molecule' ||
      modelingPending.value
    ) {
      return;
    }
    event.preventDefault();
    const picked = renderer.value.pickAtomAt(event.clientX, event.clientY);
    const pointerEnd =
      picked?.atom.position ??
      renderer.value.pointOnViewPlane(event.clientX, event.clientY, [0, 0, 0]);
    const defaultLength = picked ? sketchDefaultBondLength(picked.site.siteIndex) : undefined;
    const end =
      picked && defaultLength
        ? applyConstructionBondLength(
            picked.atom.position,
            pointerEnd,
            defaultLength,
            renderer.value.cameraRightAxis(),
          )
        : pointerEnd;
    sketchDraft.value = beginSketchDraft(
      end,
      {
        element: sketchElement.value,
        bondOrder: sketchBondOrder.value,
        formalCharge: sketchFormalCharge.value,
        hybridization: sketchHybridization.value,
      },
      picked ? { position: picked.atom.position, siteIndex: picked.site.siteIndex } : undefined,
    );
    renderSketchDraft();
    beginPointerInteraction(event, 'sketch');
    return;
  }
  if (event.button !== 0 || modelingTool.value === 'orbit') return;
  if (
    (modelingTool.value === 'move' || modelingTool.value === 'rotate') &&
    store.selectedAtomIds.value.length === 0
  ) {
    return;
  }
  event.preventDefault();
  beginPointerInteraction(event, modelingTool.value);
};

const handleModelingPointerMove = (event: PointerEvent): void => {
  if (!interactionActive.value || interactionPointerId !== event.pointerId) return;
  event.preventDefault();
  const tool = activeInteractionTool.value ?? modelingTool.value;
  const start = interactionStart;
  const current = { x: event.clientX, y: event.clientY };
  if (tool === 'adsorbate' && adsorbateDraft.value && adsorbateGestureStart && renderer.value) {
    const initial = adsorbateGestureStart;
    const normal =
      store.scene.value?.kind === 'crystal'
        ? crystalSurfaceNormal(store.scene.value.structure.lattice)
        : ([0, 0, 1] as Vector3Tuple);
    if (adsorbateGesture === 'anchor') {
      let anchor: Vector3Tuple;
      if (event.altKey) {
        const initialLength = adsorbateHostBondLength(initial);
        const targetLength = Math.max(0.35, initialLength - (current.y - start.y) * 0.01);
        const direction = normal;
        anchor = [
          initial.host[0] + direction[0] * targetLength,
          initial.host[1] + direction[1] * targetLength,
          initial.host[2] + direction[2] * targetLength,
        ];
      } else {
        const pointerPoint = renderer.value.pointOnViewPlane(
          event.clientX,
          event.clientY,
          initial.host,
        );
        anchor =
          Math.hypot(
            pointerPoint[0] - initial.host[0],
            pointerPoint[1] - initial.host[1],
            pointerPoint[2] - initial.host[2],
          ) >= 0.35
            ? pointerPoint
            : initial.coordinates[initial.fragment.anchorAtomIndex]!;
      }
      adsorbateDraft.value = { ...moveAdsorbateAnchor(initial, anchor), stage: 'anchor' };
    } else if (adsorbateGesture === 'orient' || adsorbateGesture === 'rotate') {
      adsorbateDraft.value = {
        ...rotateAdsorbateAroundHostBond(initial, (current.x - start.x) * 0.5),
        stage: adsorbateGesture === 'rotate' ? 'ready' : 'orient',
      };
    }
    renderAdsorbateDraft();
    return;
  }
  if (tool === 'sketch' && sketchDraft.value && renderer.value) {
    const draft = sketchDraft.value;
    const picked = renderer.value.pickAtomAt(event.clientX, event.clientY);
    const target = picked && picked.site.siteIndex !== draft.anchorSiteIndex ? picked : undefined;
    const anchor = draft.start ?? [0, 0, 0];
    const pointerEnd = target
      ? target.atom.position
      : renderer.value.pointOnViewPlane(event.clientX, event.clientY, anchor);
    const defaultLength =
      draft.anchorSiteIndex === undefined
        ? undefined
        : sketchDefaultBondLength(draft.anchorSiteIndex);
    sketchDraft.value = updateSketchDraft(
      draft,
      !target && draft.start && defaultLength
        ? applyConstructionBondLength(
            draft.start,
            pointerEnd,
            defaultLength,
            renderer.value.cameraRightAxis(),
          )
        : pointerEnd,
      target?.site.siteIndex,
    );
    renderSketchDraft();
    return;
  }
  if (tool === 'box') {
    interactionPoints.value = rectanglePolygon(start, current);
    return;
  }
  if (tool === 'lasso') {
    const previous = interactionPoints.value[interactionPoints.value.length - 1];
    if (Math.hypot(current.x - previous.x, current.y - previous.y) >= 3) {
      interactionPoints.value = [...interactionPoints.value, current];
    }
    return;
  }
  if (tool === 'move') {
    previewTranslation.value = snapVector(
      renderer.value?.translationForPointerDelta(
        current.x - start.x,
        current.y - start.y,
        modelingAxis.value,
        coordinateMode.value,
      ) ?? [0, 0, 0],
      transformSnap.value,
    );
    renderer.value?.previewAtomTransform(store.selectedAtomIds.value, previewTranslation.value);
    return;
  }
  if (tool === 'rotate') {
    const rawAngle = (current.x - start.x) * 0.5;
    previewAngleDegrees.value =
      transformSnap.value > 0
        ? Math.round(rawAngle / transformSnap.value) * transformSnap.value
        : rawAngle;
    renderer.value?.previewAtomTransform(store.selectedAtomIds.value, [0, 0, 0], {
      axis: transformAxisVector(),
      angleDegrees: previewAngleDegrees.value,
      anchor: renderer.value.selectionAnchor(store.selectedAtomIds.value),
    });
  }
};

const handleModelingPointerUp = (event: PointerEvent): void => {
  if (!interactionActive.value || interactionPointerId !== event.pointerId) return;
  const tool = activeInteractionTool.value ?? modelingTool.value;
  if (tool === 'adsorbate' && adsorbateDraft.value) {
    (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
    if (adsorbateGesture === 'anchor') {
      hostAdsorbateLength.value = adsorbateHostBondLength(adsorbateDraft.value);
    }
    const stage: AdsorbateDraftStage = adsorbateGesture === 'anchor' ? 'orient' : 'ready';
    adsorbateDraft.value = { ...adsorbateDraft.value, stage };
    adsorbateGesture = undefined;
    adsorbateGestureStart = undefined;
    finishPointerInteraction();
    renderAdsorbateDraft();
    return;
  }
  const polygon = interactionPoints.value;
  const atomIds = [...store.selectedAtomIds.value];
  const axis = transformAxisVector();
  const anchor = renderer.value?.selectionAnchor(atomIds) ?? [0, 0, 0];
  const translation = previewTranslation.value;
  const angleDegrees = previewAngleDegrees.value;
  const completedSketch = sketchDraft.value ? { ...sketchDraft.value } : undefined;
  cancelInteraction();
  if (tool === 'sketch') {
    const scene = store.scene.value;
    if (
      !scene ||
      scene.kind !== 'molecule' ||
      !completedSketch ||
      currentSketchDraftIssue(completedSketch)
    ) {
      return;
    }
    if (
      completedSketch.anchorSiteIndex !== undefined &&
      completedSketch.targetSiteIndex !== undefined
    ) {
      requestModeling(
        'add_bond',
        [completedSketch.anchorSiteIndex, completedSketch.targetSiteIndex],
        { bondOrder: completedSketch.bondOrder },
      );
      return;
    }
    requestModeling(
      'sketch_atom',
      completedSketch.anchorSiteIndex === undefined ? [] : [completedSketch.anchorSiteIndex],
      {
        species: completedSketch.element,
        coordinates: completedSketch.end,
        connectTo:
          completedSketch.anchorSiteIndex === undefined ? 0 : completedSketch.anchorSiteIndex + 1,
        bondOrder: completedSketch.bondOrder,
        formalCharge: completedSketch.formalCharge,
        hybridization: completedSketch.hybridization,
        aromatic: completedSketch.aromatic,
      },
    );
    return;
  }
  if (tool === 'box' || tool === 'lasso') {
    if (polygon.length >= 3 && renderer.value) {
      selectAtomIds(
        atomIdsInPolygon(renderer.value.projectedAtoms(), polygon),
        interactionAdditive.value,
      );
    }
    return;
  }
  if (tool === 'move' && translation.some((value) => Math.abs(value) > 1e-12)) {
    requestSelectedModeling('translate_atoms', {
      vector: translation,
      fractional: false,
    });
  } else if (tool === 'rotate' && Math.abs(angleDegrees) > 1e-12) {
    requestSelectedModeling('rotate_atoms', {
      angleDegrees,
      axis,
      anchor,
    });
  }
};

const stopCompatiblePointerEvent = (event: PointerEvent): void => {
  event.preventDefault();
  event.stopImmediatePropagation();
};

const handleCanvasPointerDown = (event: PointerEvent): void => {
  suppressCompatibleContextMenu = false;
  if (modelingTool.value === 'move' || modelingTool.value === 'rotate') {
    if (
      event.button !== 0 ||
      heroShotActive.value ||
      modelingPending.value ||
      !hasModelingBackend ||
      store.selectedAtomIds.value.length === 0
    ) {
      return;
    }
    stopCompatiblePointerEvent(event);
    focusCanvas(event);
    beginPointerInteraction(event, modelingTool.value);
    return;
  }
  const tool = compatibleMouseTransformFor(event);
  if (
    !tool ||
    heroShotActive.value ||
    modelingTool.value !== 'orbit' ||
    activeMeasurementKind.value ||
    modelingPending.value ||
    !hasModelingBackend ||
    store.selectedAtomIds.value.length === 0
  ) {
    return;
  }
  stopCompatiblePointerEvent(event);
  clearHeroRetainedFrame();
  compatibleMouseTransformActive.value = true;
  suppressCompatibleContextMenu = event.button === 2;
  beginPointerInteraction(event, tool);
};

const handleCanvasPointerMove = (event: PointerEvent): void => {
  const directTransform =
    interactionActive.value &&
    (activeInteractionTool.value === 'move' || activeInteractionTool.value === 'rotate');
  if (!compatibleMouseTransformActive.value && !directTransform) return;
  stopCompatiblePointerEvent(event);
  handleModelingPointerMove(event);
};

const handleCanvasPointerUp = (event: PointerEvent): void => {
  const directTransform =
    interactionActive.value &&
    (activeInteractionTool.value === 'move' || activeInteractionTool.value === 'rotate');
  if (!compatibleMouseTransformActive.value && !directTransform) return;
  stopCompatiblePointerEvent(event);
  (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
  handleModelingPointerUp(event);
};

const handleCanvasPointerCancel = (event: PointerEvent): void => {
  const directTransform =
    interactionActive.value &&
    (activeInteractionTool.value === 'move' || activeInteractionTool.value === 'rotate');
  if (!compatibleMouseTransformActive.value && !directTransform) return;
  stopCompatiblePointerEvent(event);
  cancelInteraction();
};

const focusCanvas = (event: PointerEvent): void => {
  (event.currentTarget as HTMLCanvasElement).focus({ preventScroll: true });
  clearHeroRetainedFrame();
};

const handleCanvasContextMenu = (event: MouseEvent): void => {
  if (!suppressCompatibleContextMenu) return;
  suppressCompatibleContextMenu = false;
  event.preventDefault();
  event.stopImmediatePropagation();
};

const requestSelectedModeling = (
  commandId: ContextModelingCommandId,
  parameters: ContextModelingParameters,
): void => {
  const siteIndices = [...store.selectedSiteIndices.value];
  if (siteIndices.length === 0) return;
  requestModeling(commandId, siteIndices, parameters);
};

const requestModeling = (
  commandId: ContextModelingCommandId,
  siteIndices: number[],
  parameters: ContextModelingParameters,
): void => {
  const scene = store.scene.value;
  if (!scene || !hasModelingBackend) return;
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

const commitAdsorbateDraft = (): void => {
  const draft = adsorbateDraft.value;
  if (!draft || draft.stage !== 'ready' || adsorbateIssue.value) return;
  requestModeling('place_adsorbate', [draft.anchorSiteIndex], {
    adsorbateName: draft.fragment.label,
    adsorbateSpecies: draft.fragment.species,
    adsorbateCoordinates: draft.coordinates,
    adsorbateBonds: draft.fragment.bonds.map(([first, second, order]) => [
      first + 1,
      second + 1,
      order,
    ]),
    anchorAtomIndices: [draft.fragment.anchorAtomIndex + 1],
    minimumDistance: 0.35,
  });
  cancelAdsorbateDraft();
};

const editMeasurement = (request: {
  kind: 'distance' | 'angle' | 'dihedral';
  siteIndices: number[];
  value: number;
  scope: 'atom' | 'subtree' | 'fragment';
  referenceCoordinates: Array<[number, number, number]>;
}): void => {
  pendingMeasurementEdit = {
    kind: request.kind,
    siteIndices: [...request.siteIndices],
    value: request.value,
    referenceCoordinates: request.referenceCoordinates.map((point) => [...point]),
  };
  requestModeling(`set_${request.kind}`, request.siteIndices, {
    value: request.value,
    scope: request.scope,
    referenceCoordinates: request.referenceCoordinates,
  });
};

const requestContextModeling = (
  commandId: ContextModelingCommandId,
  parameters: ContextModelingParameters,
): void => {
  if (!atomContextMenu.value) return;
  requestSelectedModeling(commandId, parameters);
};

const selectAllAtoms = (): void => {
  const scene = store.scene.value;
  if (!scene || !renderer.value) return;
  const selectedIds = renderer.value.selectAtomInstances(
    scene.atomInstances.map((atom) => atom.id),
  );
  const selectedIdSet = new Set(selectedIds);
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  store.setAtomSelections(
    scene.atomInstances.flatMap((atom) => {
      const site = sites.get(atom.siteIndex);
      return selectedIdSet.has(atom.id) && site
        ? [{ kind: 'atom' as const, id: atom.id, atom, site, clientX: 0, clientY: 0 }]
        : [];
    }),
  );
};

const clearAtomSelection = (): void => {
  renderer.value?.selectAtomInstances([]);
  store.setSelection();
  atomContextMenu.value = undefined;
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

const reportSceneRendered = (scene: AtomicSceneSpec, startedAt: number): void => {
  requestAnimationFrame(() => {
    matlabBridge.emit('viewer:sceneRendered', {
      requestId: scene.requestId,
      atomCount: scene.atomInstances.length,
      bondCount: scene.bondInstances.length,
      elapsedMilliseconds: performance.now() - startedAt,
    });
  });
};

const handleShortcut = (event: KeyboardEvent): void => {
  const editableTarget =
    event.target instanceof HTMLElement &&
    event.target.matches('input, select, textarea, button, [role="textbox"]');
  if (
    !editableTarget &&
    event.key === 'Enter' &&
    modelingTool.value === 'adsorbate' &&
    adsorbateDraft.value?.stage === 'ready'
  ) {
    event.preventDefault();
    commitAdsorbateDraft();
    return;
  }
  const shortcut = viewerShortcutFor(event);
  if (!shortcut) return;
  event.preventDefault();
  if (shortcut === 'center-view') {
    clearHeroRetainedFrame();
    renderer.value?.centerView();
  } else if (shortcut === 'toggle-minimal-ui') {
    minimalUi.value = !minimalUi.value;
  } else if (shortcut === 'select-all-atoms') {
    selectAllAtoms();
  } else if (shortcut === 'clear-selection') {
    if (interactionActive.value || modelingTool.value !== 'orbit') {
      cancelInteraction();
      modelingTool.value = 'orbit';
    } else {
      clearAtomSelection();
    }
  } else if (shortcut === 'delete-selection') {
    requestSelectedModeling('delete_atoms', {});
  } else if (shortcut === 'box-select') {
    setModelingTool('box');
  } else if (shortcut === 'lasso-select') {
    setModelingTool('lasso');
  } else if (shortcut === 'move-selection' && store.selectedAtomIds.value.length > 0) {
    setModelingTool('move');
  } else if (shortcut === 'rotate-selection' && store.selectedAtomIds.value.length > 0) {
    setModelingTool('rotate');
  } else if (shortcut === 'sketch-molecule' && store.scene.value?.kind === 'molecule') {
    setModelingTool('sketch');
  } else if (shortcut === 'sketch-adsorbate' && store.scene.value?.kind === 'crystal') {
    setModelingTool('adsorbate');
  } else if (shortcut === 'axis-x' || shortcut === 'axis-y' || shortcut === 'axis-z') {
    modelingAxis.value = shortcut.slice(-1) as ModelingAxis;
  } else if (shortcut === 'show-shortcuts') {
    shortcutHelpOpen.value = true;
  } else if (shortcut === 'content-zoom-in') {
    contentZoomPercent.value = nextContentZoomPercent(contentZoomPercent.value, 'in');
  } else if (shortcut === 'content-zoom-out') {
    contentZoomPercent.value = nextContentZoomPercent(contentZoomPercent.value, 'out');
  } else if (shortcut === 'content-zoom-reset') {
    contentZoomPercent.value = nextContentZoomPercent(contentZoomPercent.value, 'reset');
  } else {
    const scene = store.scene.value;
    if (scene && hasModelingBackend) {
      matlabBridge.emit('viewer:historyCommand', {
        requestId: scene.requestId,
        command: shortcut,
      });
    }
  }
};

const handleEscapeRelease = (event: KeyboardEvent): void => {
  if (event.key !== 'Escape' || (!interactionActive.value && modelingTool.value === 'orbit')) {
    return;
  }
  // WKWebView's native <select> can consume Escape on keydown. The keyup
  // fallback preserves the one-press cancellation contract in that case.
  event.preventDefault();
  cancelInteraction();
  modelingTool.value = 'orbit';
};

const resetHeroCamera = (): void => {
  clearHeroRetainedFrame();
  renderer.value?.resetView();
};

const setHeroCameraAxis = (axis: CrystalCameraAxis): void => {
  clearHeroRetainedFrame();
  renderer.value?.setCameraAxis(axis);
};

let removeShortcutListener = (): void => undefined;
let removeEscapeReleaseListener = (): void => undefined;

onMounted(async () => {
  removeShortcutListener = registerViewerShortcutListener(window, handleShortcut);
  removeEscapeReleaseListener = registerViewerEscapeReleaseListener(window, handleEscapeRelease);
  await nextTick();
  if (!canvas.value) return;
  // The store safely queues an incoming scene until CrystalRenderer exists.
  // Announce bridge readiness first so MATLAB scene compilation overlaps the
  // remaining WebGL initialization instead of running strictly afterwards.
  store.markReady();
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
    if (store.scene.value) {
      const scene = store.scene.value;
      const startedAt = performance.now();
      renderer.value.setScene(scene);
      reportSceneRendered(scene, startedAt);
    }
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
  (scene, previousScene) => {
    if (scene && renderer.value) {
      const autoFitAfterConnectivity = shouldAutoFitAfterConnectivity(previousScene, scene);
      cancelAdsorbateDraft();
      atomContextMenu.value = undefined;
      modelingPending.value = false;
      modelingError.value = '';
      stopMeasurement();
      void runRendererWorkAfterPaint('Building structure graphics…', () => {
        const startedAt = performance.now();
        renderer.value?.setScene(scene, true);
        if (autoFitAfterConnectivity) {
          clearHeroRetainedFrame();
          renderer.value?.centerView();
        }
        reportSceneRendered(scene, startedAt);
        resetMeasurementResult();
        if (pendingMeasurementEdit) {
          const edit = pendingMeasurementEdit;
          pendingMeasurementEdit = undefined;
          try {
            performMeasurement(edit.kind, editedMeasurementSelections(scene, edit));
          } catch (error) {
            measurementError.value = error instanceof Error ? error.message : String(error);
          }
        }
        if (pendingProgrammaticSiteSelection) {
          selectSites(pendingProgrammaticSiteSelection);
        }
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
  if (command === 'open-shortcut-help') {
    const tier = (payload as { tier?: unknown }).tier;
    const locale = (payload as { locale?: unknown }).locale;
    viewerLocale.value = typeof locale === 'string' && locale.startsWith('zh') ? 'zh-CN' : 'en-US';
    shortcutHelpInitialTier.value = tier === 'advanced' ? 'advanced' : 'common';
    shortcutHelpOpen.value = true;
  }
  if (command === 'set-content-zoom') {
    const percent = Number((payload as { percent?: unknown }).percent);
    if ([75, 100, 125, 150, 175, 200].includes(percent)) contentZoomPercent.value = percent;
  }
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
  if (command === 'select-sites') {
    const siteIndices = (payload as { siteIndices?: unknown }).siteIndices;
    if (
      Array.isArray(siteIndices) &&
      siteIndices.every((index) => Number.isInteger(index) && Number(index) >= 0)
    ) {
      selectSites(siteIndices.map(Number));
    }
  }
  if (command === 'benchmark-direct-manipulation') {
    const requestToken = (payload as { requestToken?: unknown }).requestToken;
    const samples = (payload as { samples?: unknown }).samples;
    // Avoid a re-entrant CEF -> MATLAB event while MATLAB is still inside
    // sendEventToHTMLSource; uihtml may otherwise drop the immediate reply.
    window.setTimeout(() => {
      try {
        const result = renderer.value?.benchmarkDirectManipulation(
          typeof samples === 'number' ? samples : 30,
        );
        matlabBridge.emit(
          'viewer:selection',
          JSON.stringify({
            requestToken: typeof requestToken === 'string' ? requestToken : '',
            kind: 'benchmark',
            status: 'success',
            ...result,
          }),
        );
      } catch (error) {
        matlabBridge.emit(
          'viewer:selection',
          JSON.stringify({
            requestToken: typeof requestToken === 'string' ? requestToken : '',
            kind: 'benchmark',
            status: 'error',
            message: error instanceof Error ? error.message : String(error),
          }),
        );
      }
    }, 0);
  }
  if (command === 'screenshot') void exportImage('png');
  if (command === 'exit-fullscreen') void exitFullscreenForToolboxClose();
});

const removeLocaleListener = matlabBridge.on('viewer:locale', (payload) => {
  const locale =
    typeof payload === 'object' && payload !== null
      ? (payload as { locale?: unknown }).locale
      : undefined;
  viewerLocale.value = typeof locale === 'string' && locale.startsWith('zh') ? 'zh-CN' : 'en-US';
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
  if (modelingResultAwaitsScene(payload)) {
    atomContextMenu.value = undefined;
    modelingError.value = '';
  } else {
    modelingPending.value = false;
    pendingMeasurementEdit = undefined;
    modelingError.value = payload.message || 'Unable to update the structure.';
  }
});

onBeforeUnmount(() => {
  rendererWorkSerial += 1;
  stopSceneWatch();
  stopOptionsWatch();
  removeCommandListener();
  removeLocaleListener();
  removeExportFormatsListener();
  removeExportResultListener();
  removeModelingResultListener();
  imageSaver.dispose();
  clearHeroRetainedFrame();
  removeShortcutListener();
  removeEscapeReleaseListener();
  renderer.value?.dispose();
});
</script>

<template>
  <main
    ref="root"
    class="crystal-viewer"
    :class="[
      `theme-${store.options.theme}`,
      {
        'minimal-ui': minimalUi,
        'hero-shot': heroShotActive,
        'content-zoomed': contentZoomPercent > 100,
        'content-zoom-high': contentZoomPercent >= 175,
      },
    ]"
    :data-minimal-ui="minimalUi ? 'true' : 'false'"
    :style="themeStyle"
  >
    <canvas
      ref="canvas"
      tabindex="0"
      :aria-label="
        store.scene.value?.kind === 'molecule'
          ? 'Interactive molecule viewport'
          : 'Interactive crystal structure viewport'
      "
      @dblclick="handleCanvasDoubleClick"
      @pointerdown.capture="handleCanvasPointerDown"
      @pointerdown="focusCanvas"
      @pointermove.capture="handleCanvasPointerMove"
      @pointerup.capture="handleCanvasPointerUp"
      @pointercancel.capture="handleCanvasPointerCancel"
      @contextmenu.capture="handleCanvasContextMenu"
      @wheel.passive="clearHeroRetainedFrame"
    />

    <div
      v-if="compatibleMouseTransformActive && interactionActive"
      class="transform-readout compatible-transform-readout"
    >
      <template v-if="activeInteractionTool === 'move'">
        Δ {{ previewTranslation.map((value) => value.toFixed(3)).join(', ') }} Å
      </template>
      <template v-else>
        {{ previewAngleDegrees.toFixed(1) }}° about {{ modelingAxis.toUpperCase() }}
      </template>
    </div>

    <output
      v-if="liveMeasurementReadout || selectedGeometryReadout"
      class="live-geometry-readout"
      aria-live="polite"
    >
      {{ liveMeasurementReadout || selectedGeometryReadout }}
    </output>

    <output v-if="contentZoomPercent !== 100" class="content-zoom-readout" aria-live="polite">
      UI {{ contentZoomPercent }}% ·
      {{ viewerLocale === 'zh-CN' ? '⌘/Ctrl+0 重置' : '⌘/Ctrl+0 reset' }}
    </output>

    <div
      v-if="(modelingTool === 'move' || modelingTool === 'rotate') && !interactionActive"
      class="modeling-mode-indicator"
      role="status"
    >
      {{ modelingTool === 'move' ? 'Move selection' : 'Rotate selection' }} · drag in viewport · Esc
      cancel
    </div>

    <div
      v-if="!heroShotActive && modelingTool !== 'orbit'"
      class="modeling-interaction-layer"
      :data-tool="modelingTool"
      @pointerdown="handleModelingPointerDown"
      @pointermove="handleModelingPointerMove"
      @pointerup="handleModelingPointerUp"
      @pointercancel="cancelInteraction"
      @contextmenu.prevent
    >
      <div
        v-if="modelingTool === 'adsorbate'"
        class="sketch-palette adsorbate-palette"
        role="group"
        aria-label="Adsorbate fragment"
        @pointerdown.stop
        @pointerup.stop
        @click.stop
      >
        <label>
          Fragment
          <select
            v-model="selectedAdsorbateId"
            aria-label="Adsorbate fragment"
            @change="releaseViewerControlFocus"
          >
            <option
              v-for="fragment in availableAdsorbateFragments"
              :key="fragment.id"
              :value="fragment.id"
            >
              {{ fragment.label }} · {{ fragment.formula }}
            </option>
          </select>
        </label>
        <label>
          Host bond
          <input
            v-model.number="hostAdsorbateLength"
            aria-label="Host adsorbate bond length"
            type="number"
            min="0.35"
            max="8"
            step="0.01"
            @change="
              updateAdsorbateHostBondLength();
              releaseViewerControlFocus($event);
            "
          />
        </label>
        <output v-if="adsorbateDraft" class="sketch-palette-readout">
          {{ adsorbateDraft.fragment.formula }} · {{ adsorbateDraft.stage }} ·
          {{ adsorbateHostBondLength(adsorbateDraft).toFixed(3) }} Å
          <template v-if="adsorbateIssue"> · {{ adsorbateIssue }}</template>
        </output>
        <button
          v-if="adsorbateDraft?.stage === 'ready'"
          type="button"
          class="sketch-palette-action"
          :disabled="Boolean(adsorbateIssue) || modelingPending"
          @click="commitAdsorbateDraft"
        >
          Apply
        </button>
      </div>
      <div
        v-if="modelingTool === 'sketch'"
        class="sketch-palette"
        role="group"
        aria-label="Sketch chemistry"
        @pointerdown.stop
        @pointerup.stop
        @click.stop
      >
        <label>
          Element
          <select
            v-model="sketchElement"
            aria-label="Sketch element"
            @change="releaseViewerControlFocus"
          >
            <option
              v-for="element in ['H', 'B', 'C', 'N', 'O', 'F', 'P', 'S', 'Cl', 'Br', 'I']"
              :key="element"
            >
              {{ element }}
            </option>
          </select>
        </label>
        <label>
          Bond
          <select
            v-model.number="sketchBondOrder"
            aria-label="Sketch bond order"
            @change="releaseViewerControlFocus"
          >
            <option :value="1">Single</option>
            <option :value="2">Double</option>
            <option :value="3">Triple</option>
            <option :value="1.5">Aromatic</option>
          </select>
        </label>
        <label>
          Hybridization
          <select
            v-model="sketchHybridization"
            aria-label="Sketch hybridization"
            @change="releaseViewerControlFocus"
          >
            <option value="auto">Auto</option>
            <option value="sp">sp</option>
            <option value="sp2">sp²</option>
            <option value="sp3">sp³</option>
          </select>
        </label>
        <label>
          Charge
          <input
            v-model.number="sketchFormalCharge"
            aria-label="Sketch formal charge"
            type="number"
            min="-4"
            max="4"
            step="1"
            @change="releaseViewerControlFocus"
          />
        </label>
        <output v-if="sketchDraft" class="sketch-palette-readout">
          {{ sketchDraft.stage.replace('-', ' ') }}
          <template v-if="sketchDraftLength(sketchDraft) !== undefined">
            · {{ sketchDraftLength(sketchDraft)?.toFixed(3) }} Å
          </template>
          <template v-if="currentSketchDraftIssue(sketchDraft)">
            · {{ currentSketchDraftIssue(sketchDraft) }}</template
          >
        </output>
      </div>
      <svg v-if="interactionActive && (modelingTool === 'box' || modelingTool === 'lasso')">
        <polygon :points="interactionOverlayPoints" />
      </svg>
      <div v-if="interactionActive && modelingTool === 'move'" class="transform-readout">
        Δ {{ previewTranslation.map((value) => value.toFixed(3)).join(', ') }} Å
      </div>
      <div v-if="interactionActive && modelingTool === 'rotate'" class="transform-readout">
        {{ previewAngleDegrees.toFixed(1) }}° about {{ modelingAxis.toUpperCase() }}
      </div>
      <div
        v-if="modelingTool === 'adsorbate' && adsorbateDraft"
        class="transform-readout adsorbate-readout"
        :class="{ invalid: Boolean(adsorbateIssue) }"
      >
        Host–{{ adsorbateDraft.fragment.species[adsorbateDraft.fragment.anchorAtomIndex] }}
        {{ adsorbateHostBondLength(adsorbateDraft).toFixed(3) }} Å ·
        {{ adsorbateDraft.fragment.formula }}
        <span v-if="adsorbateIssue"> · {{ adsorbateIssue }}</span>
      </div>
    </div>

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
      @select-connected="selectConnectedComponent"
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
      :crystal="showReciprocalAxes"
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

    <ShortcutHelpDialog
      v-if="shortcutHelpOpen"
      :key="`${viewerLocale}-${shortcutHelpInitialTier}`"
      :initial-tier="shortcutHelpInitialTier"
      :locale="viewerLocale"
      @close="shortcutHelpOpen = false"
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
      @edit-measurement="editMeasurement"
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
      :class="{
        'warning-stack--modeling': modelingTool === 'sketch' || modelingTool === 'adsorbate',
      }"
      :warnings="store.warnings.value"
      :scope-key="store.scene.value?.requestId ?? ''"
      :timeout-milliseconds="5000"
      @locate="selectSites"
    />

    <div v-if="store.status.error" class="error-banner" role="alert">
      {{ store.status.error }}
    </div>

    <div v-else-if="structureExportError" class="error-banner" role="alert">
      {{ structureExportError }}
    </div>

    <div v-else-if="modelingError" class="error-banner" role="alert">
      {{ modelingError }}
    </div>

    <div v-if="statistics && store.options.showStatistics" class="performance-badge">
      {{ statistics.atoms }} atoms · {{ statistics.bonds }} bonds · {{ statistics.drawCalls }} draws
      · p95 {{ statistics.p95FrameMilliseconds.toFixed(1) }} ms
    </div>
  </main>
</template>
