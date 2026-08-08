<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';

import { matlabBridge } from '@kssolv/matlab-bridge';

import HistogramPanel from './components/HistogramPanel.vue';
import type {
  HistogramRangeBound,
  HistogramThresholdSign,
} from './components/histogramInteraction';
import SettingsPanel from './components/SettingsPanel.vue';
import ViewerToolbar from './components/ViewerToolbar.vue';
import {
  densityDisplayFor,
  toDisplayedDensity,
  type DensityDisplayUnit,
} from './densityUnits';
import { createVolumeRenderer } from './renderer/createVolumeRenderer';
import { sliceExportStem, volumeExportStem } from './renderer/exportNames';
import { decodeValues } from './renderer/gridMath';
import type {
  IsosurfaceExportFormat,
  VolumeProbe,
  VolumeRendererApi,
} from './renderer/VolumeRendererApi';
import { useVolumeStore, type VolumeOptions } from './state/volumeStore';
import { BoundedLruCache } from './state/BoundedLruCache';
import { useAcceptanceSoak } from './state/useAcceptanceSoak';
import { volumeViewerThemes } from './themes';

const store = useVolumeStore();
const viewport = ref<HTMLElement>();
const settingsOpen = ref(false);
const minimalUi = ref(false);
const probe = ref<VolumeProbe>();
const percentiles = ref<Float32Array>();
const histogramCounts = ref<Uint32Array>();
const rendererBackend = ref<'webgl2' | 'canvas2d'>('webgl2');
const densityUnit = ref<DensityDisplayUnit>('angstrom-3');
const statusVisible = ref(false);
const acceptanceMode = new URLSearchParams(window.location.search).has('kssolvTest');
let renderer: VolumeRendererApi | undefined;
let renderedRequestId = '';
let statisticsWorker: Worker | undefined;
let statisticsGeneration = 0;
let configuredChannelId = '';
let statusDismissTimer: number | undefined;
interface StatisticsResult {
  percentiles: Float32Array;
  histogram: Uint32Array;
}
const statisticsCache = new BoundedLruCache<string, StatisticsResult>({
  maximumEntries: 8,
  maximumBytes: 4 * 1024 * 1024,
  byteLength: (value) =>
    value.percentiles.byteLength + value.histogram.byteLength,
});

const reportClientError = (value: unknown): void => {
  const message =
    value instanceof Error
      ? value.message
      : typeof value === 'object' && value && 'message' in value
        ? String(value.message)
        : String(value);
  store.status.phase = 'error';
  store.status.message = message;
  store.status.progress = null;
  matlabBridge.emit('volume:client-error', {
    requestId: store.scene.value?.requestId ?? '',
    message,
  });
};

const handleWindowError = (event: ErrorEvent): void => {
  reportClientError(event.error ?? event.message);
};

const handleUnhandledRejection = (event: PromiseRejectionEvent): void => {
  reportClientError(event.reason);
};

const values = computed(() => {
  const channel = store.activeChannel.value;
  const buffer = store.activeBuffer.value;
  return channel && buffer
    ? decodeValues(
        buffer,
        channel.transport.valueEncoding,
        channel.transport.scale,
        channel.transport.offset,
      )
    : undefined;
});
const densityDisplay = computed(() =>
  densityDisplayFor(store.activeChannel.value?.units ?? '', densityUnit.value),
);
const toggleDensityUnit = (): void => {
  if (!densityDisplay.value.convertible) return;
  densityUnit.value = densityUnit.value === 'angstrom-3' ? 'bohr-3' : 'angstrom-3';
};
const themeStyle = computed(() => {
  const theme = volumeViewerThemes[store.options.theme];
  return {
    '--viewer-background': theme.background,
    '--viewer-foreground': theme.foreground,
    '--viewer-muted': theme.muted,
    '--viewer-panel': theme.panel,
    '--viewer-panel-border': theme.panelBorder,
    '--viewer-accent': theme.accent,
    '--viewer-selection': theme.selection,
  };
});

