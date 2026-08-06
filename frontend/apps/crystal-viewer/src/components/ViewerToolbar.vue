<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';

import { measurementTitle, type MeasurementKind } from '../measurement';
import type { CrystalCameraAxis } from '../renderer/cameraAxis';
import type { ImageExportFormat } from '../renderer/imageExport';
import type { StructureExportFormat } from '../structureExport';

const props = withDefaults(
  defineProps<{
    settingsOpen: boolean;
    informationOpen?: boolean;
    informationAvailable?: boolean;
    crystal: boolean;
    autoRotating?: boolean;
    imageExporting?: boolean;
    structureExporting?: boolean;
    structureExportFormats?: StructureExportFormat[];
    sceneAvailable?: boolean;
    activeMeasurementKind?: MeasurementKind;
  }>(),
  {
    autoRotating: false,
    informationOpen: false,
    informationAvailable: false,
    imageExporting: false,
    structureExporting: false,
    structureExportFormats: () => [],
    sceneAvailable: false,
    activeMeasurementKind: undefined,
  },
);
const emit = defineEmits<{
  reset: [];
  toggleAutoRotation: [];
  toggleSettings: [];
  toggleInformation: [];
  exportImage: [format: ImageExportFormat];
  exportScene: [];
  exportOfflineHtml: [];
  exportStructure: [format: string];
  fullscreen: [];
  axis: [axis: CrystalCameraAxis];
  measure: [kind: MeasurementKind];
  stopMeasurement: [];
}>();

const measurementMenuOpen = ref(false);
const imageExportMenuOpen = ref(false);
const fileExportMenuOpen = ref(false);
const structureExportMenuOpen = ref(false);
const imageExportTrigger = ref<HTMLElement>();
const imageExportPopover = ref<HTMLElement>();
const imageExportPopoverStyle = ref<Record<string, string>>({});
const imageExportPopoverPositioned = ref(false);
const structureExportTrigger = ref<HTMLElement>();
const structureExportPopover = ref<HTMLElement>();
const structureExportPopoverStyle = ref<Record<string, string>>({});
const imageFormats: Array<{ format: ImageExportFormat; label: string; detail: string }> = [
  { format: 'png', label: 'PNG', detail: 'Lossless high-resolution image' },
  { format: 'jpeg', label: 'JPEG', detail: 'High-quality compressed image' },
  { format: 'tiff', label: 'TIFF', detail: 'Lossless TIFF image (.tif)' },
  { format: 'svg', label: 'SVG', detail: 'Scalable vector graphic' },
  { format: 'pdf-vector', label: 'PDF (Vector)', detail: 'Editable publication-quality vectors' },
  { format: 'pdf-raster', label: 'PDF (Raster)', detail: 'High-fidelity lossless WebGL rendering' },
];
const measurementItems: Array<{ kind: MeasurementKind; label: string }> = [
  { kind: 'distance', label: 'Atom-to-atom distance' },
  { kind: 'angle', label: 'Bond angle' },
  { kind: 'dihedral', label: 'Dihedral angle' },
  { kind: 'cell', label: 'Cell parameters' },
  { kind: 'bond_stats', label: 'Bond statistics' },
  { kind: 'atom_plane', label: 'Atom-to-plane distance' },
  { kind: 'plane_plane', label: 'Plane-to-plane angle' },
  { kind: 'coordination', label: 'Coordination number' },
  { kind: 'nearest_neighbors', label: 'Nearest neighbors' },
];

const measurementEnabled = (kind: MeasurementKind): boolean =>
  props.sceneAvailable && (kind !== 'cell' || props.crystal);

const selectMeasurement = (kind: MeasurementKind): void => {
  if (!measurementEnabled(kind)) return;
  measurementMenuOpen.value = false;
  emit('measure', kind);
};

const handleMeasurementButton = (): void => {
  if (props.activeMeasurementKind) {
    emit('stopMeasurement');
    return;
  }
  toggleMeasurementMenu();
};

const selectImageFormat = (format: ImageExportFormat): void => {
  imageExportMenuOpen.value = false;
  imageExportPopoverPositioned.value = false;
  emit('exportImage', format);
};

