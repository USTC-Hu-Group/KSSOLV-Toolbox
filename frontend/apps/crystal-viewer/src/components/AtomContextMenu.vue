<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';

import { primaryElementSymbol, siteSpeciesLabel } from '../elementSelection';
import type { ContextModelingCommandId, ContextModelingParameters } from '../modeling';
import type { SiteSpec, Vector3Tuple } from '../scene/types';

const props = defineProps<{
  x: number;
  y: number;
  site: SiteSpec;
  selectionCount: number;
  selectedSiteCount: number;
  backendAvailable: boolean;
  pending?: boolean;
  error?: string;
}>();

const emit = defineEmits<{
  close: [];
  command: [commandId: ContextModelingCommandId, parameters: ContextModelingParameters];
  selectSameElement: [symbol: string];
}>();

type DialogKind = 'delete' | 'substitute' | 'move' | 'translate';

const panel = ref<HTMLElement>();
const activeDialog = ref<DialogKind>();
const species = ref('');
const coordinates = ref<Vector3Tuple>([...props.site.cartesian]);
const cartesian = ref(true);
const translation = ref<Vector3Tuple>([0, 0, 0]);
const fractional = ref(false);
const validationError = ref('');
const position = ref({ left: props.x, top: props.y });

const plural = computed(() => props.selectionCount !== 1);
const elementSymbol = computed(() => primaryElementSymbol(props.site));
const deleteDisabled = computed(() => !props.backendAvailable);
const moveDisabled = computed(() => !props.backendAvailable || props.selectedSiteCount !== 1);
const title = computed(() =>
  props.selectionCount === 1
    ? `${siteSpeciesLabel(props.site)} · Site ${props.site.siteIndex + 1}`
    : `${props.selectionCount} atoms selected`,
);

const clampPosition = async (): Promise<void> => {
  await nextTick();
  if (!panel.value) return;
  const padding = 8;
  const bounds = panel.value.getBoundingClientRect();
  position.value = {
    left: Math.min(Math.max(props.x, padding), window.innerWidth - bounds.width - padding),
    top: Math.min(Math.max(props.y, padding), window.innerHeight - bounds.height - padding),
  };
};

const openDialog = (kind: DialogKind): void => {
  if (!props.backendAvailable || props.pending) return;
  if (kind === 'delete' && deleteDisabled.value) return;
  if (kind === 'move' && moveDisabled.value) return;
  validationError.value = '';
  activeDialog.value = kind;
  if (kind === 'move') {
    coordinates.value = cartesian.value
      ? [...props.site.cartesian]
      : [...(props.site.fractional ?? [0, 0, 0])];
  }
  void clampPosition();
};

const updateCoordinateMode = (): void => {
  coordinates.value = cartesian.value
    ? [...props.site.cartesian]
    : [...(props.site.fractional ?? [0, 0, 0])];
};

const finiteVector = (value: Vector3Tuple): boolean =>
  value.length === 3 && value.every(Number.isFinite);

const submit = (): void => {
  validationError.value = '';
  if (activeDialog.value === 'delete') {
    emit('command', 'delete_atoms', {});
    return;
  }
  if (activeDialog.value === 'substitute') {
    const normalized = species.value.trim();
    if (!normalized) {
      validationError.value = 'Enter a replacement element or species.';
      return;
    }
    emit('command', 'substitute_atoms', { species: normalized });
    return;
  }
  if (activeDialog.value === 'move') {
    if (!finiteVector(coordinates.value)) {
      validationError.value = 'Coordinates must contain three finite numbers.';
      return;
    }
    emit('command', 'move_atoms', {
      coordinates: [...coordinates.value],
      cartesian: cartesian.value,
    });
    return;
  }
  if (activeDialog.value === 'translate') {
    if (!finiteVector(translation.value)) {
      validationError.value = 'Translation must contain three finite numbers.';
      return;
    }
    emit('command', 'translate_atoms', {
      vector: [...translation.value],
      fractional: fractional.value,
    });
  }
};

const handleDocumentPointerDown = (event: PointerEvent): void => {
  if (!panel.value?.contains(event.target as Node)) emit('close');
};

const handleKeyDown = (event: KeyboardEvent): void => {
  if (event.key === 'Escape') {
    event.preventDefault();
    if (activeDialog.value && !props.pending) activeDialog.value = undefined;
    else emit('close');
  }
};

watch(
  () => [props.x, props.y, activeDialog.value],
  () => void clampPosition(),
);

onMounted(() => {
  void clampPosition().then(() =>
    panel.value?.querySelector<HTMLElement>('button:not(:disabled)')?.focus(),
  );
  document.addEventListener('pointerdown', handleDocumentPointerDown, true);
  window.addEventListener('keydown', handleKeyDown);
  window.addEventListener('resize', clampPosition);
});

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', handleDocumentPointerDown, true);
  window.removeEventListener('keydown', handleKeyDown);
  window.removeEventListener('resize', clampPosition);
});
</script>