const applyOptions = (next: VolumeOptions): void => {
  Object.assign(store.options, next);
};

const selectHistogramThreshold = (
  sign: HistogramThresholdSign,
  value: number,
): void => {
  store.options[
    sign === 'negative' ? 'negativeThreshold' : 'positiveThreshold'
  ] = value;
};

const selectHistogramRange = (
  bound: HistogramRangeBound,
  value: number,
): void => {
  const channel = store.activeChannel.value;
  if (!channel) return;
  const epsilon =
    Math.max(Math.abs(channel.maximum - channel.minimum), 1) * 1e-6;
  if (bound === 'minimum') {
    store.options.rangeMinimum = Math.min(
      value,
      store.options.rangeMaximum - epsilon,
    );
  } else {
    store.options.rangeMaximum = Math.max(
      value,
      store.options.rangeMinimum + epsilon,
    );
  }
};

const download = (dataUrl: string, name: string): void => {
  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = name;
  link.click();
};

const downloadText = (value: string, name: string, type: string): void => {
  const url = URL.createObjectURL(new Blob([value], { type }));
  download(url, name);
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
};

const exportIsosurface = async (format: IsosurfaceExportFormat): Promise<void> => {
  if (!renderer || !store.scene.value) return;
  try {
    store.status.phase = 'building';
    store.status.message = `Exporting ${format.toUpperCase()}…`;
    const result = await renderer.exportIsosurface(format);
    const url = URL.createObjectURL(new Blob([result.data], { type: result.mime }));
    const stem = volumeExportStem(
      store.scene.value.source.name,
      store.options.channelId,
    );
    download(url, `${stem}.isosurface.${format}`);
    window.setTimeout(() => URL.revokeObjectURL(url), 0);
    store.status.phase = 'ready';
    store.status.message = `${format.toUpperCase()} export ready`;
  } catch (error) {
    store.status.phase = 'error';
    store.status.message = error instanceof Error ? error.message : String(error);
  }
};

const exportManifest = (): void => {
  if (!store.scene.value) return;
  try {
    downloadText(
      JSON.stringify(store.scene.value, null, 2),
      `${volumeExportStem(
        store.scene.value.source.name,
        store.options.channelId,
      )}.scene.json`,
      'application/json',
    );
    store.status.phase = 'ready';
    store.status.message = 'Scene manifest export ready';
  } catch (error) {
    store.status.phase = 'error';
    store.status.message = error instanceof Error ? error.message : String(error);
  }
};

const exportSlice = (format: 'csv' | 'png'): void => {
  if (!renderer || !store.scene.value) return;
  try {
    const basename = sliceExportStem(
      store.scene.value.source.name,
      store.options.channelId,
      store.options.sliceAxis,
      store.options.sliceIndex,
    );
    if (format === 'csv') {
      downloadText(renderer.exportSliceCsv(), `${basename}.csv`, 'text/csv');
    } else {
      download(renderer.exportSlicePng(), `${basename}.png`);
    }
    store.status.phase = 'ready';
    store.status.message = `Slice ${format.toUpperCase()} export ready`;
  } catch (error) {
    store.status.phase = 'error';
    store.status.message = error instanceof Error ? error.message : String(error);
  }
};

const exportScreenshot = (): void => {
  if (!renderer || !store.scene.value) return;
  try {
    const stem = volumeExportStem(
      store.scene.value.source.name,
      store.options.channelId,
    );
    download(
      renderer.screenshot(store.options.pngScale),
      `${stem}.${store.options.mode}.png`,
    );
    store.status.phase = 'ready';
    store.status.message = 'PNG export ready';
  } catch (error) {
    store.status.phase = 'error';
    store.status.message = error instanceof Error ? error.message : String(error);
  }
};

const fullscreen = (): void => {
  void window.document.documentElement.requestFullscreen?.();
};