const selectFileExport = (format: 'html' | 'json'): void => {
  fileExportMenuOpen.value = false;
  if (format === 'html') emit('exportOfflineHtml');
  else emit('exportScene');
};

const selectStructureFormat = (format: string): void => {
  structureExportMenuOpen.value = false;
  fileExportMenuOpen.value = false;
  emit('exportStructure', format);
};

const positionPopoverWithinViewport = (
  trigger: HTMLElement,
  popover: HTMLElement,
): Record<string, string> => {
  const viewportPadding = 12;
  const maxHeight = Math.max(window.innerHeight - viewportPadding * 2, 80);
  const estimatedHeight = popover.children.length * 48 + 14;
  const measuredHeight = Math.max(
    popover.scrollHeight,
    popover.getBoundingClientRect().height,
    estimatedHeight,
  );
  const menuHeight = Math.min(measuredHeight, maxHeight);
  const triggerBounds = trigger.getBoundingClientRect();
  const anchorBounds = trigger.parentElement?.getBoundingClientRect() ?? triggerBounds;
  const preferredTop = triggerBounds.top - 6;
  const top = Math.min(
    Math.max(preferredTop, viewportPadding),
    Math.max(viewportPadding, window.innerHeight - menuHeight - viewportPadding),
  );

  return {
    top: `${Math.round(top - anchorBounds.top)}px`,
    maxHeight: `${Math.round(maxHeight)}px`,
  };
};

const positionImageExportMenu = (): void => {
  const trigger = imageExportTrigger.value;
  const popover = imageExportPopover.value;
  if (!trigger || !popover) return;
  imageExportPopoverStyle.value = positionPopoverWithinViewport(trigger, popover);
  imageExportPopoverPositioned.value = true;
};

const scheduleImageExportMenuPosition = (hideUntilPositioned = false): void => {
  if (hideUntilPositioned) imageExportPopoverPositioned.value = false;
  void nextTick(positionImageExportMenu);
};

const positionStructureExportMenu = (): void => {
  const trigger = structureExportTrigger.value;
  const popover = structureExportPopover.value;
  if (!trigger || !popover) return;

  const viewportPadding = 12;
  const availableHeight = Math.max(window.innerHeight - viewportPadding * 2, 80);
  const maxHeight = availableHeight;
  const menuHeight = Math.min(popover.scrollHeight, maxHeight);
  const triggerBounds = trigger.getBoundingClientRect();
  const anchorBounds = trigger.parentElement?.getBoundingClientRect() ?? triggerBounds;
  const idealTop = triggerBounds.top + triggerBounds.height / 2 - menuHeight / 2;
  const top = Math.min(
    Math.max(idealTop, viewportPadding),
    Math.max(viewportPadding, window.innerHeight - menuHeight - viewportPadding),
  );

  structureExportPopoverStyle.value = {
    top: `${Math.round(top - anchorBounds.top)}px`,
    maxHeight: `${Math.round(maxHeight)}px`,
  };
};

const openStructureExportMenu = (): void => {
  if (!props.structureExportFormats.length || props.structureExporting) return;
  structureExportMenuOpen.value = true;
  void nextTick(positionStructureExportMenu);
};

const toggleStructureExportMenu = (): void => {
  if (!props.structureExportFormats.length || props.structureExporting) return;
  if (structureExportMenuOpen.value) {
    structureExportMenuOpen.value = false;
  } else {
    openStructureExportMenu();
  }
};

const repositionOpenStructureExportMenu = (): void => {
  if (structureExportMenuOpen.value) positionStructureExportMenu();
};

const repositionOpenExportMenus = (): void => {
  if (imageExportMenuOpen.value) scheduleImageExportMenuPosition();
  repositionOpenStructureExportMenu();
};

onMounted(() => window.addEventListener('resize', repositionOpenExportMenus));
onBeforeUnmount(() => {
  window.removeEventListener('resize', repositionOpenExportMenus);
});

