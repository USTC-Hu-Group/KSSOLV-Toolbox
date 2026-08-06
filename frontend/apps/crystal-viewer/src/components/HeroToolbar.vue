<script setup lang="ts">
import { ref } from 'vue';

import type { CrystalCameraAxis } from '../renderer/cameraAxis';
import type { HeroExportScale } from '../renderer/quality';

const props = withDefaults(
  defineProps<{
    crystal: boolean;
    exportScale?: HeroExportScale;
    exporting?: boolean;
  }>(),
  {
    exportScale: 2.5,
    exporting: false,
  },
);

const emit = defineEmits<{
  reset: [];
  axis: [axis: CrystalCameraAxis];
  export: [scale: HeroExportScale];
  'update:exportScale': [scale: HeroExportScale];
  exit: [];
}>();

const exportMenuOpen = ref(false);
const exportOptions: Array<{ scale: HeroExportScale; label: string; detail: string }> = [
  { scale: 2.5, label: 'High', detail: '2.5× viewport · PNG' },
  { scale: 3, label: 'Ultra', detail: '3× viewport · PNG' },
  { scale: 4, label: 'Poster', detail: '4× viewport · PNG' },
];

const selectExportScale = (scale: HeroExportScale): void => {
  exportMenuOpen.value = false;
  emit('update:exportScale', scale);
  emit('export', scale);
};

const closeMenuOnFocusOut = (event: FocusEvent): void => {
  const menu = event.currentTarget as HTMLElement;
  if (!menu.contains(event.relatedTarget as Node | null)) exportMenuOpen.value = false;
};
</script>

<template>
  <nav
    class="hero-toolbar"
    :class="{ 'has-open-export-menu': exportMenuOpen }"
    aria-label="Hero mode tools"
    @keydown.esc="exportMenuOpen = false"
  >
    <button type="button" title="Reset camera" aria-label="Reset camera" @click="emit('reset')">
      <svg class="reset-camera-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M3 7h3.4L8 4.8h8L17.6 7H21v14H3z" />
        <path d="M16.2 11.4a4.3 4.3 0 1 0 .2 4.4" />
        <path d="m13.7 9.6 2.5 1.8-2.8 1.2" />
      </svg>
    </button>
    <div class="toolbar-separator" />
    <button
      v-for="axis in ['a', 'b', 'c'] as CrystalCameraAxis[]"
      :key="axis"
      class="axis-button"
      :data-toolbar-axis="axis"
      type="button"
      :title="`View along ${axis} axis`"
      @click="emit('axis', axis)"
    >
      {{ axis }}
    </button>
    <template v-if="crystal">
      <div class="toolbar-separator" />
      <button
        v-for="axis in ['a*', 'b*', 'c*'] as CrystalCameraAxis[]"
        :key="axis"
        class="axis-button reciprocal-axis-button"
        :data-toolbar-axis="axis"
        type="button"
        :title="`View along reciprocal ${axis} axis`"
        @click="emit('axis', axis)"
      >
        {{ axis }}
      </button>
    </template>
    <div class="toolbar-separator" />
    <div class="toolbar-export-menu hero-export-menu" @focusout="closeMenuOnFocusOut">
      <button
        type="button"
        title="Export Hero Shot"
        aria-label="Export Hero Shot"
        aria-haspopup="menu"
        :aria-expanded="exportMenuOpen"
        :disabled="exporting"
        @click="exportMenuOpen = !exportMenuOpen"
      >
        <svg class="hero-export-icon" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 4h11l5 5v11H4z" />
          <path d="M8 4v6h8V5M8 20v-6h8v6" />
        </svg>
      </button>
      <div
        v-if="exportMenuOpen"
        class="toolbar-export-popover hero-export-popover"
        role="menu"
        aria-label="Hero export resolution"
      >
        <button
          v-for="option in exportOptions"
          :key="option.scale"
          class="toolbar-export-option"
          :class="{ 'is-selected': option.scale === props.exportScale }"
          type="button"
          role="menuitemradio"
          :aria-checked="option.scale === props.exportScale"
          @click="selectExportScale(option.scale)"
        >
          <strong>{{ option.label }}</strong>
          <span>{{ option.detail }}</span>
        </button>
      </div>
    </div>
    <button
      class="hero-exit-button"
      type="button"
      title="Exit Hero mode"
      aria-label="Exit Hero mode"
      :disabled="exporting"
      @click="emit('exit')"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="m7 7 10 10M17 7 7 17" />
      </svg>
    </button>
  </nav>
</template>
