<script setup lang="ts">
import { computed } from 'vue';

import type { MeasurementDiagramPoint, MeasurementRecord } from '../measurement';

const props = defineProps<{ measurement: MeasurementRecord }>();

const width = 214;
const height = 142;
const padding = 22;

interface DiagramPoint {
  x: number;
  y: number;
}

const fittedGeometry = computed(() => {
  const diagram = props.measurement.diagram;
  if (!diagram?.points.length) return undefined;
  const coordinates = [
    ...diagram.points,
    ...(diagram.projection ? [diagram.projection] : []),
  ].filter((point) => point.every(Number.isFinite));
  if (!coordinates.length) return undefined;
  const xs = coordinates.map((point) => point[0]);
  const ys = coordinates.map((point) => point[1]);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const spanX = maxX - minX;
  const spanY = maxY - minY;
  const horizontalScale = spanX > 1e-9 ? (width - padding * 2) / spanX : Infinity;
  const verticalScale = spanY > 1e-9 ? (height - padding * 2) / spanY : Infinity;
  const finiteScale = Math.min(horizontalScale, verticalScale);
  const scale = Number.isFinite(finiteScale) ? finiteScale : 1;
  const centerX = (minX + maxX) * 0.5;
  const centerY = (minY + maxY) * 0.5;
  const fit = ([x, y]: MeasurementDiagramPoint): DiagramPoint => ({
    x: width * 0.5 + (x - centerX) * scale,
    y: height * 0.5 + (y - centerY) * scale,
  });
  const points = diagram.points.map(fit);
  let projection = diagram.projection ? fit(diagram.projection) : undefined;
  if (props.measurement.kind === 'atom_plane' && points[0] && projection) {
    const planePoints = points.slice(1, 4);
    if (planePoints.length === 3) {
      const planeCenter = {
        x: planePoints.reduce((sum, point) => sum + point.x, 0) / 3,
        y: planePoints.reduce((sum, point) => sum + point.y, 0) / 3,
      };
      const direction = {
        x: points[0].x - projection.x,
        y: points[0].y - projection.y,
      };
      const directionLength = Math.hypot(direction.x, direction.y);
      const unitDirection =
        directionLength > 1e-6
          ? { x: direction.x / directionLength, y: direction.y / directionLength }
          : { x: 0, y: -1 };
      points[0] = {
        x: planeCenter.x + unitDirection.x * 58,
        y: planeCenter.y + unitDirection.y * 58,
      };
      projection = planeCenter;
    }
  }
  return {
    points,
    projection,
  };
});

const segmentIndices = computed<Array<[number, number]>>(() => {
  switch (props.measurement.kind) {
    case 'distance':
      return [[0, 1]];
    case 'angle':
      return [
        [0, 1],
        [1, 2],
      ];
    case 'dihedral':
      return [
        [0, 1],
        [1, 2],
        [2, 3],
      ];
    default:
      return [];
  }
});

const planeIndices = computed<number[][]>(() => {
  switch (props.measurement.kind) {
    case 'dihedral':
      return [
        [0, 1, 2],
        [1, 2, 3],
      ];
    case 'atom_plane':
      return [[1, 2, 3]];
    case 'plane_plane':
      return [
        [0, 1, 2],
        [3, 4, 5],
      ];
    default:
      return [];
  }
});

const polygons = computed(() => {
  const points = fittedGeometry.value?.points ?? [];
  return planeIndices.value.flatMap((indices, planeIndex) => {
    const vertices = indices.map((index) => points[index]).filter(Boolean);
    return vertices.length === indices.length
      ? [{ planeIndex, points: vertices.map((point) => `${point.x},${point.y}`).join(' ') }]
      : [];
  });
});

const segments = computed(() => {
  const points = fittedGeometry.value?.points ?? [];
  return segmentIndices.value.flatMap(([startIndex, finishIndex]) => {
    const start = points[startIndex];
    const finish = points[finishIndex];
    return start && finish ? [{ start, finish }] : [];
  });
});

const sites = computed(() => {
  const points = fittedGeometry.value?.points ?? [];
  return (props.measurement.siteLabels ?? []).flatMap((label, index) => {
    const point = points[index];
    if (!point) return [];
    const match = /^(#\d+)\s+(.+)$/.exec(label);
    return [
      {
        label,
        point,
        indexLabel: match?.[1] ?? label,
        elementLabel: match?.[2] ?? '',
      },
    ];
  });
});

const ariaLabel = computed(
  () => `${props.measurement.title} geometry: ${(props.measurement.siteLabels ?? []).join(' to ')}`,
);
</script>

<template>
  <svg
    v-if="fittedGeometry && sites.length"
    class="measurement-geometry"
    :viewBox="`0 0 ${width} ${height}`"
    role="img"
    :aria-label="ariaLabel"
  >
    <polygon
      v-for="polygon in polygons"
      :key="polygon.planeIndex"
      class="measurement-geometry-plane"
      :class="`plane-${polygon.planeIndex + 1}`"
      :points="polygon.points"
    />
    <line
      v-for="(segment, index) in segments"
      :key="index"
      class="measurement-geometry-bond"
      :x1="segment.start.x"
      :y1="segment.start.y"
      :x2="segment.finish.x"
      :y2="segment.finish.y"
    />
    <template
      v-if="
        measurement.kind === 'atom_plane' && fittedGeometry.points[0] && fittedGeometry.projection
      "
    >
      <line
        class="measurement-geometry-distance"
        :x1="fittedGeometry.points[0].x"
        :y1="fittedGeometry.points[0].y"
        :x2="fittedGeometry.projection.x"
        :y2="fittedGeometry.projection.y"
      />
      <circle
        class="measurement-geometry-projection"
        :cx="fittedGeometry.projection.x"
        :cy="fittedGeometry.projection.y"
        r="3"
      />
      <text
        class="measurement-geometry-perpendicular"
        :x="fittedGeometry.projection.x + 5"
        :y="fittedGeometry.projection.y - 4"
        aria-hidden="true"
      >
        ⊥
      </text>
    </template>
    <g
      v-for="(site, index) in sites"
      :key="`${index}-${site.label}`"
      class="measurement-geometry-site"
      :data-site-label="site.label"
      :transform="`translate(${site.point.x} ${site.point.y})`"
    >
      <circle r="15" />
      <text text-anchor="middle" aria-hidden="true">
        <tspan class="measurement-geometry-site-index" x="0" y="-2.5">
          {{ site.indexLabel }}
        </tspan>
        <tspan class="measurement-geometry-site-element" x="0" y="7">
          {{ site.elementLabel }}
        </tspan>
      </text>
      <title>{{ site.label }}</title>
    </g>
  </svg>
</template>
