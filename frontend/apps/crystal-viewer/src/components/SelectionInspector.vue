<script setup lang="ts">
import { computed } from 'vue';

import type { SelectionInfo } from '../scene/types';

const props = defineProps<{ selection?: SelectionInfo }>();

const title = computed(() => {
  if (props.selection?.kind === 'atom') return props.selection.site?.label ?? 'Atom';
  if (props.selection?.kind === 'bond') return 'Bond';
  return '';
});

const position = computed(() =>
  props.selection?.atom?.position.map((value) => value.toFixed(4)).join(', '),
);
</script>

<template>
  <aside v-if="selection" class="selection-inspector">
    <h2>{{ title }}</h2>
    <template v-if="selection.kind === 'atom' && selection.site">
      <p>Site {{ selection.site.siteIndex + 1 }}</p>
      <dl>
        <dt>Position</dt>
        <dd>{{ position }} Å</dd>
        <template v-if="selection.site.fractional">
          <dt>Fractional</dt>
          <dd>{{ selection.site.fractional.map((value) => value.toFixed(4)).join(', ') }}</dd>
        </template>
        <dt>Occupancy</dt>
        <dd>
          {{ selection.site.species.map((item) => `${item.symbol} ${item.occupancy}`).join(' · ') }}
        </dd>
      </dl>
    </template>
    <template v-else-if="selection.bond">
      <p>Sites {{ selection.bond.fromSiteIndex + 1 }}–{{ selection.bond.toSiteIndex + 1 }}</p>
      <dl>
        <dt>Distance</dt>
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