<template>
  <section
    ref="panel"
    class="atom-context-panel"
    :class="{ 'has-dialog': activeDialog }"
    :style="{ left: `${position.left}px`, top: `${position.top}px` }"
    :role="activeDialog ? 'dialog' : 'menu'"
    :aria-label="activeDialog ? 'Atom modeling dialog' : 'Atom modeling menu'"
    @contextmenu.prevent
  >
    <template v-if="!activeDialog">
      <header>
        <h2>{{ title }}</h2>
      </header>
      <div class="atom-context-actions">
        <button
          class="selection-action"
          type="button"
          role="menuitem"
          @click="emit('selectSameElement', elementSymbol)"
        >
          Select All {{ elementSymbol }} Atoms
        </button>
        <button
          type="button"
          role="menuitem"
          :disabled="!backendAvailable || pending"
          @click="openDialog('substitute')"
        >
          Replace Element…
        </button>
        <button
          type="button"
          role="menuitem"
          :disabled="moveDisabled || pending"
          :title="selectedSiteCount !== 1 ? 'Move Atom requires exactly one structure site.' : ''"
          @click="openDialog('move')"
        >
          Move Atom…
        </button>
        <button
          type="button"
          role="menuitem"
          :disabled="!backendAvailable || pending"
          @click="openDialog('translate')"
        >
          Translate {{ plural ? 'Atoms' : 'Atom' }}…
        </button>
        <button
          class="danger-action"
          type="button"
          role="menuitem"
          :disabled="deleteDisabled || pending"
          @click="openDialog('delete')"
        >
          Delete {{ plural ? 'Atoms' : 'Atom' }}
        </button>
      </div>
      <p v-if="!backendAvailable" class="atom-context-notice">
        Requires KSSOLV Toolbox. Editing is unavailable in offline HTML.
      </p>
      <p v-else-if="selectionCount > 1" class="atom-context-hint">
        <template v-if="selectionCount !== selectedSiteCount">
          {{ selectionCount }} displayed atoms represent {{ selectedSiteCount }} structure
          {{ selectedSiteCount === 1 ? 'site' : 'sites' }}.
        </template>
        <template v-else>Actions apply to all selected atoms.</template>
      </p>
    </template>

    <form v-else class="atom-modeling-form" @submit.prevent="submit">
      <header>
        <h2 v-if="activeDialog === 'delete'">Delete {{ plural ? 'Atoms' : 'Atom' }}</h2>
        <h2 v-else-if="activeDialog === 'substitute'">Replace Element</h2>
        <h2 v-else-if="activeDialog === 'move'">Move Atom</h2>
        <h2 v-else>Translate {{ plural ? 'Atoms' : 'Atom' }}</h2>
        <button
          type="button"
          class="close-button"
          aria-label="Close atom modeling dialog"
          :disabled="pending"
          @click="emit('close')"
        >
          ×
        </button>
      </header>

      <p class="atom-dialog-context">{{ title }}</p>

      <p v-if="activeDialog === 'delete'" class="atom-modeling-copy">
        Delete {{ selectedSiteCount }} selected structure
        {{ selectedSiteCount === 1 ? 'site' : 'sites' }}? This can be undone from the Modeling tab.
      </p>

      <label v-else-if="activeDialog === 'substitute'" class="atom-modeling-field">
        <span>Replacement element or species</span>
        <input v-model="species" name="species" placeholder="Si" autocomplete="off" autofocus />
      </label>

      <template v-else-if="activeDialog === 'move'">
        <label class="atom-modeling-check">
          <input v-model="cartesian" type="checkbox" @change="updateCoordinateMode" />
          Cartesian coordinates (Å)
        </label>
        <div class="atom-vector-fields" aria-label="New atom coordinates">
          <label v-for="(_, index) in coordinates" :key="index">
            <span>{{ ['x', 'y', 'z'][index] }}</span>
            <input v-model.number="coordinates[index]" type="number" step="any" required />
          </label>
        </div>
      </template>

      <template v-else>
        <label class="atom-modeling-check">
          <input v-model="fractional" type="checkbox" />
          Fractional translation vector
        </label>
        <div class="atom-vector-fields" aria-label="Translation vector">
          <label v-for="(_, index) in translation" :key="index">
            <span>{{ ['x', 'y', 'z'][index] }}</span>
            <input v-model.number="translation[index]" type="number" step="any" required />
          </label>
        </div>
      </template>

      <p v-if="validationError || error" class="atom-modeling-error" role="alert">
        {{ validationError || error }}
      </p>
      <div v-if="pending" class="atom-modeling-progress" role="status" aria-live="polite">
        <span>Applying structure edit…</span>
        <progress aria-label="Structure edit progress"></progress>
      </div>
      <div class="atom-modeling-buttons">
        <button type="button" :disabled="pending" @click="activeDialog = undefined">Back</button>
        <button
          type="submit"
          :class="{ 'danger-confirm': activeDialog === 'delete' }"
          :disabled="pending"
        >
          {{ pending ? 'Applying…' : activeDialog === 'delete' ? 'Delete' : 'Apply' }}
        </button>
      </div>
    </form>
  </section>
</template>
