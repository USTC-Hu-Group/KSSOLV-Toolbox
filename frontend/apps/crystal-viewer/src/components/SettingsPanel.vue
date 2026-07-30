<script setup lang="ts">
import { computed, ref, watch } from 'vue';

import type { AtomicBondAlgorithm, AtomicSceneSpec, ViewerOptions } from '../scene/types';
import type { SceneActivityPhase } from '../state/viewerStore';

const props = withDefaults(
  defineProps<{
    modelValue: ViewerOptions;
    scene?: AtomicSceneSpec;
    rebuildPhase?: SceneActivityPhase;
    rebuildMessage?: string;
    rebuilding?: boolean;
  }>(),
  {
    scene: undefined,
    rebuildPhase: 'idle',
    rebuildMessage: '',
    rebuilding: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: ViewerOptions];
  rebuild: [
    value: {
      requestId: string;
      algorithm: AtomicBondAlgorithm;
      cell: string;
      repeat: [number, number, number];
    },
  ];
  close: [];
}>();

const algorithm = ref<AtomicBondAlgorithm>('CrystalNN');
const cell = ref('input');
const repeat = ref<[number, number, number]>([1, 1, 1]);

watch(
  () => props.scene?.analysis.algorithm,
  (value) => {
    if (value && value !== 'None') algorithm.value = value;
  },
  { immediate: true },
);

const update = <K extends keyof ViewerOptions>(key: K, value: ViewerOptions[K]): void => {
  emit('update:modelValue', { ...props.modelValue, [key]: value });
};

const requestAnalysis = (): void => {
  if (props.rebuilding || !props.scene) return;
  emit('rebuild', {
    requestId: props.scene?.requestId ?? '',
    algorithm: algorithm.value,
    cell: cell.value,
    // MATLAB uihtml cannot reliably serialize Vue's reactive array Proxy.
    // Create a plain tuple at the HTML/MATLAB boundary.
    repeat: [repeat.value[0], repeat.value[1], repeat.value[2]],
  });
};

const isMolecule = computed(() => props.scene?.kind === 'molecule');
</script>

