<script setup lang="ts">
import { computed } from 'vue';

import { defaultViewerOptions } from '@kssolv/atomic-scene';
import type { VolumeSceneSpec } from '@kssolv/volume-scene';

import {
  densityDisplayFor,
  fromDisplayedDensity,
  toDisplayedDensity,
  type DensityDisplayUnit,
} from '../densityUnits';
import type { VolumeOptions } from '../state/volumeStore';

const props = defineProps<{
  scene: VolumeSceneSpec;
  modelValue: VolumeOptions;
  percentiles?: Float32Array;
  backend?: 'webgl2' | 'canvas2d';
  displayUnit: DensityDisplayUnit;
}>();
const emit = defineEmits<{
  'update:modelValue': [VolumeOptions];
  'update:displayUnit': [DensityDisplayUnit];
  'export-isosurface': ['gltf' | 'glb' | 'ply' | 'stl'];
  'export-slice': ['csv' | 'png'];
  close: [];
}>();

const update = <K extends keyof VolumeOptions>(key: K, value: VolumeOptions[K]): void => {
  emit('update:modelValue', { ...props.modelValue, [key]: value });
};

const appearanceKeys = [
  'ambientLight',
  'directionalLight',
  'metalness',
  'roughness',
  'brightness',
  'contrast',
] as const;
const defaultAppearance = defaultViewerOptions();
const appearanceIsDefault = computed(() =>
  appearanceKeys.every((key) => props.modelValue[key] === defaultAppearance[key]),
);
const percentage = (value: number): string => `${Math.round(value * 100)}%`;
const rangeFill = (value: number, min: number, max: number): Record<string, string> => ({
  '--range-fill': `${((value - min) / (max - min)) * 100}%`,
});
const resetAppearance = (): void => {
  emit('update:modelValue', {
    ...props.modelValue,
    ...Object.fromEntries(appearanceKeys.map((key) => [key, defaultAppearance[key]])),
  });
};

const sliceAxes = ['i', 'j', 'k'] as const;
const axisMaximum = (axisIndex: number): number =>
  props.scene.grid.dimensions[axisIndex] - 1;
const updateSliceIndex = (axisIndex: number, requested: number): void => {
  const value = Math.min(axisMaximum(axisIndex), Math.max(0, Math.round(requested)));
  const sliceIndices = [...props.modelValue.sliceIndices] as [number, number, number];
  sliceIndices[axisIndex] = value;
  emit('update:modelValue', {
    ...props.modelValue,
    sliceAxis: sliceAxes[axisIndex],
    sliceIndex: value,
    sliceIndices,
  });
};
const updateSliceVisibility = (axisIndex: number, visible: boolean): void => {
  const sliceVisibility = [...props.modelValue.sliceVisibility] as [
    boolean,
    boolean,
    boolean,
  ];
  sliceVisibility[axisIndex] = visible;
  emit('update:modelValue', {
    ...props.modelValue,
    sliceAxis: sliceAxes[axisIndex],
    sliceIndex: props.modelValue.sliceIndices[axisIndex],
    sliceVisibility,
  });
};

const channel = () =>
  props.scene.channels.find((item) => item.id === props.modelValue.channelId) ??
  props.scene.channels[0];
