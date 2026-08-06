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
    <button
      class="toolbar-reset"
      type="button"
      title="Reset camera"
      aria-label="Reset camera"
      @click="emit('reset')"
    >
      <svg class="reset-camera-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M3 7h3.4L8 4.8h8L17.6 7H21v14H3z" />
        <path d="M16.2 11.4a4.3 4.3 0 1 0 .2 4.4" />
        <path d="m13.7 9.6 2.5 1.8-2.8 1.2" />
      </svg>
    </button>
    <div class="toolbar-separator" />
    <button
      class="axis-button"
      data-toolbar-axis="a"
      type="button"
      title="View along a axis"
      @click="emit('axis', 'a')"
    >
      a
    </button>
    <button
      class="axis-button"
      data-toolbar-axis="b"
      type="button"
      title="View along b axis"
      @click="emit('axis', 'b')"
    >
      b
    </button>
    <button
      class="axis-button"
      data-toolbar-axis="c"
      type="button"
      title="View along c axis"
      @click="emit('axis', 'c')"
    >
      c
    </button>
    <div class="toolbar-separator" />
    <button
      class="axis-button reciprocal-axis-button"
      data-toolbar-axis="a*"
      type="button"
      title="View along reciprocal a* axis"
      @click="emit('axis', 'a*')"
    >
      a*
    </button>
    <button
      class="axis-button reciprocal-axis-button"
      data-toolbar-axis="b*"
      type="button"
      title="View along reciprocal b* axis"
      @click="emit('axis', 'b*')"
    >
      b*
    </button>
    <button
      class="axis-button reciprocal-axis-button"
      data-toolbar-axis="c*"
      type="button"
      title="View along reciprocal c* axis"
      @click="emit('axis', 'c*')"
    >
      c*
    </button>
    <div class="toolbar-separator" />
    <button
      class="toolbar-settings"
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
    <button
      class="toolbar-image-export"
      type="button"
      title="Save PNG"
      aria-label="Save PNG"
      @click="emit('screenshot')"
    >
      <svg
        class="toolbar-filled-icon export-image-icon"
        viewBox="0 0 1024 1024"
        aria-hidden="true"
      >
        <path
          d="M459.6 515.7c0-33.2-26.9-60.1-60.1-60.1s-60.2 26.9-60.2 60.1 26.9 60.1 60.2 60.1c33.1.1 60.1-26.8 60.1-60.1ZM585.2 776.1c15.7-98.2 94.8-175.1 194-187.5l-10-32.5-50.8 16.9-44.1-83L532 695.4l-76.2-49.2-119.5 129.9h248.9Z"
        />
        <path
          d="M259.7 829V398c0-7.7 6.2-13.9 13.9-13.9h607.1c7.7 0 13.9 6.2 13.9 13.9v206.4c23.5 9.9 44.9 23.6 63.6 40.4V351.9c0-17.4-14.1-31.4-31.4-31.4h-134l-79.3-206.2c-6.2-16.2-24.4-24.3-40.6-18.1L20.2 347.1C4 353.4-4.1 371.6 2.1 387.8l194 504.5v.3h401.2c-7.7-20-12.6-41.3-14.3-63.6H259.7Zm400.7-660c2.1-.3 5.5-.2 7.3 3.8l56.8 147.6H266.6L660.4 169ZM196.1 715.1 77.9 407.9c-2.7-7.1.8-15.2 8-17.9l110.2-42.4v367.5Z"
        />
        <path
          d="M1022.5 800 871 678.5c-2.3-1.7-5.5-.1-5.5 2.8v75.1H670c-5.3 0-9.7 4.3-9.7 9.6v75.7c0 5.3 4.3 9.7 9.7 9.7h195.5v75.1c0 2.8 3.3 4.5 5.5 2.8l151.5-121.5c2.6-2 2.6-5.9 0-7.8Z"
        />
      </svg>
    </button>
    <button
      class="toolbar-file-export"
      type="button"
      title="Export scene JSON"
      aria-label="Export scene JSON"
      @click="emit('exportScene')"
    >
      <svg
        class="toolbar-filled-icon export-file-icon"
        viewBox="0 0 1024 1024"
        aria-hidden="true"
      >
        <path
          d="M597.333 0C666.453 0 886.57 218.624 895.7 294.059l.299 4.608v186.666a42.667 42.667 0 0 1-85.035 4.992l-.298-4.992v-144h-128a128 128 0 0 1-127.787-120.49l-.213-7.51v-128h-384a42.667 42.667 0 0 0-42.368 37.675L128 128v725.332a85.333 85.333 0 0 0 78.933 85.12l6.4.214h341.334a42.667 42.667 0 0 1 4.992 85.034l-4.992.299H213.333A170.667 170.667 0 0 1 42.88 861.866l-.213-8.534V128A128 128 0 0 1 163.157.213l7.51-.213h426.666Zm256 700.33a42.667 42.667 0 0 1 30.166 12.501l67.669 67.67a42.667 42.667 0 0 1 0 60.33l-67.67 67.67a42.667 42.667 0 0 1-72.831-30.166v-25.003H597.333a42.667 42.667 0 0 1 0-85.333h213.334v-25.003a42.667 42.667 0 0 1 42.666-42.666Zm-256-145.664a42.667 42.667 0 0 1 0 85.333H298.667a42.667 42.667 0 0 1 0-85.333h298.666ZM512 341.333a42.667 42.667 0 0 1 0 85.334H298.667a42.667 42.667 0 1 1 0-85.334H512ZM640 114.9v98.432a42.667 42.667 0 0 0 37.675 42.368l4.992.299h98.474A1572.691 1572.691 0 0 0 640 114.944Z"
        />
      </svg>
    </button>
    <button
      class="toolbar-fullscreen"
      type="button"
      title="Fullscreen"
      aria-label="Fullscreen"
      @click="emit('fullscreen')"
    >
      <svg class="toolbar-filled-icon fullscreen-icon" viewBox="0 0 1024 1024" aria-hidden="true">
        <path
          d="M170.667 170.667V384H85.333V85.333H384v85.334H170.667ZM853.333 384V170.667H640V85.333h298.667V384h-85.334ZM170.667 640v213.333H384v85.334H85.333V640h85.334ZM853.333 640h85.334v298.667H640v-85.334h213.333V640Z"
        />
      </svg>
    </button>
  </nav>
</template>
