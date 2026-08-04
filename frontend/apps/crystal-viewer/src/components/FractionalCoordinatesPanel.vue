<script setup lang="ts">
import { computed } from 'vue';

import { siteSpeciesLabel } from '../elementSelection';
import type { AtomicSceneSpec } from '../scene/types';

const props = defineProps<{ scene?: AtomicSceneSpec }>();
defineEmits<{ close: [] }>();

const rows = computed(() =>
  (props.scene?.sites ?? []).map((site) => ({
    id: site.siteIndex + 1,
    symbol: siteSpeciesLabel(site),
    label: site.label,
    coordinates: site.fractional?.map((value) => value.toFixed(5)),
  })),
);
</script>

<template>
  <aside class="fractional-coordinates-panel" aria-label="Fractional coordinates">
    <header>
      <h2>Fractional Coordinates</h2>
      <button
        type="button"
        class="close-button"
        aria-label="Close fractional coordinates"
        @click="$emit('close')"
      >
        ×
      </button>
    </header>
    <div class="fractional-coordinates-table-wrap">
      <table v-if="rows.length">
        <thead>
          <tr>
            <th scope="col">ID</th>
            <th scope="col">Symbol</th>
            <th scope="col">Label</th>
            <th scope="col">x</th>
            <th scope="col">y</th>
            <th scope="col">z</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.id">
            <td>{{ row.id }}</td>
            <td>{{ row.symbol }}</td>
            <td>{{ row.label }}</td>
            <td v-for="(coordinate, index) in row.coordinates ?? ['—', '—', '—']" :key="index">
              {{ coordinate }}
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else class="fractional-coordinates-empty">No atomic sites.</p>
    </div>
  </aside>
</template>