const densityDisplay = computed(() =>
  densityDisplayFor(channel().units, props.displayUnit),
);
const thresholdValue = (sign: 'positive' | 'negative'): number => {
  const value =
    sign === 'positive'
      ? props.modelValue.positiveThreshold
      : props.modelValue.negativeThreshold;
  if (props.modelValue.isovalueMode === 'absolute') {
    return toDisplayedDensity(value, densityDisplay.value);
  }
  if (props.modelValue.isovalueMode === 'percentile') {
    if (!props.percentiles?.length) return 50;
    let closest = 0;
    for (let index = 1; index < props.percentiles.length; index += 1) {
      if (
        Math.abs(props.percentiles[index] - value) <
        Math.abs(props.percentiles[closest] - value)
      ) {
        closest = index;
      }
    }
    return closest;
  }
  return (value - channel().mean) / Math.max(channel().standardDeviation, Number.EPSILON);
};
const setThreshold = (sign: 'positive' | 'negative', displayed: number): void => {
  const value =
    props.modelValue.isovalueMode === 'absolute'
      ? fromDisplayedDensity(displayed, densityDisplay.value)
      : props.modelValue.isovalueMode === 'percentile'
        ? (props.percentiles?.[Math.round(displayed)] ?? displayed)
      : channel().mean + displayed * channel().standardDeviation;
  update(sign === 'positive' ? 'positiveThreshold' : 'negativeThreshold', value);
};
const updateClip = (
  bound: 'clipMinimum' | 'clipMaximum',
  axis: number,
  requested: number,
): void => {
  const value = Math.min(1, Math.max(0, requested));
  const next = [...props.modelValue[bound]] as [number, number, number];
  next[axis] =
    bound === 'clipMinimum'
      ? Math.min(value, props.modelValue.clipMaximum[axis] - 0.01)
      : Math.max(value, props.modelValue.clipMinimum[axis] + 0.01);
  update(bound, next);
};
</script>