const toggleImageExportMenu = (): void => {
  imageExportMenuOpen.value = !imageExportMenuOpen.value;
  measurementMenuOpen.value = false;
  fileExportMenuOpen.value = false;
  structureExportMenuOpen.value = false;
  if (imageExportMenuOpen.value) scheduleImageExportMenuPosition(true);
  else imageExportPopoverPositioned.value = false;
};

const toggleFileExportMenu = (): void => {
  fileExportMenuOpen.value = !fileExportMenuOpen.value;
  measurementMenuOpen.value = false;
  imageExportMenuOpen.value = false;
  imageExportPopoverPositioned.value = false;
  structureExportMenuOpen.value = false;
};

const closeAllMenus = (): void => {
  measurementMenuOpen.value = false;
  imageExportMenuOpen.value = false;
  imageExportPopoverPositioned.value = false;
  fileExportMenuOpen.value = false;
  structureExportMenuOpen.value = false;
};

const handleInformationButton = (): void => {
  if (!props.informationAvailable) return;
  closeAllMenus();
  emit('toggleInformation');
};

const toggleMeasurementMenu = (): void => {
  measurementMenuOpen.value = !measurementMenuOpen.value;
  imageExportMenuOpen.value = false;
  imageExportPopoverPositioned.value = false;
  fileExportMenuOpen.value = false;
  structureExportMenuOpen.value = false;
};

const closeMeasurementMenuOnFocusOut = (event: FocusEvent): void => {
  const menu = event.currentTarget as HTMLElement;
  if (!menu.contains(event.relatedTarget as Node | null)) measurementMenuOpen.value = false;
};

const closeImageMenuOnFocusOut = (event: FocusEvent): void => {
  const menu = event.currentTarget as HTMLElement;
  if (!menu.contains(event.relatedTarget as Node | null)) {
    imageExportMenuOpen.value = false;
    imageExportPopoverPositioned.value = false;
  }
};

const closeFileMenuOnFocusOut = (event: FocusEvent): void => {
  const menu = event.currentTarget as HTMLElement;
  if (!menu.contains(event.relatedTarget as Node | null)) {
    fileExportMenuOpen.value = false;
    structureExportMenuOpen.value = false;
  }
};
</script>

