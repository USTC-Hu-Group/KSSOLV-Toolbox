<script setup lang="ts">
import type { CrystalCameraAxis } from '@kssolv/three-scene';

defineProps<{ settingsOpen: boolean }>();
const emit = defineEmits<{
  reset: [];
  toggleSettings: [];
  screenshot: [];
  exportScene: [];
  fullscreen: [];
  axis: [axis: CrystalCameraAxis];
}>();
</script>

<template>
  <nav class="viewer-toolbar" aria-label="Volume viewer tools">
    <button type="button" title="Reset camera" aria-label="Reset camera" @click="emit('reset')">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4.5 8.5A8 8 0 1 1 4 15" />
        <path d="M4.5 4.5v4h4" />
        <circle cx="12" cy="12" r="2.5" />
      </svg>
    </button>
    <div class="toolbar-separator" />
    <button class="axis-button" type="button" title="View along a axis" @click="emit('axis', 'a')">
      a
    </button>
    <button class="axis-button" type="button" title="View along b axis" @click="emit('axis', 'b')">
      b
    </button>
    <button class="axis-button" type="button" title="View along c axis" @click="emit('axis', 'c')">
      c
    </button>
    <div class="toolbar-separator" />
    <button
      class="axis-button reciprocal-axis-button"
      type="button"
      title="View along reciprocal a* axis"
      @click="emit('axis', 'a*')"
    >
      a*
    </button>
    <button
      class="axis-button reciprocal-axis-button"
      type="button"
      title="View along reciprocal b* axis"
      @click="emit('axis', 'b*')"
    >
      b*
    </button>
    <button
      class="axis-button reciprocal-axis-button"
      type="button"
      title="View along reciprocal c* axis"
      @click="emit('axis', 'c*')"
    >
      c*
    </button>
    <div class="toolbar-separator" />
    <button
      type="button"
      title="Viewer settings"
      :aria-pressed="settingsOpen"
      aria-label="Viewer settings"
      @click="emit('toggleSettings')"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M9.7 3.3h4.6l.6 2.2a7.5 7.5 0 0 1 1.4.8l2.2-.6 2.3 4-1.6 1.6v1.6l1.6 1.6-2.3 4-2.2-.6a7.5 7.5 0 0 1-1.4.8l-.6 2.2H9.7l-.6-2.2a7.5 7.5 0 0 1-1.4-.8l-2.2.6-2.3-4 1.6-1.6v-1.6L3.2 9.7l2.3-4 2.2.6a7.5 7.5 0 0 1 1.4-.8z"
        />
        <circle cx="12" cy="12" r="3" />
      </svg>
    </button>
    <button type="button" title="Save PNG" aria-label="Save PNG" @click="emit('screenshot')">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7.5h3l1.4-2h7.2l1.4 2h3v11H4z" />
        <circle cx="12" cy="13" r="3.5" />
      </svg>
    </button>
    <button
      type="button"
      title="Export scene JSON"
      aria-label="Export scene JSON"
      @click="emit('exportScene')"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 3.5h8l4 4v6" />
        <path d="M14 3.5v4h4" />
        <path d="M6 3.5v17h6" />
        <path d="M16 12v8m-3-3 3 3 3-3" />
      </svg>
    </button>
    <button type="button" title="Fullscreen" aria-label="Fullscreen" @click="emit('fullscreen')">
      ⛶
    </button>
  </nav>
</template>