<template>
  <aside class="settings-panel" aria-label="Volume display settings">
    <header>
      <h2>Display settings</h2>
      <button type="button" class="close-button" aria-label="Close settings" @click="emit('close')">
        ×
      </button>
    </header>

    <section>
      <h3>Style</h3>
      <label>
        Theme
        <select :value="modelValue.theme" @change="update('theme', ($event.target as HTMLSelectElement).value as VolumeOptions['theme'])">
          <option value="materials">Materials Project</option>
          <option value="gleamoe-premiror">Gleamoe Noir</option>
        </select>
      </label>
      <template v-if="scene.atomicOverlay">
      <label>
        Element colors
        <select :value="modelValue.colorMode" @change="update('colorMode', ($event.target as HTMLSelectElement).value as VolumeOptions['colorMode'])">
          <option value="vesta">VESTA</option>
          <option value="jmol">Jmol</option>
        </select>
      </label>
      <label>
        Atomic radii
        <select :value="modelValue.radiusMode" @change="update('radiusMode', ($event.target as HTMLSelectElement).value as VolumeOptions['radiusMode'])">
          <option value="atomic">Atomic</option>
          <option value="uniform">Uniform</option>
        </select>
      </label>
      <label class="range-label">
        Atom scale
        <output>{{ modelValue.atomScale.toFixed(2) }}</output>
        <input type="range" min="0.2" max="0.8" step="0.02" :value="modelValue.atomScale" @input="update('atomScale', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="range-label">
        Bond radius
        <output>{{ modelValue.bondRadius.toFixed(2) }}</output>
        <input type="range" min="0.03" max="0.25" step="0.01" :value="modelValue.bondRadius" @input="update('bondRadius', Number(($event.target as HTMLInputElement).value))" />
      </label>
      </template>
      <p v-else class="setting-hint">Crystal styling controls appear when the volume includes an atomic structure.</p>
    </section>

    <section>
      <h3>Scalar field</h3>
      <label>
        Channel
        <select :value="modelValue.channelId" @change="update('channelId', ($event.target as HTMLSelectElement).value)">
          <option v-for="channel in scene.channels" :key="channel.id" :value="channel.id">
            {{ channel.label }}
          </option>
        </select>
      </label>
      <label>
        Display mode
        <select :value="modelValue.mode" @change="update('mode', ($event.target as HTMLSelectElement).value as VolumeOptions['mode'])">
          <option value="isosurface" :disabled="backend === 'canvas2d'">Isosurfaces</option>
          <option value="slices">Orthogonal slice</option>
          <option value="volume" :disabled="scene.grid.dimensionality === 2 || backend === 'canvas2d'">Direct volume (GPU)</option>
        </select>
      </label>
      <label v-if="densityDisplay.convertible">
        Density units
        <select :value="displayUnit" @change="emit('update:displayUnit', ($event.target as HTMLSelectElement).value as DensityDisplayUnit)">
          <option value="angstrom-3">Å⁻³</option>
          <option value="bohr-3">bohr⁻³</option>
        </select>
      </label>
    </section>

    <section v-if="modelValue.mode === 'isosurface'">
      <h3>Isosurfaces</h3>
      <label>
        Isovalue units
        <select :value="modelValue.isovalueMode" @change="update('isovalueMode', ($event.target as HTMLSelectElement).value as VolumeOptions['isovalueMode'])">
          <option value="absolute">Absolute value</option>
          <option value="sigma">Standard deviations (σ)</option>
          <option value="percentile" :disabled="!percentiles">Percentile</option>
        </select>
      </label>
      <label class="check"><input type="checkbox" :checked="modelValue.showPositive" @change="update('showPositive', ($event.target as HTMLInputElement).checked)" />Positive</label>
      <label class="range-label">Threshold <output>{{ thresholdValue('positive').toPrecision(4) }}</output>
        <input type="range" :min="0" :max="modelValue.isovalueMode === 'absolute' ? toDisplayedDensity(channel().maximum, densityDisplay) : modelValue.isovalueMode === 'percentile' ? 100 : Math.max(1, (channel().maximum - channel().mean) / Math.max(channel().standardDeviation, Number.EPSILON))" :step="modelValue.isovalueMode === 'percentile' ? 1 : 'any'" :value="thresholdValue('positive')" @input="setThreshold('positive', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="check"><input type="checkbox" :checked="modelValue.showNegative" @change="update('showNegative', ($event.target as HTMLInputElement).checked)" />Negative</label>
      <label class="range-label">Threshold <output>{{ thresholdValue('negative').toPrecision(4) }}</output>
        <input type="range" :min="modelValue.isovalueMode === 'absolute' ? toDisplayedDensity(channel().minimum, densityDisplay) : modelValue.isovalueMode === 'percentile' ? 0 : Math.min(-1, (channel().minimum - channel().mean) / Math.max(channel().standardDeviation, Number.EPSILON))" :max="modelValue.isovalueMode === 'percentile' ? 100 : 0" :step="modelValue.isovalueMode === 'percentile' ? 1 : 'any'" :value="thresholdValue('negative')" @input="setThreshold('negative', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="range-label">Opacity <output>{{ modelValue.opacity.toFixed(2) }}</output>
        <input type="range" min="0.08" max="1" step="0.01" :value="modelValue.opacity" @input="update('opacity', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="check"><input type="checkbox" :checked="modelValue.smoothIsosurface" @change="update('smoothIsosurface', ($event.target as HTMLInputElement).checked)" />Smooth vertex normals</label>
      <label v-if="scene.grid.sampling === 'cell-periodic'" class="check"><input type="checkbox" :checked="modelValue.periodicWrap" @change="update('periodicWrap', ($event.target as HTMLInputElement).checked)" />Wrap periodic boundaries</label>
    </section>

    <section v-if="modelValue.mode === 'slices'">
      <h3>Orthogonal slices</h3>
      <div v-for="(axis, axisIndex) in sliceAxes" :key="axis" class="slice-row">
        <label class="check slice-toggle">
          <input
            type="checkbox"
            :aria-label="`Show ${axis.toUpperCase()} slice`"
            :checked="modelValue.sliceVisibility[axisIndex]"
            @change="updateSliceVisibility(axisIndex, ($event.target as HTMLInputElement).checked)"
          />
          {{ axis.toUpperCase() }}
        </label>
        <input
          :aria-label="`${axis.toUpperCase()} slice index`"
          type="range"
          min="0"
          :max="axisMaximum(axisIndex)"
          step="1"
          :value="Math.min(modelValue.sliceIndices[axisIndex], axisMaximum(axisIndex))"
          @input="updateSliceIndex(axisIndex, Number(($event.target as HTMLInputElement).value))"
        />
        <output>{{ Math.min(modelValue.sliceIndices[axisIndex], axisMaximum(axisIndex)) }}</output>
      </div>
      <p class="setting-hint">Each plane can be positioned and shown independently. Slice export uses the last adjusted plane.</p>
    </section>

    <section v-if="modelValue.mode === 'slices' || modelValue.mode === 'volume'">
      <h3>Color and sampling</h3>
      <label>
        Colormap
        <select :value="modelValue.colormap" @change="update('colormap', ($event.target as HTMLSelectElement).value as VolumeOptions['colormap'])">
          <option value="viridis">Viridis</option>
          <option value="coolwarm">Cool–warm</option>
          <option value="density">Density</option>
        </select>
      </label>
      <label>
        Interpolation
        <select :value="modelValue.interpolation" @change="update('interpolation', ($event.target as HTMLSelectElement).value as VolumeOptions['interpolation'])">
          <option value="linear">Linear</option>
          <option value="nearest">Nearest</option>
        </select>
      </label>
      <label>
        Range minimum ({{ densityDisplay.units }})
        <input type="number" step="any" :value="toDisplayedDensity(modelValue.rangeMinimum, densityDisplay)" @change="update('rangeMinimum', fromDisplayedDensity(Number(($event.target as HTMLInputElement).value), densityDisplay))" />
      </label>
      <label>
        Range maximum ({{ densityDisplay.units }})
        <input type="number" step="any" :value="toDisplayedDensity(modelValue.rangeMaximum, densityDisplay)" @change="update('rangeMaximum', fromDisplayedDensity(Number(($event.target as HTMLInputElement).value), densityDisplay))" />
      </label>
    </section>

    <section v-if="modelValue.mode === 'volume'">
      <h3>Direct volume</h3>
      <label>
        Sampling quality
        <select :value="modelValue.volumeQuality" @change="update('volumeQuality', ($event.target as HTMLSelectElement).value as VolumeOptions['volumeQuality'])">
          <option value="fast">Fast</option>
          <option value="balanced">Balanced</option>
          <option value="high">High</option>
        </select>
      </label>
      <label class="range-label">Opacity <output>{{ modelValue.opacity.toFixed(2) }}</output>
        <input type="range" min="0.02" max="1" step="0.01" :value="modelValue.opacity" @input="update('opacity', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="range-label">Gradient opacity <output>{{ modelValue.gradientOpacity.toFixed(2) }}</output>
        <input type="range" min="0" max="1" step="0.01" :value="modelValue.gradientOpacity" @input="update('gradientOpacity', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <div v-for="(axis, axisIndex) in ['I', 'J', 'K']" :key="axis" class="clip-row">
        <span>{{ axis }} clipping</span>
        <input
          :aria-label="`${axis} clip minimum`"
          type="number"
          min="0"
          max="1"
          step="0.01"
          :value="modelValue.clipMinimum[axisIndex]"
          @change="updateClip('clipMinimum', axisIndex, Number(($event.target as HTMLInputElement).value))"
        />
        <input
          :aria-label="`${axis} clip maximum`"
          type="number"
          min="0"
          max="1"
          step="0.01"
          :value="modelValue.clipMaximum[axisIndex]"
          @change="updateClip('clipMaximum', axisIndex, Number(($event.target as HTMLInputElement).value))"
        />
      </div>
    </section>

    <section>
      <h3>Visibility</h3>
      <label class="check"><input type="checkbox" :checked="modelValue.showAtoms" @change="update('showAtoms', ($event.target as HTMLInputElement).checked)" />Atoms</label>
      <label class="check"><input type="checkbox" :checked="modelValue.showBonds" @change="update('showBonds', ($event.target as HTMLInputElement).checked)" />Bonds</label>
      <label class="check"><input type="checkbox" :checked="modelValue.showCell" @change="update('showCell', ($event.target as HTMLInputElement).checked)" />Unit cell</label>
      <label class="check"><input type="checkbox" :checked="modelValue.showPolyhedra" @change="update('showPolyhedra', ($event.target as HTMLInputElement).checked)" />Polyhedra</label>
      <label class="check"><input type="checkbox" :checked="modelValue.showAxes" @change="update('showAxes', ($event.target as HTMLInputElement).checked)" />Orientation axes</label>
    </section>

    <section v-if="scene.atomicOverlay" class="appearance-settings">
      <h3>Lighting &amp; surface</h3>

      <div class="appearance-group" aria-label="Light source settings">
        <h4>Light sources</h4>
        <label class="range-label appearance-range">
          <span>Ambient light</span>
          <output>{{ percentage(modelValue.ambientLight) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.ambientLight, 0, 1)" :value="modelValue.ambientLight" @input="update('ambientLight', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
        <label class="range-label appearance-range">
          <span>Directional light</span>
          <output>{{ percentage(modelValue.directionalLight) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.directionalLight, 0, 1)" :value="modelValue.directionalLight" @input="update('directionalLight', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
      </div>

      <div class="appearance-group" aria-label="Material settings">
        <h4>Material response</h4>
        <label class="range-label appearance-range">
          <span>Metalness</span>
          <output>{{ percentage(modelValue.metalness) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.metalness, 0, 1)" :value="modelValue.metalness" @input="update('metalness', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
        <label class="range-label appearance-range">
          <span>Roughness</span>
          <output>{{ percentage(modelValue.roughness) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.roughness, 0, 1)" :value="modelValue.roughness" @input="update('roughness', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
      </div>

      <div class="appearance-group" aria-label="Image settings">
        <h4>Image</h4>
        <label class="range-label appearance-range">
          <span>Brightness</span>
          <output>{{ percentage(modelValue.brightness) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.brightness, 0, 1)" :value="modelValue.brightness" @input="update('brightness', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
        <label class="range-label appearance-range">
          <span>Contrast</span>
          <output>{{ percentage(modelValue.contrast) }}</output>
          <input type="range" min="0" max="1" step="0.025" :style="rangeFill(modelValue.contrast, 0, 1)" :value="modelValue.contrast" @input="update('contrast', Number(($event.target as HTMLInputElement).value))" />
          <span class="range-scale" aria-hidden="true"><span>0</span><span>50</span><span>100%</span></span>
        </label>
      </div>

      <button type="button" class="appearance-reset-button" :disabled="appearanceIsDefault" @click="resetAppearance">
        Reset appearance
      </button>
    </section>

    <section v-if="modelValue.mode === 'isosurface'">
      <h3>Isosurface export</h3>
      <div class="segmented">
        <button @click="emit('export-isosurface', 'gltf')">glTF</button>
        <button @click="emit('export-isosurface', 'glb')">GLB</button>
        <button @click="emit('export-isosurface', 'ply')">PLY</button>
        <button @click="emit('export-isosurface', 'stl')">STL</button>
      </div>
    </section>

    <section v-if="modelValue.mode === 'slices'">
      <h3>Slice export</h3>
      <div class="segmented">
        <button @click="emit('export-slice', 'csv')">CSV</button>
        <button @click="emit('export-slice', 'png')">PNG</button>
      </div>
    </section>

    <section>
      <h3>Image export</h3>
      <label>
        PNG scale
        <select :value="modelValue.pngScale" @change="update('pngScale', Number(($event.target as HTMLSelectElement).value) as VolumeOptions['pngScale'])">
          <option :value="1">1×</option>
          <option :value="1.5">1.5×</option>
          <option :value="2">2×</option>
        </select>
      </label>
    </section>
  </aside>
</template>