<template>
  <aside
    class="settings-panel"
    :aria-label="isMolecule ? 'Molecule display settings' : 'Crystal display settings'"
  >
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
        <select
          :value="modelValue.theme"
          @change="
            update('theme', ($event.target as HTMLSelectElement).value as ViewerOptions['theme'])
          "
        >
          <option value="pretty">Pretty Lattice</option>
          <option value="materials">Materials Project</option>
        </select>
      </label>
      <label>
        Element colors
        <select
          :value="modelValue.colorMode"
          @change="
            update(
              'colorMode',
              ($event.target as HTMLSelectElement).value as ViewerOptions['colorMode'],
            )
          "
        >
          <option value="vesta">VESTA</option>
          <option value="jmol">Jmol</option>
        </select>
      </label>
      <label>
        Atomic radii
        <select
          :value="modelValue.radiusMode"
          @change="
            update(
              'radiusMode',
              ($event.target as HTMLSelectElement).value as ViewerOptions['radiusMode'],
            )
          "
        >
          <option value="atomic">Atomic</option>
          <option value="uniform">Uniform</option>
        </select>
      </label>
      <label class="range-label">
        Atom scale
        <output>{{ modelValue.atomScale.toFixed(2) }}</output>
        <input
          type="range"
          min="0.2"
          max="0.8"
          step="0.02"
          :value="modelValue.atomScale"
          @input="update('atomScale', Number(($event.target as HTMLInputElement).value))"
        />
      </label>
      <label class="range-label">
        Bond radius
        <output>{{ modelValue.bondRadius.toFixed(2) }}</output>
        <input
          type="range"
          min="0.03"
          max="0.25"
          step="0.01"
          :value="modelValue.bondRadius"
          @input="update('bondRadius', Number(($event.target as HTMLInputElement).value))"
        />
      </label>
    </section>

    <section>
      <h3>Visibility</h3>
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showAtoms"
          @change="update('showAtoms', ($event.target as HTMLInputElement).checked)"
        />Atoms</label
      >
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showBonds"
          @change="update('showBonds', ($event.target as HTMLInputElement).checked)"
        />Bonds</label
      >
      <label v-if="isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showHydrogens"
          @change="update('showHydrogens', ($event.target as HTMLInputElement).checked)"
        />Hydrogens</label
      >
      <label v-if="isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showBondOrders"
          @change="update('showBondOrders', ($event.target as HTMLInputElement).checked)"
        />Multiple bond order</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showUnitCell"
          @change="update('showUnitCell', ($event.target as HTMLInputElement).checked)"
        />Unit cell</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showPolyhedra"
          @change="update('showPolyhedra', ($event.target as HTMLInputElement).checked)"
        />Polyhedra</label
      >
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showAxes"
          @change="update('showAxes', ($event.target as HTMLInputElement).checked)"
        />Orientation axes</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showBoundaryAtoms"
          @change="update('showBoundaryAtoms', ($event.target as HTMLInputElement).checked)"
        />Boundary image atoms</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showBondedOutside"
          @change="update('showBondedOutside', ($event.target as HTMLInputElement).checked)"
        />One-hop bonded atoms</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.hideIncompleteBonds"
          @change="update('hideIncompleteBonds', ($event.target as HTMLInputElement).checked)"
        />Hide incomplete bonds</label
      >
      <label v-if="!isMolecule" class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showMagmoms"
          @change="update('showMagmoms', ($event.target as HTMLInputElement).checked)"
        />Magnetic moments</label
      >
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.showStatistics"
          @change="update('showStatistics', ($event.target as HTMLInputElement).checked)"
        />Performance statistics</label
      >
    </section>

    <section>
      <h3>Scientific scene</h3>
      <label>
        Bonding strategy
        <select v-model="algorithm" :disabled="rebuilding || !scene" @change="requestAnalysis">
          <template v-if="isMolecule">
            <option value="Auto">Source topology · preferred</option>
            <option value="Source">Source topology · explicit</option>
            <option value="OpenBabelNN">OpenBabelNN · inferred</option>
          </template>
          <template v-else>
            <option value="CrystalNN">CrystalNN · accurate</option>
            <option value="CutOffDictNN">Custom bonds · VESTA cutoff</option>
            <option value="JmolNN">Jmol bonding</option>
            <option value="MinimumDistanceNN">Minimum distance · 10% tolerance</option>
            <option value="MinimumOKeeffeNN">O'Keeffe's algorithm</option>
            <option value="EconNN">Hoppe's ECoN algorithm</option>
            <option value="BrunnerNNReciprocal">Brunner's reciprocal algorithm</option>
          </template>
        </select>
      </label>
      <label v-if="!isMolecule">
        Unit-cell representation
        <select v-model="cell" :disabled="rebuilding || !scene" @change="requestAnalysis">
          <option value="input">Input cell</option>
          <option value="primitive">Primitive</option>
          <option value="conventional">Conventional</option>
          <option value="niggli">Niggli reduced</option>
          <option value="lll">LLL reduced</option>
        </select>
      </label>
      <fieldset v-if="!isMolecule">
        <legend>Repeat cell</legend>
        <label v-for="(_, index) in repeat" :key="index">
          {{ ['a', 'b', 'c'][index] }}
          <input
            v-model.number="repeat[index]"
            type="number"
            min="1"
            max="8"
            :disabled="rebuilding || !scene"
            @change="requestAnalysis"
          />
        </label>
      </fieldset>
      <p
        v-if="rebuildPhase !== 'idle'"
        class="rebuild-feedback"
        :class="`is-${rebuildPhase}`"
        role="status"
        aria-live="polite"
      >
        <span
          v-if="rebuildPhase === 'queued' || rebuildPhase === 'building'"
          class="feedback-spinner"
          aria-hidden="true"
        ></span>
        <span v-else class="feedback-icon" aria-hidden="true">
          {{ rebuildPhase === 'success' ? '✓' : '!' }}
        </span>
        {{ rebuildMessage }}
      </p>
    </section>

    <section>
      <h3>High-quality exporting</h3>
      <label>
        Rendering path
        <select
          :value="modelValue.renderMode"
          @change="
            update(
              'renderMode',
              ($event.target as HTMLSelectElement).value as ViewerOptions['renderMode'],
            )
          "
        >
          <option value="fast">Fast interactive · Phong</option>
          <option value="quality">High quality · Physical</option>
        </select>
      </label>
      <label>
        Quality level
        <select
          :value="modelValue.renderQuality"
          :disabled="modelValue.renderMode === 'fast'"
          @change="
            update(
              'renderQuality',
              ($event.target as HTMLSelectElement).value as ViewerOptions['renderQuality'],
            )
          "
        >
          <option value="balanced">Balanced</option>
          <option value="high">High</option>
          <option value="ultra">Ultra</option>
        </select>
      </label>
    </section>
  </aside>
</template>
