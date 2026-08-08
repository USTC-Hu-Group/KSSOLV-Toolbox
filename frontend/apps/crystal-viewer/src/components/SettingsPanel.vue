<script setup lang="ts">
import { computed, ref, watch } from 'vue';

import {
  defaultViewerOptions,
  type AtomicBondAlgorithm,
  type AtomicSceneSpec,
  type ViewerOptions,
} from '../scene/types';
import type { SceneActivityPhase } from '../state/viewerStore';

const props = withDefaults(
  defineProps<{
    modelValue: ViewerOptions;
    scene?: AtomicSceneSpec;
    rebuildPhase?: SceneActivityPhase;
    rebuildMessage?: string;
    rebuilding?: boolean;
    imageExporting?: boolean;
    sceneAvailable?: boolean;
  }>(),
  {
    scene: undefined,
    rebuildPhase: 'idle',
    rebuildMessage: '',
    rebuilding: false,
    imageExporting: false,
    sceneAvailable: false,
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
  toggleHeroShot: [];
}>();

const algorithm = ref<AtomicBondAlgorithm>('CrystalNN');
type UnitCellRepresentation = 'input' | 'primitive' | 'conventional' | 'niggli' | 'lll';

const unitCellRepresentations: UnitCellRepresentation[] = [
  'input',
  'primitive',
  'conventional',
  'niggli',
  'lll',
];
const isUnitCellRepresentation = (value: unknown): value is UnitCellRepresentation =>
  typeof value === 'string' && unitCellRepresentations.includes(value as UnitCellRepresentation);

const cell = ref<UnitCellRepresentation>('input');
const repeat = ref<[number, number, number]>([1, 1, 1]);

watch(
  () => props.scene?.analysis.algorithm,
  (value) => {
    if (value && value !== 'None') algorithm.value = value;
  },
  { immediate: true },
);

watch(
  () => props.scene?.analysis.parameters.cell,
  (value) => {
    if (isUnitCellRepresentation(value)) cell.value = value;
  },
  { immediate: true },
);

watch(
  () => (props.scene?.kind === 'crystal' ? props.scene.structure.repeat : undefined),
  (value) => {
    if (value) repeat.value = [value[0], value[1], value[2]];
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
const isBlankStructure = computed(
  () => props.scene?.kind === 'crystal' && props.scene.structure.siteCount === 0,
);
const repeatIsDefault = computed(() => repeat.value.every((value) => value === 1));
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

const resetRepeat = (): void => {
  repeat.value = [1, 1, 1];
  requestAnalysis();
};
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
          <option value="materials">Materials Project</option>
          <option value="gleamoe-premiror">Gleamoe Noir</option>
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
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.depthCueing"
          @change="update('depthCueing', ($event.target as HTMLInputElement).checked)"
        />Depth Cueing</label
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
      <h3>Measurements</h3>
      <label class="check"
        ><input
          type="checkbox"
          :checked="modelValue.continuousMeasurement"
          @change="update('continuousMeasurement', ($event.target as HTMLInputElement).checked)"
        />Continuous measurement</label
      >
    </section>

    <section>
      <h3>Scientific scene</h3>
      <p v-if="isBlankStructure" class="blank-settings-note">
        Bond analysis becomes available after the first atom is added.
      </p>
      <label v-if="!isMolecule">
        Change unit cell
        <select
          v-model="cell"
          :disabled="rebuilding || !scene || isBlankStructure"
          @change="requestAnalysis"
        >
          <option value="input">Input cell</option>
          <option value="primitive">Primitive cell</option>
          <option value="conventional">Conventional cell</option>
          <option value="niggli">Reduced cell (Niggli)</option>
          <option value="lll">Reduced cell (LLL)</option>
        </select>
      </label>
      <label>
        Bonding strategy
        <select
          v-model="algorithm"
          :disabled="rebuilding || !scene || isBlankStructure"
          @change="requestAnalysis"
        >
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
      <fieldset v-if="!isMolecule">
        <legend>Repeat cell</legend>
        <label v-for="(_, index) in repeat" :key="index">
          {{ ['a', 'b', 'c'][index] }}
          <input
            v-model.number="repeat[index]"
            type="number"
            min="1"
            max="8"
            :disabled="rebuilding || !scene || isBlankStructure"
            @change="requestAnalysis"
          />
        </label>
        <button
          type="button"
          class="repeat-reset-button"
          :disabled="rebuilding || !scene || isBlankStructure || repeatIsDefault"
          @click="resetRepeat"
        >
          Reset to 1 × 1 × 1
        </button>
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
        <span class="rebuild-feedback-copy">{{ rebuildMessage }}</span>
        <progress
          v-if="rebuildPhase === 'queued' || rebuildPhase === 'building'"
          aria-label="Scientific scene progress"
        ></progress>
      </p>
    </section>

    <section class="appearance-settings">
      <h3>Lighting &amp; surface</h3>

      <div class="appearance-group" aria-label="Light source settings">
        <h4>Light sources</h4>
        <label class="range-label appearance-range">
          <span>Ambient light</span>
          <output>{{ percentage(modelValue.ambientLight) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.ambientLight, 0, 1)"
            :value="modelValue.ambientLight"
            @input="update('ambientLight', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
        <label class="range-label appearance-range">
          <span>Directional light</span>
          <output>{{ percentage(modelValue.directionalLight) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.directionalLight, 0, 1)"
            :value="modelValue.directionalLight"
            @input="update('directionalLight', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
      </div>

      <div class="appearance-group" aria-label="Material settings">
        <h4>Material response</h4>
        <label class="range-label appearance-range">
          <span>Metalness</span>
          <output>{{ percentage(modelValue.metalness) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.metalness, 0, 1)"
            :value="modelValue.metalness"
            @input="update('metalness', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
        <label class="range-label appearance-range">
          <span>Roughness</span>
          <output>{{ percentage(modelValue.roughness) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.roughness, 0, 1)"
            :value="modelValue.roughness"
            @input="update('roughness', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
      </div>

      <div class="appearance-group" aria-label="Image settings">
        <h4>Image</h4>
        <label class="range-label appearance-range">
          <span>Brightness</span>
          <output>{{ percentage(modelValue.brightness) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.brightness, 0, 1)"
            :value="modelValue.brightness"
            @input="update('brightness', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
        <label class="range-label appearance-range">
          <span>Contrast</span>
          <output>{{ percentage(modelValue.contrast) }}</output>
          <input
            type="range"
            min="0"
            max="1"
            step="0.025"
            :style="rangeFill(modelValue.contrast, 0, 1)"
            :value="modelValue.contrast"
            @input="update('contrast', Number(($event.target as HTMLInputElement).value))"
          />
          <span class="range-scale" aria-hidden="true"
            ><span>0</span><span>50</span><span>100%</span></span
          >
        </label>
      </div>

      <button
        type="button"
        class="appearance-reset-button"
        :disabled="appearanceIsDefault"
        @click="resetAppearance"
      >
        Reset appearance
      </button>
    </section>

    <section v-if="modelValue.theme === 'gleamoe-premiror'" class="hero-settings">
      <h3>Hero Shot</h3>
      <p class="hero-settings-description">
        Compose a cinematic, path-traced view and progressively refine it into a high-resolution
        image.
      </p>
      <button
        type="button"
        class="hero-mode-button"
        :disabled="!sceneAvailable || imageExporting"
        @click="emit('toggleHeroShot')"
      >
        Enter Hero mode
      </button>
    </section>
  </aside>
</template>
