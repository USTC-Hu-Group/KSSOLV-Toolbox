<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue';

import { matlabBridge } from './bridge/matlabBridge';
import ElementLegend from './components/ElementLegend.vue';
import SelectionInspector from './components/SelectionInspector.vue';
import SettingsPanel from './components/SettingsPanel.vue';
import ViewerToolbar from './components/ViewerToolbar.vue';
import WarningStack from './components/WarningStack.vue';
import { viewerShortcutFor } from './keyboard';
import {
  expectedSelectionCount,
  measurementProgressAnnotation,
  measureScene,
  type MeasurementKind,
  type MeasurementRecord,
} from './measurement';
import { buildOfflineHtml, offlineHtmlBlob } from './offlineExport';
import { CrystalRenderer, type CrystalRendererCallbacks } from './renderer/CrystalRenderer';
import type { CrystalCameraAxis } from './renderer/cameraAxis';
import type { ImageExportFormat } from './renderer/imageExport';
import type {
  AtomHoverInfo,
  AtomInstanceSpec,
  RendererStatistics,
  SiteSpec,
  ViewerOptions,
} from './scene/types';
import { useViewerStore } from './state/viewerStore';
import { parseStructureExportFormats, type StructureExportFormat } from './structureExport';
import { themes } from './themes/themes';

const root = ref<HTMLElement>();
const canvas = ref<HTMLCanvasElement>();
const settingsOpen = ref(false);
const minimalUi = ref(false);
const autoRotating = ref(false);
const imageExporting = ref(false);
const structureExporting = ref(false);
const structureExportFormats = ref<StructureExportFormat[]>([]);
const structureExportError = ref('');
const atomHover = shallowRef<AtomHoverInfo>();
const activeMeasurement = shallowRef<MeasurementRecord>();
const progressMeasurement = shallowRef<ReturnType<typeof measurementProgressAnnotation>>();
const measurementError = ref('');
const activeMeasurementKind = ref<MeasurementKind>();
const measurementSelections = shallowRef<Array<{ atom: AtomInstanceSpec; site: SiteSpec }>>([]);
let measurementSerial = 0;
// Three.js owns mutable, non-configurable matrix properties and must never be
// wrapped in Vue's deep reactive proxy.
const renderer = shallowRef<CrystalRenderer>();
const statistics = ref<RendererStatistics>();
const store = useViewerStore();
const blankCellDimensions = computed(() => {
  const scene = store.scene.value;
  if (!store.isBlankStructure.value || scene?.kind !== 'crystal') return '';
  return scene.structure.lattice.map((vector) => Math.hypot(...vector).toFixed(2)).join(' × ');
});
const atomHoverLabel = computed(() => {
  if (!atomHover.value) return '';
  const coordinates = atomHover.value.atom.position.map((value) => value.toFixed(3)).join(', ');
  return `${atomHover.value.site.label} (${coordinates}) site:${atomHover.value.site.siteIndex + 1}`;
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
  const atomCount = statistics.value?.atoms ?? scene.atomInstances.length;
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

const exportImage = async (format: ImageExportFormat): Promise<void> => {
  if (!renderer.value || imageExporting.value) return;
  imageExporting.value = true;
  try {
    const blob = await renderer.value.exportImage(format);
    const extension =
      format === 'jpeg'
        ? 'jpg'
        : format === 'tiff'
          ? 'tif'
          : format.startsWith('pdf-')
            ? 'pdf'
            : format;
    const suffix = format === 'pdf-vector' ? '-vector' : format === 'pdf-raster' ? '-raster' : '';
    downloadBlob(blob, `${store.formula.value || 'crystal'}${suffix}.${extension}`);
  } catch (error) {
    matlabBridge.emit('viewer:error', {
      requestId: store.scene.value?.requestId ?? '',
      code: 'IMAGE_EXPORT',
      message: error instanceof Error ? error.message : String(error),
    });
  } finally {
    imageExporting.value = false;
  }
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
  if (document.fullscreenElement) await document.exitFullscreen();
  else await root.value.requestFullscreen();
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

const handleAtomHover = (value?: AtomHoverInfo): void => {
  atomHover.value = value;
  if (activeMeasurementKind.value) updateMeasurementProgress(value);
};

const applyOptions = (options: ViewerOptions): void => {
  store.updateOptions(options);
};

const handleShortcut = (event: KeyboardEvent): void => {
  const shortcut = viewerShortcutFor(event);
  if (!shortcut) return;
  event.preventDefault();
  if (shortcut === 'center-view') renderer.value?.centerView();
  else minimalUi.value = !minimalUi.value;
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
        onAtomHover: handleAtomHover,
        onCameraSettled: store.setCamera,
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
      stopMeasurement();
      renderer.value.setScene(scene, true);
      resetMeasurementResult();
    }
  },
);

const stopOptionsWatch = watch(
  store.options,
  () => renderer.value?.setOptions({ ...store.options }),
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

onBeforeUnmount(() => {
  stopSceneWatch();
  stopOptionsWatch();
  removeCommandListener();
  removeExportFormatsListener();
  removeExportResultListener();
  window.removeEventListener('keydown', handleShortcut);
  renderer.value?.dispose();
});
</script>

<template>
  <main
    ref="root"
    class="crystal-viewer"
    :class="[`theme-${store.options.theme}`, { 'minimal-ui': minimalUi }]"
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

    <ViewerToolbar
      :settings-open="settingsOpen"
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
      @toggle-settings="settingsOpen = !settingsOpen"
      @export-image="exportImage"
      @export-scene="exportScene"
      @export-offline-html="exportOfflineHtml"
      @export-structure="exportStructure"
      @fullscreen="toggleFullscreen"
      @measure="startMeasurement"
      @stop-measurement="stopMeasurement"
    />

    <SettingsPanel
      v-if="settingsOpen"
      :model-value="{ ...store.options }"
      :scene="store.scene.value"
      :rebuild-phase="store.status.activityPhase"
      :rebuild-message="store.status.activityMessage"
      :rebuilding="store.status.loading"
      @update:model-value="applyOptions"
      @rebuild="store.requestAnalysis"
      @close="settingsOpen = false"
    />

    <ElementLegend :scene="store.scene.value" :color-mode="store.options.colorMode" />
    <SelectionInspector
      :selection="store.selection.value"
      :measurement="activeMeasurement"
      :measurement-error="measurementError"
      :measurement-kind="activeMeasurementKind"
      :measurement-selection-count="measurementSelections.length"
      @close-measurement="closeMeasurementResult"
    />
    <div
      v-if="
        (store.options.theme === 'materials' || activeMeasurementKind) && atomHover && !minimalUi
      "
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
