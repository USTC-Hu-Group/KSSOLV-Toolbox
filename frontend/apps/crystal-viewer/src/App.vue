<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue';

import { matlabBridge } from './bridge/matlabBridge';
import ElementLegend from './components/ElementLegend.vue';
import SelectionInspector from './components/SelectionInspector.vue';
import SettingsPanel from './components/SettingsPanel.vue';
import ViewerToolbar from './components/ViewerToolbar.vue';
import { viewerShortcutFor } from './keyboard';
import { CrystalRenderer } from './renderer/CrystalRenderer';
import type { CrystalCameraAxis } from './renderer/cameraAxis';
import type { AtomHoverInfo, RendererStatistics, ViewerOptions } from './scene/types';
import { useViewerStore } from './state/viewerStore';
import { themes } from './themes/themes';

const root = ref<HTMLElement>();
const canvas = ref<HTMLCanvasElement>();
const settingsOpen = ref(false);
const minimalUi = ref(false);
const atomHover = shallowRef<AtomHoverInfo>();
// Three.js owns mutable, non-configurable matrix properties and must never be
// wrapped in Vue's deep reactive proxy.
const renderer = shallowRef<CrystalRenderer>();
const statistics = ref<RendererStatistics>();
const store = useViewerStore();
const atomHoverLabel = computed(() => {
  if (!atomHover.value) return '';
  const coordinates = atomHover.value.atom.position.map((value) => value.toFixed(3)).join(', ');
  return `${atomHover.value.site.label} (${coordinates}) index:${atomHover.value.site.siteIndex}`;
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

const saveScreenshot = (): void => {
  if (!renderer.value) return;
  download(renderer.value.screenshot(), `${store.formula.value || 'crystal'}.png`);
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

const toggleFullscreen = async (): Promise<void> => {
  if (!root.value) return;
  if (document.fullscreenElement) await document.exitFullscreen();
  else await root.value.requestFullscreen();
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
        onSelection: store.setSelection,
        onAtomHover: (value) => {
          atomHover.value = value;
        },
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
    if (scene && renderer.value) renderer.value.setScene(scene, true);
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
  if (command === 'screenshot') saveScreenshot();
});

onBeforeUnmount(() => {
  stopSceneWatch();
  stopOptionsWatch();
  removeCommandListener();
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
      @reset="renderer?.resetView()"
      @axis="renderer?.setCameraAxis($event)"
      @toggle-settings="settingsOpen = !settingsOpen"
      @screenshot="saveScreenshot"
      @export-scene="exportScene"
      @fullscreen="toggleFullscreen"
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
    <SelectionInspector :selection="store.selection.value" />
    <div
      v-if="store.options.theme === 'materials' && atomHover && !minimalUi"
      class="atom-hover-tooltip"
      :style="atomHoverStyle"
      role="tooltip"
    >
      {{ atomHoverLabel }}
    </div>

    <div v-if="store.warnings.value.length" class="warning-stack" aria-live="polite">
      <div v-for="warning in store.warnings.value" :key="warning.code" :class="warning.severity">
        <strong>{{ warning.code }}</strong>
        {{ warning.message }}
      </div>
    </div>

    <div v-if="store.status.error" class="error-banner" role="alert">
      {{ store.status.error }}
    </div>

    <div v-if="statistics && store.options.showStatistics" class="performance-badge">
      {{ statistics.atoms }} atoms · {{ statistics.bonds }} bonds · {{ statistics.drawCalls }} draws
      · p95 {{ statistics.p95FrameMilliseconds.toFixed(1) }} ms
    </div>
  </main>
</template>
