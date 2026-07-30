<script setup lang="ts">
import type { VolumeSceneSpec } from '@kssolv/volume-scene';

import type { VolumeOptions } from '../state/volumeStore';

const props = defineProps<{
  scene: VolumeSceneSpec;
  modelValue: VolumeOptions;
  percentiles?: Float32Array;
  backend?: 'webgl2' | 'canvas2d';
}>();
const emit = defineEmits<{
  'update:modelValue': [VolumeOptions];
  'export-isosurface': ['gltf' | 'glb' | 'ply' | 'stl'];
  'export-slice': ['csv' | 'png'];
  close: [];
}>();

const update = <K extends keyof VolumeOptions>(key: K, value: VolumeOptions[K]): void => {
  emit('update:modelValue', { ...props.modelValue, [key]: value });
};

const axisMaximum = (): number => {
  const axis = props.modelValue.sliceAxis;
  return props.scene.grid.dimensions[axis === 'i' ? 0 : axis === 'j' ? 1 : 2] - 1;
};

const channel = () =>
  props.scene.channels.find((item) => item.id === props.modelValue.channelId) ??
  props.scene.channels[0];
const thresholdValue = (sign: 'positive' | 'negative'): number => {
  const value =
    sign === 'positive'
      ? props.modelValue.positiveThreshold
      : props.modelValue.negativeThreshold;
  if (props.modelValue.isovalueMode === 'absolute') return value;
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
      ? displayed
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
        <input type="range" :min="0" :max="modelValue.isovalueMode === 'absolute' ? channel().maximum : modelValue.isovalueMode === 'percentile' ? 100 : Math.max(1, (channel().maximum - channel().mean) / Math.max(channel().standardDeviation, Number.EPSILON))" :step="modelValue.isovalueMode === 'percentile' ? 1 : 'any'" :value="thresholdValue('positive')" @input="setThreshold('positive', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="check"><input type="checkbox" :checked="modelValue.showNegative" @change="update('showNegative', ($event.target as HTMLInputElement).checked)" />Negative</label>
      <label class="range-label">Threshold <output>{{ thresholdValue('negative').toPrecision(4) }}</output>
        <input type="range" :min="modelValue.isovalueMode === 'absolute' ? channel().minimum : modelValue.isovalueMode === 'percentile' ? 0 : Math.min(-1, (channel().minimum - channel().mean) / Math.max(channel().standardDeviation, Number.EPSILON))" :max="modelValue.isovalueMode === 'percentile' ? 100 : 0" :step="modelValue.isovalueMode === 'percentile' ? 1 : 'any'" :value="thresholdValue('negative')" @input="setThreshold('negative', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="range-label">Opacity <output>{{ modelValue.opacity.toFixed(2) }}</output>
        <input type="range" min="0.08" max="1" step="0.01" :value="modelValue.opacity" @input="update('opacity', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label class="check"><input type="checkbox" :checked="modelValue.smoothIsosurface" @change="update('smoothIsosurface', ($event.target as HTMLInputElement).checked)" />Smooth vertex normals</label>
      <label v-if="scene.grid.sampling === 'cell-periodic'" class="check"><input type="checkbox" :checked="modelValue.periodicWrap" @change="update('periodicWrap', ($event.target as HTMLInputElement).checked)" />Wrap periodic boundaries</label>
    </section>

    <section v-if="modelValue.mode === 'slices'">
      <h3>Slice</h3>
      <div class="segmented">
        <button v-for="axis in (['i','j','k'] as const)" :key="axis" :class="{ active: modelValue.sliceAxis === axis }" @click="update('sliceAxis', axis)">{{ axis.toUpperCase() }}</button>
      </div>
      <label class="range-label">Index <output>{{ modelValue.sliceIndex }}</output>
        <input type="range" min="0" :max="axisMaximum()" step="1" :value="Math.min(modelValue.sliceIndex, axisMaximum())" @input="update('sliceIndex', Number(($event.target as HTMLInputElement).value))" />
      </label>
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
        Range minimum
        <input type="number" step="any" :value="modelValue.rangeMinimum" @change="update('rangeMinimum', Number(($event.target as HTMLInputElement).value))" />
      </label>
      <label>
        Range maximum
        <input type="number" step="any" :value="modelValue.rangeMaximum" @change="update('rangeMaximum', Number(($event.target as HTMLInputElement).value))" />
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
