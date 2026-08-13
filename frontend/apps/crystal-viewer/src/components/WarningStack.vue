<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';

import type { SceneWarning } from '../scene/types';

interface TimedWarning extends SceneWarning {
  id: string;
}

const props = withDefaults(
  defineProps<{
    warnings: SceneWarning[];
    scopeKey?: string;
    timeoutMilliseconds?: number;
    collapsedLimit?: number;
  }>(),
  {
    scopeKey: '',
    timeoutMilliseconds: 5000,
    collapsedLimit: 3,
  },
);
const emit = defineEmits<{ locate: [siteIndices: number[]] }>();

const visibleWarnings = ref<TimedWarning[]>([]);
const expanded = ref(false);
const expiryTimers = new Map<string, number>();
const displayedWarnings = computed(() =>
  expanded.value
    ? visibleWarnings.value
    : visibleWarnings.value.slice(0, Math.max(1, props.collapsedLimit)),
);
const hiddenWarningCount = computed(
  () => visibleWarnings.value.length - displayedWarnings.value.length,
);

const clearExpiryTimers = (): void => {
  for (const timer of expiryTimers.values()) window.clearTimeout(timer);
  expiryTimers.clear();
};

const dismissWarning = (id: string): void => {
  const timer = expiryTimers.get(id);
  if (timer !== undefined) window.clearTimeout(timer);
  expiryTimers.delete(id);
  visibleWarnings.value = visibleWarnings.value.filter((warning) => warning.id !== id);
};

const resetWarnings = (): void => {
  clearExpiryTimers();
  expanded.value = false;
  visibleWarnings.value = props.warnings.map((warning, index) => ({
    ...warning,
    id: `${props.scopeKey}:${index}:${warning.code}`,
  }));
  for (const warning of visibleWarnings.value) {
    if (props.timeoutMilliseconds <= 0) continue;
    expiryTimers.set(
      warning.id,
      window.setTimeout(() => dismissWarning(warning.id), props.timeoutMilliseconds),
    );
  }
};

watch(() => [props.scopeKey, props.warnings] as const, resetWarnings, {
  deep: true,
  immediate: true,
});
onBeforeUnmount(clearExpiryTimers);
</script>

<template>
  <div v-if="visibleWarnings.length" class="warning-stack" aria-live="polite">
    <div v-for="warning in displayedWarnings" :key="warning.id" :class="warning.severity">
      <span>{{ warning.message }}</span>
      <button
        v-if="warning.siteIndices?.length"
        type="button"
        class="warning-locate"
        aria-label="Locate affected atoms"
        title="Locate affected atoms"
        @click="emit('locate', warning.siteIndices)"
      >
        Locate
      </button>
      <button
        type="button"
        class="warning-dismiss"
        aria-label="Dismiss warning"
        title="Dismiss"
        @click="dismissWarning(warning.id)"
      >
        ×
      </button>
    </div>
    <button
      v-if="hiddenWarningCount > 0 || (expanded && visibleWarnings.length > collapsedLimit)"
      type="button"
      class="warning-summary"
      :aria-expanded="expanded"
      @click="expanded = !expanded"
    >
      <span v-if="expanded">Show fewer warnings</span>
      <span v-else>Show {{ hiddenWarningCount }} more warnings</span>
      <span aria-hidden="true">{{ expanded ? '⌃' : '⌄' }}</span>
    </button>
  </div>
</template>
