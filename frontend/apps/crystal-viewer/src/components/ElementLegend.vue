<script setup lang="ts">
import { computed } from 'vue';

import type { AtomicSceneSpec, ColorMode } from '../scene/types';

const props = defineProps<{ scene?: AtomicSceneSpec; colorMode: ColorMode }>();

const elements = computed(() => {
  const values = new Map<string, { symbol: string; color: string; foreground: string }>();
  for (const site of props.scene?.sites ?? []) {
    for (const component of site.species) {
      const rgb = props.colorMode === 'vesta' ? component.colorVesta : component.colorJmol;
      values.set(component.symbol, {
        symbol: component.symbol,
        color: `rgb(${rgb.join(',')})`,
        foreground:
          rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722 > 155 ? '#202124' : '#ffffff',
      });
    }
  }
  return [...values.values()].sort((first, second) => first.symbol.localeCompare(second.symbol));
});
</script>

<template>
  <div v-if="elements.length" class="element-legend" aria-label="Element legend">
    <span
      v-for="element in elements"
      :key="element.symbol"
      :style="{
        '--element-color': element.color,
        '--element-foreground': element.foreground,
      }"
    >
      <i :style="{ background: element.color }" />
      {{ element.symbol }}
    </span>
  </div>
</template>
