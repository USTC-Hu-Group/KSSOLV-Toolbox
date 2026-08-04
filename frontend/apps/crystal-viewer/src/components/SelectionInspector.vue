<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';

import {
  expectedSelectionCount,
  measurementPrompt,
  measurementStopHint,
  measurementTitle,
  type MeasurementKind,
  type MeasurementRecord,
} from '../measurement';
import type { SelectionInfo } from '../scene/types';
import MeasurementGeometry from './MeasurementGeometry.vue';

const props = defineProps<{
  selection?: SelectionInfo;
  measurement?: MeasurementRecord;
  measurementError?: string;
  measurementKind?: MeasurementKind;
  measurementSelectionCount?: number;
}>();
defineEmits<{ closeMeasurement: [] }>();

const showsMeasurement = computed(() => !!props.measurement || !!props.measurementError);
const showsMeasurementGuide = computed(() => !!props.measurementKind && !showsMeasurement.value);
const guideTitle = computed(() =>
  props.measurementKind ? measurementTitle(props.measurementKind) : '',
);
const guideExpectedCount = computed(() =>
  props.measurementKind ? expectedSelectionCount(props.measurementKind) : 0,
);
const guidePrompt = computed(() =>
  props.measurementKind
    ? measurementPrompt(props.measurementKind, props.measurementSelectionCount ?? 0)
    : '',
);

const title = computed(() => {
  if (props.selection?.kind === 'atom') return props.selection.site?.label ?? 'Atom';
  if (props.selection?.kind === 'bond') return 'Bond';
  return '';
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
  if (!image?.some((value) => value !== 0)) return undefined;
  return image.join(', ');
});

const occupancy = computed(() =>
  props.selection?.site?.species.map((item) => `${item.symbol} ${item.occupancy}`).join(' · '),
);

type CopyTarget = 'cartesian' | 'fractional' | 'cell-lengths' | 'cell-angles' | 'cell-volume';

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

const copyCoordinate = async (kind: 'cartesian' | 'fractional'): Promise<void> => {
  const coordinates =
    kind === 'cartesian' ? cartesianCoordinates.value : fractionalCoordinates.value;
  if (!coordinates) return;
  try {
    const unit = kind === 'cartesian' ? ' Å' : '';
    await writeClipboard(`${coordinates.map((value) => String(value)).join(', ')}${unit}`);
    showCopyFeedback(kind);
  } catch {
    copiedValue.value = undefined;
  }
};

const showCopyFeedback = (target: CopyTarget): void => {
  copiedValue.value = target;
  if (copyFeedbackTimer !== undefined) window.clearTimeout(copyFeedbackTimer);
  copyFeedbackTimer = window.setTimeout(() => {
    copiedValue.value = undefined;
  }, 1400);
};

const copyCellValues = async (
  target: 'cell-lengths' | 'cell-angles' | 'cell-volume',
): Promise<void> => {
  const values = props.measurement?.cellValues;
  if (!values) return;
  const text =
    target === 'cell-lengths'
      ? [
          `a = ${values.lengths[0]} Å`,
          `b = ${values.lengths[1]} Å`,
          `c = ${values.lengths[2]} Å`,
        ].join('\n')
      : target === 'cell-angles'
        ? [`α = ${values.angles[0]}°`, `β = ${values.angles[1]}°`, `γ = ${values.angles[2]}°`].join(
            '\n',
          )
        : `Volume = ${values.volume} Å³`;
  try {
    await writeClipboard(text);
    showCopyFeedback(target);
  } catch {
    copiedValue.value = undefined;
  }
};

onBeforeUnmount(() => {
  if (copyFeedbackTimer !== undefined) window.clearTimeout(copyFeedbackTimer);
});

const measurementSummaryDisplay = computed(() => {
  const summary = props.measurement?.summary ?? '';
  const separator = summary.indexOf(':');
  if (separator <= 0) {
    return { label: 'Result', value: summary, compact: summary.length > 24 };
  }
  const label = summary.slice(0, separator);
  const value = summary.slice(separator + 1).trim();
  return { label, value, compact: value.length > 24 };
});

const measurementDetailRows = computed(() =>
  (props.measurement?.details ?? '')
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      const separator = line.indexOf(':');
      if (separator <= 0) return { label: '', value: line, items: undefined };
      return {
        label: line.slice(0, separator),
        value: line.slice(separator + 1).trim(),
        items:
          line.slice(0, separator).toLowerCase() === 'sites'
            ? line
                .slice(separator + 1)
                .trim()
                .split(' – ')
            : undefined,
      };
    }),
);

const showsMeasurementGeometry = computed(() => {
  const measurement = props.measurement;
  return !!(
    measurement?.diagram?.points.length &&
    measurement.siteLabels?.length === measurement.diagram.points.length
  );
});
</script>