<template>
  <nav
    class="viewer-toolbar"
    :class="{ 'has-open-export-menu': imageExportMenuOpen || fileExportMenuOpen }"
    aria-label="Crystal viewer tools"
    @keydown.esc="closeAllMenus"
  >
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
    <button
      class="toolbar-auto-rotate"
      type="button"
      :title="autoRotating ? 'Stop rotation' : 'Auto rotate'"
      :aria-label="autoRotating ? 'Stop rotation' : 'Auto rotate'"
      :aria-pressed="autoRotating"
      @click="emit('toggleAutoRotation')"
    >
      <svg
        v-if="!autoRotating"
        class="toolbar-filled-icon auto-rotate-icon"
        viewBox="0 0 1024 1024"
        aria-hidden="true"
      >
        <path
          transform="translate(512 512) scale(.92) translate(-512 -512)"
          d="M148.032 581.504c4.736 26.88 16.832 51.2 34.112 70.848-22.848 19.648-31.872 38.784-31.872 54.016 0 24.96 24.512 60.544 94.528 91.968 11.84 5.312 24.64 10.048 38.144 14.656l12.672-32.96a12.8 12.8 0 0 1 21.952-3.52l90.688 112a12.8 12.8 0 0 1-7.936 20.672l-142.336 22.592a12.8 12.8 0 0 1-13.952-17.216l11.328-29.632c-14.72-5.12-28.8-10.56-42.048-16.512-74.752-33.6-139.776-87.936-139.84-162.048 0-51.136 30.848-92.864 74.56-124.8Zm727.68 0c43.776 32 74.752 73.664 74.752 124.8 0 74.24-65.088 128.512-139.84 162.112-63.744 28.608-145.536 47.36-235.456 53.568v-76.992c80.32-5.952 151.04-22.912 203.968-46.656 70.016-31.424 94.528-66.944 94.528-91.968 0-15.296-9.088-34.368-32-54.08 17.28-19.648 29.312-43.904 34.112-70.784ZM460.672 105.728a102.528 102.528 0 0 1 102.528 0l204.736 118.208c31.68 18.304 51.2 52.16 51.2 88.704V549.12c0 36.544-19.52 70.4-51.2 88.704l-204.8 118.208a102.464 102.464 0 0 1-102.4 0L256 637.824a102.592 102.592 0 0 1-51.2-88.704V312.64c0-36.544 19.52-70.4 51.2-88.64l204.672-118.272Zm89.408 344.32v224.768L729.536 571.2a25.6 25.6 0 0 0 12.8-22.08l-.064-208.384-192.192 109.376ZM281.6 549.12a25.6 25.6 0 0 0 12.8 22.144l178.88 103.296V449.536L281.536 338.304l.064 210.816Zm243.072-376.832a25.6 25.6 0 0 0-25.6 0L323.392 273.856 512 383.36l190.528-108.416-177.856-102.656Z"
        />
      </svg>
      <svg v-else viewBox="0 0 24 24" aria-hidden="true">
        <path d="M9 7.5v9M15 7.5v9" />
      </svg>
    </button>
    <div
      class="toolbar-export-menu toolbar-measurement-menu"
      @focusout="closeMeasurementMenuOnFocusOut"
    >
      <button
        type="button"
        :title="
          activeMeasurementKind
            ? `Stop ${measurementTitle(activeMeasurementKind).toLowerCase()}`
            : 'Measurements'
        "
        :aria-label="activeMeasurementKind ? 'Stop measurement' : 'Measurements'"
        :aria-haspopup="activeMeasurementKind ? undefined : 'menu'"
        :aria-expanded="activeMeasurementKind ? undefined : measurementMenuOpen"
        :aria-pressed="activeMeasurementKind ? true : undefined"
        :disabled="!sceneAvailable && !activeMeasurementKind"
        @click="handleMeasurementButton"
      >
        <svg
          v-if="!activeMeasurementKind"
          class="toolbar-filled-icon measurement-toolbar-icon"
          viewBox="0 0 1024 1024"
          aria-hidden="true"
        >
          <path
            d="M.49 708.146 316.34 1023.996l707.646-707.646L708.136.5 607.172 101.464l-31.608 31.496-47.69 47.692-26.248 26.246-70.586 70.586-13.738 13.738L.49 708.146Zm315.85 236.888L79.454 708.036l61.426-61.432 118.5 118.504 31.606-31.608-118.5-118.502 47.354-47.354 78.964 78.958 31.606-31.606-78.962-78.96 47.356-47.354 78.962 78.962 31.606-31.608-78.962-78.962 47.356-47.356 118.498 118.5 31.608-31.608-118.5-118.5 47.356-47.354 78.962 78.96 31.606-31.608-78.96-78.96 47.354-47.356 78.96 78.962 31.606-31.606-78.96-78.962 47.69-47.69 118.502 118.5 31.606-31.606-118.388-118.5 61.43-61.426 236.886 236.886L316.34 945.034Z"
          />
        </svg>
        <svg v-else class="measurement-stop-icon" viewBox="0 0 24 24" aria-hidden="true">
          <rect x="7" y="7" width="10" height="10" rx="1" />
        </svg>
      </button>
      <div
        v-if="measurementMenuOpen"
        class="toolbar-export-popover toolbar-measurement-popover"
        role="menu"
        aria-label="Measurement tools"
      >
        <button
          v-for="item in measurementItems"
          :key="item.kind"
          class="toolbar-measurement-option"
          type="button"
          role="menuitem"
          :disabled="!measurementEnabled(item.kind)"
          @click="selectMeasurement(item.kind)"
        >
          {{ item.label }}
        </button>
      </div>
    </div>
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
    <div v-if="crystal" class="toolbar-separator" />
    <button
      v-if="crystal"
      class="axis-button reciprocal-axis-button"
      data-toolbar-axis="a*"
      type="button"
      title="View along reciprocal a* axis"
      @click="emit('axis', 'a*')"
    >
      a*
    </button>
    <button
      v-if="crystal"
      class="axis-button reciprocal-axis-button"
      data-toolbar-axis="b*"
      type="button"
      title="View along reciprocal b* axis"
      @click="emit('axis', 'b*')"
    >
      b*
    </button>
    <button
      v-if="crystal"
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
      v-if="crystal"
      class="toolbar-information"
      type="button"
      title="Fractional coordinates"
      :aria-pressed="informationOpen"
      aria-label="Structure information"
      :disabled="!informationAvailable"
      @click="handleInformationButton"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="12" cy="12" r="8.5" />
        <path d="M12 10.5v6" />
        <path d="M12 7.5h.01" />
      </svg>
    </button>
    <div class="toolbar-export-menu toolbar-image-menu" @focusout="closeImageMenuOnFocusOut">
      <button
        ref="imageExportTrigger"
        type="button"
        title="Export image"
        aria-label="Export image"
        aria-haspopup="menu"
        :aria-expanded="imageExportMenuOpen"
        :disabled="imageExporting"
        @click="toggleImageExportMenu"
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
      <div
        v-if="imageExportMenuOpen"
        ref="imageExportPopover"
        class="toolbar-export-popover toolbar-image-export-popover"
        :class="{ 'is-positioning': !imageExportPopoverPositioned }"
        role="menu"
        aria-label="Image formats"
        :style="imageExportPopoverStyle"
      >
        <button
          v-for="option in imageFormats"
          :key="option.format"
          class="toolbar-export-option"
          type="button"
          role="menuitem"
          @click="selectImageFormat(option.format)"
        >
          <strong>{{ option.label }}</strong>
          <span>{{ option.detail }}</span>
        </button>
      </div>
    </div>
    <div class="toolbar-export-menu toolbar-file-menu" @focusout="closeFileMenuOnFocusOut">
      <button
        type="button"
        title="Export file"
        aria-label="Export file"
        aria-haspopup="menu"
        :aria-expanded="fileExportMenuOpen"
        @click="toggleFileExportMenu"
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
      <div
        v-if="fileExportMenuOpen"
        class="toolbar-export-popover"
        role="menu"
        aria-label="File exports"
      >
        <div
          class="toolbar-export-submenu"
          @mouseenter="openStructureExportMenu"
          @mouseleave="structureExportMenuOpen = false"
        >
          <button
            ref="structureExportTrigger"
            class="toolbar-export-option toolbar-export-submenu-trigger"
            type="button"
            role="menuitem"
            aria-haspopup="menu"
            :aria-expanded="structureExportMenuOpen"
            :disabled="!structureExportFormats.length || structureExporting"
            @click.stop="toggleStructureExportMenu"
          >
            <strong>Structure file <span class="submenu-arrow" aria-hidden="true">‹</span></strong>
            <span>
              {{
                structureExporting
                  ? 'Exporting…'
                  : structureExportFormats.length
                    ? `${structureExportFormats.length} formats`
                    : 'Waiting for formats'
              }}
            </span>
          </button>
          <div
            v-if="structureExportMenuOpen"
            ref="structureExportPopover"
            class="toolbar-export-popover toolbar-export-subpopover"
            role="menu"
            aria-label="Structure file formats"
            :style="structureExportPopoverStyle"
          >
            <button
              v-for="option in structureExportFormats"
              :key="option.format"
              class="toolbar-export-option"
              type="button"
              role="menuitem"
              @click="selectStructureFormat(option.format)"
            >
              <strong>{{ option.label }}</strong>
              <span>{{ option.detail }}</span>
            </button>
          </div>
        </div>
        <button
          class="toolbar-export-option"
          type="button"
          role="menuitem"
          @click="selectFileExport('html')"
        >
          <strong>Offline HTML</strong>
          <span>Interactive single-file viewer</span>
        </button>
        <button
          class="toolbar-export-option"
          type="button"
          role="menuitem"
          @click="selectFileExport('json')"
        >
          <strong>Scene JSON</strong>
          <span>Raw atomic scene data</span>
        </button>
      </div>
    </div>
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
