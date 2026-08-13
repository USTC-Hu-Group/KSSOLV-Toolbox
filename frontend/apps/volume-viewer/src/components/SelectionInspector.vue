<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';

import type { SelectionInfo, SiteSpec } from '@kssolv/atomic-scene';

const props = defineProps<{ selection?: SelectionInfo }>();

const siteSpeciesLabel = (site: SiteSpec): string =>
  [...new Set(site.species.map((component) => component.symbol))].join('/');
const title = computed(() => {
  if (props.selection?.kind === 'atom') {
    return props.selection.site ? siteSpeciesLabel(props.selection.site) : 'Atom';
  }
  return props.selection?.kind === 'bond' ? 'Bond' : '';
});
const cartesianCoordinates = computed(() => props.selection?.atom?.position);
const cartesianPosition = computed(() =>
  cartesianCoordinates.value?.map((value) => value.toFixed(3)).join(', '),
);
const fractionalCoordinates = computed(() => {
  const fractional = props.selection?.site?.fractional;
  const image = props.selection?.atom?.imageOffset;
  if (!fractional || !image) return undefined;
  return fractional.map((value, index) => value + image[index]);
});
const fractionalPosition = computed(() =>
  fractionalCoordinates.value?.map((value) => value.toFixed(3)).join(', '),
);
const imageOffset = computed(() => {
  const image = props.selection?.atom?.imageOffset;
  return image?.some((value) => value !== 0) ? image.join(', ') : undefined;
});
const occupancy = computed(() =>
  props.selection?.site?.species
    .map((component) => `${component.symbol} ${component.occupancy}`)
    .join(' · '),
);

type CopyTarget = 'cartesian' | 'fractional';
const copiedValue = ref<CopyTarget>();
let copyFeedbackTimer: number | undefined;
const writeClipboard = async (text: string): Promise<void> => {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.append(textarea);
  textarea.select();
  const copied = document.execCommand('copy');
  textarea.remove();
  if (!copied) throw new Error('The browser denied clipboard access.');
};
const copyCoordinate = async (kind: CopyTarget): Promise<void> => {
  const coordinates = kind === 'cartesian'
    ? cartesianCoordinates.value
    : fractionalCoordinates.value;
  if (!coordinates) return;
  try {
    await writeClipboard(
      `${coordinates.map((value) => String(value)).join(', ')}${kind === 'cartesian' ? ' Å' : ''}`,
    );
    copiedValue.value = kind;
    if (copyFeedbackTimer !== undefined) window.clearTimeout(copyFeedbackTimer);
    copyFeedbackTimer = window.setTimeout(() => {
      copiedValue.value = undefined;
    }, 1400);
  } catch {
    copiedValue.value = undefined;
  }
};
onBeforeUnmount(() => {
  if (copyFeedbackTimer !== undefined) window.clearTimeout(copyFeedbackTimer);
});
</script>

<template>
  <aside v-if="selection" class="selection-inspector" aria-live="polite">
    <div class="selection-heading">
      <h2>{{ title }}</h2>
      <span v-if="selection.kind === 'atom' && selection.site">
        Site {{ selection.site.siteIndex + 1 }}
      </span>
      <span v-else-if="selection.bond">
        Sites {{ selection.bond.fromSiteIndex + 1 }}–{{ selection.bond.toSiteIndex + 1 }}
      </span>
    </div>

    <template v-if="selection.kind === 'atom' && selection.site">
      <div class="atom-coordinate-stack">
        <section class="atom-coordinate-field">
          <header>
            <span>Cartesian</span>
            <button
              type="button"
              class="coordinate-copy"
              :class="{ copied: copiedValue === 'cartesian' }"
              :aria-label="copiedValue === 'cartesian' ? 'Cartesian coordinates copied' : 'Copy Cartesian coordinates'"
              :title="copiedValue === 'cartesian' ? 'Copied' : 'Copy full-precision Cartesian coordinates'"
              @click="copyCoordinate('cartesian')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="copiedValue === 'cartesian'" d="m7 12 3 3 7-7" />
                <template v-else>
                  <rect x="8" y="8" width="9" height="9" rx="1.5" />
                  <path d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6" />
                </template>
              </svg>
            </button>
          </header>
          <p>{{ cartesianPosition }} Å</p>
        </section>
        <section v-if="fractionalPosition" class="atom-coordinate-field">
          <header>
            <span>Fractional</span>
            <button
              type="button"
              class="coordinate-copy"
              :class="{ copied: copiedValue === 'fractional' }"
              :aria-label="copiedValue === 'fractional' ? 'Fractional coordinates copied' : 'Copy Fractional coordinates'"
              :title="copiedValue === 'fractional' ? 'Copied' : 'Copy full-precision Fractional coordinates'"
              @click="copyCoordinate('fractional')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="copiedValue === 'fractional'" d="m7 12 3 3 7-7" />
                <template v-else>
                  <rect x="8" y="8" width="9" height="9" rx="1.5" />
                  <path d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6" />
                </template>
              </svg>
            </button>
          </header>
          <p>{{ fractionalPosition }}</p>
        </section>
      </div>
      <dl class="selection-data-grid atom-metadata-grid">
        <template v-if="imageOffset">
          <dt>Image</dt>
          <dd>{{ imageOffset }}</dd>
        </template>
        <dt>Occupancy</dt>
        <dd>{{ occupancy }}</dd>
      </dl>
    </template>

    <template v-else-if="selection.bond">
      <dl class="selection-data-grid">
        <dt>Bond length</dt>
        <dd>{{ selection.bond.distance.toFixed(5) }} Å</dd>
        <template v-if="selection.bond.origin">
          <dt>Bond order</dt>
          <dd>{{ selection.bond.order?.toFixed(1) ?? '1.0' }}</dd>
          <dt>Topology</dt>
          <dd>{{ selection.bond.origin }}</dd>
        </template>
        <template v-else>
          <dt>Image</dt>
          <dd>{{ selection.bond.toImage.join(', ') }}</dd>
        </template>
      </dl>
    </template>
  </aside>
</template>