const acceptance = useAcceptanceSoak({
  enabled: acceptanceMode,
  getRenderer: () => renderer,
  getChannel: () => store.activeChannel.value,
  volumeOptions: store.options,
  reportError: (message) => {
    store.status.phase = 'error';
    store.status.message = message;
  },
});
const acceptanceProgress = acceptance.progress;
const loseContext = acceptance.loseContext;
const restoreContext = acceptance.restoreContext;
const recordAcceptanceError = acceptance.recordError;
const startAcceptanceSoak = acceptance.start;
const stopAcceptanceSoak = acceptance.stop;

const handleKey = (event: KeyboardEvent): void => {
  if (event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) return;
  if (event.key === ' ') {
    event.preventDefault();
    renderer?.centerView();
  } else if (event.key.toLowerCase() === 'i') {
    minimalUi.value = !minimalUi.value;
  }
};

const sceneStop = watch(
  [store.scene, store.activeChannel, store.activeBuffer],
  ([scene, channel, buffer]) => {
    if (scene && channel && buffer && renderer) {
      try {
        const preserveCamera = renderedRequestId === scene.requestId;
        renderer.setScene(scene, channel, buffer, { ...store.options }, preserveCamera);
        renderedRequestId = scene.requestId;
      } catch (error) {
        reportClientError(error);
      }
    }
  },
);
const optionStop = watch(
  store.options,
  (options) => renderer?.setOptions({ ...options }),
  { deep: true },
);
const channelStop = watch(
  store.activeChannel,
  (channel) => {
    if (!channel || channel.id === configuredChannelId) return;
    configuredChannelId = channel.id;
    store.options.positiveThreshold = Math.max(0, channel.maximum * 0.2);
    store.options.negativeThreshold = Math.min(0, channel.minimum * 0.2);
    store.options.rangeMinimum = channel.minimum;
    store.options.rangeMaximum = channel.maximum;
  },
  { immediate: true },
);
const valuesStop = watch(
  values,
  (next) => {
    statisticsGeneration += 1;
    const generation = statisticsGeneration;
    statisticsWorker?.terminate();
    statisticsWorker = undefined;
    percentiles.value = undefined;
    histogramCounts.value = undefined;
    if (!next) return;
    const channel = store.activeChannel.value;
    const requestId = store.scene.value?.requestId;
    if (!channel || !requestId) return;
    const cacheKey = [
      requestId,
      channel.id,
      channel.transport.crc32,
      channel.minimum,
      channel.maximum,
      72,
    ].join(':');
    const cached = statisticsCache.get(cacheKey);
    if (cached) {
      percentiles.value = cached.percentiles;
      histogramCounts.value = cached.histogram;
      return;
    }
    statisticsWorker = new Worker(new URL('./renderer/statistics.worker.ts', import.meta.url), {
      type: 'module',
    });
    statisticsWorker.onmessage = (
      event: MessageEvent<{
        id: number;
        percentiles: ArrayBuffer;
        histogram: ArrayBuffer;
      }>,
    ) => {
      if (event.data.id !== generation) return;
      const result = {
        percentiles: new Float32Array(event.data.percentiles),
        histogram: new Uint32Array(event.data.histogram),
      };
      statisticsCache.set(cacheKey, result);
      percentiles.value = result.percentiles;
      histogramCounts.value = result.histogram;
      statisticsWorker?.terminate();
      statisticsWorker = undefined;
    };
    statisticsWorker.onerror = (event): void => {
      reportClientError(
        event.error ??
          event.message ??
          'The volume statistics worker failed.',
      );
      statisticsWorker?.terminate();
      statisticsWorker = undefined;
    };
    const copy =
      next instanceof Float32Array ? next.slice() : Float64Array.from(next);
    statisticsWorker.postMessage(
      {
        id: generation,
        values: copy.buffer,
        encoding: copy instanceof Float32Array ? 'float32' : 'float64',
        minimum: store.activeChannel.value?.minimum ?? 0,
        maximum: store.activeChannel.value?.maximum ?? 1,
        bins: 72,
      },
      [copy.buffer],
    );
  },
  { immediate: true },
);
const statusStop = watch(
  [() => store.status.phase, () => store.status.message],
  ([phase, message]) => {
    if (statusDismissTimer !== undefined) {
      window.clearTimeout(statusDismissTimer);
      statusDismissTimer = undefined;
    }
    statusVisible.value = Boolean(message);
    if (message && (phase === 'ready' || phase === 'cancelled')) {
      statusDismissTimer = window.setTimeout(() => {
        statusVisible.value = false;
        statusDismissTimer = undefined;
      }, 2400);
    }
  },
  { immediate: true },
);

