<script setup lang="ts">
import { computed, ref } from 'vue';

import type { VolumeChannelSpec } from '@kssolv/volume-scene';

import {
  histogramThresholdSign,
  histogramThresholdValueForSign,
  histogramValueAtFraction,
  nearestHistogramRangeBound,
  type HistogramRangeBound,
  type HistogramThresholdSign,
} from './histogramInteraction';

const props = withDefaults(defineProps<{
  channel: VolumeChannelSpec;
  counts?: Uint32Array;
  positiveThreshold: number;
  negativeThreshold: number;
  rangeMinimum: number;
  rangeMaximum: number;
  interaction: 'threshold' | 'range';
  displayScale?: number;
  displayUnits?: string;
}>(), {
  displayScale: 1,
  displayUnits: '',
});
const emit = defineEmits<{
  'select-threshold': [sign: HistogramThresholdSign, value: number];
  'select-range': [bound: HistogramRangeBound, value: number];
}>();
type DragSelection =
  | { interaction: 'threshold'; sign: HistogramThresholdSign }
  | { interaction: 'range'; bound: HistogramRangeBound };
const dragging = ref<DragSelection>();

const bars = computed(() => {
  const counts = props.counts ?? new Uint32Array(72);
  const maximum = Math.max(...counts, 1);
  return Array.from(counts, (count, index) => ({
    x: index,
    height: (count / maximum) * 44,
  }));
});

const marker = (value: number): number =>
  Math.min(
    100,
    Math.max(
      0,
      ((value - props.channel.minimum) /
        (props.channel.maximum - props.channel.minimum || 1)) *
        100,
    ),
  );

const valueAtPointer = (
  clientX: number,
  target: SVGSVGElement,
): number | undefined => {
  const bounds = target.getBoundingClientRect();
  if (bounds.width <= 0) return undefined;
  return histogramValueAtFraction(
    props.channel.minimum,
    props.channel.maximum,
    (clientX - bounds.left) / bounds.width,
  );
};

const emitSelection = (selection: DragSelection, value: number): void => {
  if (selection.interaction === 'threshold') {
    emit(
      'select-threshold',
      selection.sign,
      histogramThresholdValueForSign(
        props.channel.signed,
        selection.sign,
        value,
      ),
    );
  } else {
    emit('select-range', selection.bound, value);
  }
};

const selectThreshold = (event: MouseEvent): void => {
  const target = event.currentTarget as SVGSVGElement | null;
  if (!target) return;
  const value = valueAtPointer(event.clientX, target);
  if (value === undefined) return;
  if (props.interaction === 'threshold') {
    const sign = histogramThresholdSign(props.channel.signed, value);
    emitSelection({ interaction: 'threshold', sign }, value);
  } else {
    emitSelection(
      {
        interaction: 'range',
        bound: nearestHistogramRangeBound(
        props.rangeMinimum,
        props.rangeMaximum,
        value,
        ),
      },
      value,
    );
  }
};

const startDrag = (
  selection: DragSelection,
  event: PointerEvent,
): void => {
  const target = event.currentTarget as SVGElement | null;
  const svg = target?.ownerSVGElement;
  if (!svg) return;
  dragging.value = selection;
  const value = valueAtPointer(event.clientX, svg);
  if (value !== undefined) emitSelection(selection, value);
  try {
    svg.setPointerCapture?.(event.pointerId);
  } catch {
    // Continue updating while the pointer remains over the histogram when
    // capture is unavailable (for example, in embedded or synthetic events).
  }
};

const continueDrag = (event: PointerEvent): void => {
  if (!dragging.value) return;
  const svg = event.currentTarget as SVGSVGElement;
  const value = valueAtPointer(event.clientX, svg);
  if (value !== undefined) emitSelection(dragging.value, value);
};