<template>
  <aside
    v-if="showsMeasurement || showsMeasurementGuide || selection"
    class="selection-inspector"
    :class="{ 'measurement-mode': showsMeasurement || showsMeasurementGuide }"
    aria-live="polite"
  >
    <template v-if="showsMeasurement">
      <header class="inspector-header measurement-result-header">
        <div class="measurement-result-heading">
          <h2>{{ measurement?.title ?? 'Measurement error' }}</h2>
        </div>
        <button
          type="button"
          class="inspector-close"
          aria-label="Close measurement result"
          title="Close"
          @click="$emit('closeMeasurement')"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="m7 7 10 10M17 7 7 17" />
          </svg>
        </button>
      </header>
      <div v-if="measurement?.kind === 'cell' && measurement.cellValues" class="cell-measurement">
        <section class="cell-parameter-section cell-lengths">
          <header>
            <span>Lengths</span>
            <button
              type="button"
              class="coordinate-copy"
              :class="{ copied: copiedValue === 'cell-lengths' }"
              :aria-label="
                copiedValue === 'cell-lengths' ? 'Cell lengths copied' : 'Copy cell lengths'
              "
              :title="copiedValue === 'cell-lengths' ? 'Copied' : 'Copy lengths'"
              @click="copyCellValues('cell-lengths')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="copiedValue === 'cell-lengths'" d="m7 12 3 3 7-7" />
                <template v-else>
                  <rect x="8" y="8" width="9" height="9" rx="1.5" />
                  <path
                    d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6"
                  />
                </template>
              </svg>
            </button>
          </header>
          <div class="cell-parameter-list">
            <div v-for="(value, index) in measurement.cellValues.lengths" :key="index">
              <span>{{ ['a', 'b', 'c'][index] }}</span>
              <strong>{{ value.toFixed(5) }}</strong>
              <small>Å</small>
            </div>
          </div>
        </section>
        <section class="cell-parameter-section">
          <header>
            <span>Angles</span>
            <button
              type="button"
              class="coordinate-copy"
              :class="{ copied: copiedValue === 'cell-angles' }"
              :aria-label="
                copiedValue === 'cell-angles' ? 'Cell angles copied' : 'Copy cell angles'
              "
              :title="copiedValue === 'cell-angles' ? 'Copied' : 'Copy angles'"
              @click="copyCellValues('cell-angles')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="copiedValue === 'cell-angles'" d="m7 12 3 3 7-7" />
                <template v-else>
                  <rect x="8" y="8" width="9" height="9" rx="1.5" />
                  <path
                    d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6"
                  />
                </template>
              </svg>
            </button>
          </header>
          <div class="cell-parameter-list">
            <div v-for="(value, index) in measurement.cellValues.angles" :key="index">
              <span>{{ ['α', 'β', 'γ'][index] }}</span>
              <strong>{{ value.toFixed(3) }}</strong>
              <small>°</small>
            </div>
          </div>
        </section>
        <section class="cell-parameter-section cell-volume">
          <header>
            <span>Volume</span>
            <button
              type="button"
              class="coordinate-copy"
              :class="{ copied: copiedValue === 'cell-volume' }"
              :aria-label="
                copiedValue === 'cell-volume' ? 'Cell volume copied' : 'Copy cell volume'
              "
              :title="copiedValue === 'cell-volume' ? 'Copied' : 'Copy volume'"
              @click="copyCellValues('cell-volume')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="copiedValue === 'cell-volume'" d="m7 12 3 3 7-7" />
                <template v-else>
                  <rect x="8" y="8" width="9" height="9" rx="1.5" />
                  <path
                    d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6"
                  />
                </template>
              </svg>
            </button>
          </header>
          <p>
            <strong>{{ measurement.cellValues.volume.toFixed(5) }}</strong>
            <span>Å³</span>
          </p>
        </section>
      </div>
      <div
        v-else-if="measurement?.kind === 'bond_stats' && measurement.bondStatistics"
        class="bond-statistics"
      >
        <section class="bond-statistics-summary">
          <span class="bond-statistics-pair">{{ measurement.bondStatistics.pairLabel }}</span>
          <div v-if="measurement.bondStatistics.count" class="bond-statistics-primary">
            <div>
              <span>Bonds</span>
              <strong>{{ measurement.bondStatistics.count }}</strong>
            </div>
            <div>
              <span>Average</span>
              <strong>
                {{ measurement.bondStatistics.average?.toFixed(5) }}
                <small>Å</small>
              </strong>
            </div>
          </div>
          <strong v-else class="bond-statistics-empty">No bonds found</strong>
        </section>
        <section v-if="measurement.bondStatistics.count" class="bond-statistics-range">
          <div>
            <span>Minimum</span>
            <strong>
              {{ measurement.bondStatistics.minimum?.toFixed(5) }}
              <small>Å</small>
            </strong>
          </div>
          <div>
            <span>Maximum</span>
            <strong>
              {{ measurement.bondStatistics.maximum?.toFixed(5) }}
              <small>Å</small>
            </strong>
          </div>
        </section>
        <section class="bond-statistics-algorithm">
          <span>Algorithm</span>
          <strong>{{ measurement.bondStatistics.algorithm }}</strong>
        </section>
      </div>
      <div v-else-if="measurement" class="measurement-result">
        <span>{{ measurementSummaryDisplay.label }}</span>
        <strong :class="{ compact: measurementSummaryDisplay.compact }">
          {{ measurementSummaryDisplay.value }}
        </strong>
      </div>
      <ol
        v-if="
          measurement?.neighbors &&
          (measurement.kind === 'coordination' || measurement.kind === 'nearest_neighbors')
        "
        class="measurement-neighbor-list"
      >
        <li
          v-for="(neighbor, index) in measurement.neighbors"
          :key="`${index}-${neighbor.siteIndex}`"
        >
          <span class="measurement-neighbor-identity">
            {{ index + 1 }}. #{{ neighbor.siteIndex + 1 }} {{ neighbor.label }} · image [{{
              neighbor.image.join(', ')
            }}]
          </span>
          <strong class="measurement-neighbor-distance">
            {{ neighbor.distance.toFixed(5) }}&nbsp;Å
          </strong>
        </li>
      </ol>
      <div
        v-else-if="
          measurement?.kind !== 'cell' &&
          measurement?.kind !== 'bond_stats' &&
          measurementDetailRows.length
        "
        class="measurement-details"
      >
        <div
          v-for="(row, index) in measurementDetailRows"
          :key="index"
          class="measurement-row"
          :class="{ 'measurement-geometry-row': row.items && showsMeasurementGeometry }"
        >
          <span v-if="row.label" class="measurement-detail-label">
            {{ row.items && showsMeasurementGeometry ? 'Geometry' : row.label }}
          </span>
          <MeasurementGeometry
            v-if="row.items && showsMeasurementGeometry && measurement"
            :measurement="measurement"
          />
          <div v-else-if="row.items" class="measurement-site-path">
            <template v-for="(item, itemIndex) in row.items" :key="`${itemIndex}-${item}`">
              <span v-if="itemIndex" class="measurement-path-arrow">→</span>
              <span class="measurement-site-token">{{ item }}</span>
            </template>
          </div>
          <p v-else>{{ row.value }}</p>
        </div>
      </div>
      <p v-if="measurementError" class="measurement-error">{{ measurementError }}</p>
    </template>
    <template v-else-if="showsMeasurementGuide">
      <header class="inspector-header measurement-guide-header">
        <div>
          <div class="inspector-eyebrow">Measurement mode</div>
          <h2>{{ guideTitle }}</h2>
        </div>
        <strong class="measurement-progress">
          {{ measurementSelectionCount ?? 0 }}/{{ guideExpectedCount }}
        </strong>
      </header>
      <p class="measurement-guide">{{ guidePrompt }}</p>
      <p class="measurement-stop-hint">
        <em>({{ measurementStopHint }})</em>
      </p>
    </template>
    <template v-else-if="selection">
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
                :aria-label="
                  copiedValue === 'cartesian'
                    ? 'Cartesian coordinates copied'
                    : 'Copy Cartesian coordinates'
                "
                :title="
                  copiedValue === 'cartesian'
                    ? 'Copied'
                    : 'Copy full-precision Cartesian coordinates'
                "
                @click="copyCoordinate('cartesian')"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path v-if="copiedValue === 'cartesian'" d="m7 12 3 3 7-7" />
                  <template v-else>
                    <rect x="8" y="8" width="9" height="9" rx="1.5" />
                    <path
                      d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6"
                    />
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
                :aria-label="
                  copiedValue === 'fractional'
                    ? 'Fractional coordinates copied'
                    : 'Copy Fractional coordinates'
                "
                :title="
                  copiedValue === 'fractional'
                    ? 'Copied'
                    : 'Copy full-precision Fractional coordinates'
                "
                @click="copyCoordinate('fractional')"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path v-if="copiedValue === 'fractional'" d="m7 12 3 3 7-7" />
                  <template v-else>
                    <rect x="8" y="8" width="9" height="9" rx="1.5" />
                    <path
                      d="M6 14H5.5A1.5 1.5 0 0 1 4 12.5v-7A1.5 1.5 0 0 1 5.5 4h7A1.5 1.5 0 0 1 14 5.5V6"
                    />
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
    </template>
  </aside>
</template>