onMounted(() => {
  if (!viewport.value) return;
  renderer = createVolumeRenderer(
    viewport.value,
    (next) => (probe.value = next),
    (phase, message) => {
      store.status.phase = phase;
      store.status.message = message;
    },
  );
  rendererBackend.value = renderer.backend;
  if (renderer.backend === 'canvas2d') store.options.mode = 'slices';
  if (store.scene.value && store.activeChannel.value && store.activeBuffer.value) {
    try {
      renderer.setScene(
        store.scene.value,
        store.activeChannel.value,
        store.activeBuffer.value,
        { ...store.options },
      );
    } catch (error) {
      reportClientError(error);
    }
  }
  window.addEventListener('keydown', handleKey);
  window.addEventListener('error', handleWindowError);
  window.addEventListener('unhandledrejection', handleUnhandledRejection);
  if (acceptanceMode) {
    window.addEventListener('error', recordAcceptanceError);
    window.addEventListener('unhandledrejection', recordAcceptanceError);
  }
  matlabBridge.emit('volume:ready', { schemaVersion: '1.0' });
});

onBeforeUnmount(() => {
  sceneStop();
  optionStop();
  channelStop();
  valuesStop();
  statusStop();
  if (statusDismissTimer !== undefined) window.clearTimeout(statusDismissTimer);
  statisticsWorker?.terminate();
  statisticsCache.clear();
  stopAcceptanceSoak();
  window.removeEventListener('keydown', handleKey);
  window.removeEventListener('error', handleWindowError);
  window.removeEventListener('unhandledrejection', handleUnhandledRejection);
  window.removeEventListener('error', recordAcceptanceError);
  window.removeEventListener('unhandledrejection', recordAcceptanceError);
  renderer?.dispose();
});
</script>