const stopDrag = (event: PointerEvent): void => {
  const svg = event.currentTarget as SVGSVGElement;
  try {
    if (svg.hasPointerCapture?.(event.pointerId)) {
      svg.releasePointerCapture(event.pointerId);
    }
  } catch {
    // The host may release pointer capture before the component receives
    // pointercancel; clearing local drag state is still sufficient.
  }
  dragging.value = undefined;
};
</script>

<template>
  <div class="histogram" aria-label="Volume value distribution">
    <header class="histogram-header">
      <strong>VALUE DISTRIBUTION</strong>
    </header>
    <svg
      viewBox="0 0 72 48"
      preserveAspectRatio="none"
      :class="['interactive', { dragging: Boolean(dragging) }]"
      :aria-label="interaction === 'threshold'
        ? 'Click the histogram to set an isosurface threshold'
        : 'Click the histogram to adjust the color range'"
      role="img"
      @click="selectThreshold"
      @pointermove="continueDrag"
      @pointerup="stopDrag"
      @pointercancel="stopDrag"
    >
      <rect
        v-for="bar in bars"
        :key="bar.x"
        :x="bar.x"
        :y="48 - bar.height"
        width="0.82"
        :height="bar.height"
        rx="0.2"
      />
      <template v-if="interaction === 'threshold'">
        <g
          v-if="channel.signed"
          class="marker-handle"
          @click.stop
          @pointerdown.stop.prevent="startDrag({ interaction: 'threshold', sign: 'negative' }, $event)"
        >
          <line
            :x1="marker(negativeThreshold) * 0.72"
            :x2="marker(negativeThreshold) * 0.72"
            y1="0"
            y2="48"
            class="marker-hit"
          />
          <line
            :x1="marker(negativeThreshold) * 0.72"
            :x2="marker(negativeThreshold) * 0.72"
            y1="0"
            y2="48"
            class="marker-line negative-marker"
          />
        </g>
        <g
          class="marker-handle"
          @click.stop
          @pointerdown.stop.prevent="startDrag({ interaction: 'threshold', sign: 'positive' }, $event)"
        >
          <line
            :x1="marker(positiveThreshold) * 0.72"
            :x2="marker(positiveThreshold) * 0.72"
            y1="0"
            y2="48"
            class="marker-hit"
          />
          <line
            :x1="marker(positiveThreshold) * 0.72"
            :x2="marker(positiveThreshold) * 0.72"
            y1="0"
            y2="48"
            class="marker-line positive-marker"
          />
        </g>
      </template>
      <template v-else>
        <g
          class="marker-handle"
          @click.stop
          @pointerdown.stop.prevent="startDrag({ interaction: 'range', bound: 'minimum' }, $event)"
        >
          <line
            :x1="marker(rangeMinimum) * 0.72"
            :x2="marker(rangeMinimum) * 0.72"
            y1="0"
            y2="48"
            class="marker-hit"
          />
          <line
            :x1="marker(rangeMinimum) * 0.72"
            :x2="marker(rangeMinimum) * 0.72"
            y1="0"
            y2="48"
            class="marker-line range-minimum-marker"
          />
        </g>
        <g
          class="marker-handle"
          @click.stop
          @pointerdown.stop.prevent="startDrag({ interaction: 'range', bound: 'maximum' }, $event)"
        >
          <line
            :x1="marker(rangeMaximum) * 0.72"
            :x2="marker(rangeMaximum) * 0.72"
            y1="0"
            y2="48"
            class="marker-hit"
          />
          <line
            :x1="marker(rangeMaximum) * 0.72"
            :x2="marker(rangeMaximum) * 0.72"
            y1="0"
            y2="48"
            class="marker-line range-maximum-marker"
          />
        </g>
      </template>
    </svg>
    <div class="histogram-labels">
      <span>{{ (channel.minimum * displayScale).toPrecision(4) }}</span>
      <span>{{ (channel.maximum * displayScale).toPrecision(4) }} {{ displayUnits || channel.units }}</span>
    </div>
  </div>
</template>