<template>
  <main
    class="volume-viewer"
    :class="[`theme-${store.options.theme}`, { minimal: minimalUi }]"
    :style="themeStyle"
  >
    <div ref="viewport" class="viewport" />

    <section v-if="store.scene.value && !minimalUi" class="info-card">
      <p>VOLUME DATA</p>
      <h1>{{ store.scene.value.source.name }}</h1>
      <dl>
        <div><dt>Format</dt><dd>{{ store.scene.value.source.format.toUpperCase() }}</dd></div>
        <div><dt>Grid</dt><dd>{{ store.scene.value.grid.dimensions.join(' × ') }}</dd></div>
        <div><dt>Channel</dt><dd>{{ store.activeChannel.value?.label }}</dd></div>
        <div>
          <dt>Units</dt>
          <dd>
            <button
              v-if="densityDisplay.convertible"
              class="unit-toggle"
              type="button"
              :aria-label="`Switch density units from ${densityDisplay.units}`"
              :title="`Switch to ${densityUnit === 'angstrom-3' ? 'bohr⁻³' : 'Å⁻³'}`"
              @click="toggleDensityUnit"
            >
              {{ densityDisplay.units }} ⇄
            </button>
            <template v-else>{{ densityDisplay.units }}</template>
          </dd>
        </div>
      </dl>
    </section>

    <ViewerToolbar
      v-if="!minimalUi"
      :settings-open="settingsOpen"
      @reset="renderer?.resetView()"
      @axis="renderer?.setCameraAxis($event)"
      @toggle-settings="settingsOpen = !settingsOpen"
      @screenshot="exportScreenshot"
      @export-scene="exportManifest"
      @fullscreen="fullscreen"
    />

    <SettingsPanel
      v-if="settingsOpen && store.scene.value && !minimalUi"
      :scene="store.scene.value"
      :model-value="{ ...store.options }"
      :percentiles="percentiles"
      :backend="rendererBackend"
      :display-unit="densityUnit"
      @update:model-value="applyOptions"
      @update:display-unit="densityUnit = $event"
      @export-isosurface="exportIsosurface"
      @export-slice="exportSlice"
      @close="settingsOpen = false"
    />

    <div v-if="probe && !minimalUi" class="probe-card">
      <strong>{{ store.activeChannel.value?.label }}</strong>
      <span>{{ toDisplayedDensity(probe.value, densityDisplay).toPrecision(7) }} {{ densityDisplay.units }}</span>
      <small>grid ({{ probe.grid.map((value) => value.toFixed(2)).join(', ') }})</small>
      <button @click="probe = undefined">×</button>
    </div>

    <HistogramPanel
      v-if="values && store.activeChannel.value && !minimalUi"
      :channel="store.activeChannel.value"
      :counts="histogramCounts"
      :positive-threshold="store.options.positiveThreshold"
      :negative-threshold="store.options.negativeThreshold"
      :range-minimum="store.options.rangeMinimum"
      :range-maximum="store.options.rangeMaximum"
      :display-scale="densityDisplay.scale"
      :display-units="densityDisplay.units"
      :interaction="store.options.mode === 'isosurface' ? 'threshold' : 'range'"
      @select-threshold="selectHistogramThreshold"
      @select-range="selectHistogramRange"
    />

    <div
      v-if="statusVisible && store.status.message && !minimalUi"
      :class="['status', store.status.phase]"
      role="status"
      aria-live="polite"
    >
      {{ store.status.message }}
    </div>

    <div v-if="acceptanceMode" class="acceptance-controls" aria-label="Acceptance controls">
      <button data-testid="lose-context" @click="loseContext">Lose WebGL context</button>
      <button data-testid="restore-context" @click="restoreContext">Restore WebGL context</button>
      <button
        data-testid="start-soak"
        :disabled="acceptanceProgress.running"
        @click="startAcceptanceSoak"
      >
        Start stability soak
      </button>
      <output
        data-testid="soak-progress"
        :data-running="acceptanceProgress.running"
        :data-done="acceptanceProgress.done"
        :data-iterations="acceptanceProgress.iterations"
        :data-context-cycles="acceptanceProgress.contextCycles"
        :data-elapsed-ms="Math.round(acceptanceProgress.elapsedMs)"
        :data-start-heap="acceptanceProgress.startHeap"
        :data-current-heap="acceptanceProgress.currentHeap"
        :data-geometries="acceptanceProgress.geometries"
        :data-textures="acceptanceProgress.textures"
        :data-programs="acceptanceProgress.programs"
        :data-frames="acceptanceProgress.frames"
        :data-average-fps="acceptanceProgress.averageFps.toFixed(1)"
        :data-minimum-fps="acceptanceProgress.minimumFps.toFixed(1)"
        :data-errors="acceptanceProgress.errors.length"
      >
        {{ Math.floor(acceptanceProgress.elapsedMs / 1000) }} s ·
        {{ acceptanceProgress.iterations }} updates ·
        {{ acceptanceProgress.contextCycles }} recoveries ·
        {{ acceptanceProgress.averageFps.toFixed(1) }} FPS ·
        {{ acceptanceProgress.errors.length }} errors
      </output>
    </div>
  </main>
</template>
