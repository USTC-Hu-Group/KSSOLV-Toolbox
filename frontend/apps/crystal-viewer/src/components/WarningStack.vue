<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';

import type { SceneWarning } from '../scene/types';

interface TimedWarning extends SceneWarning {
  id: string;
}

const props = withDefaults(
  defineProps<{
    warnings: SceneWarning[];
    scopeKey?: string;
    timeoutMilliseconds?: number;
  }>(),
  {
    scopeKey: '',
    timeoutMilliseconds: 5000,
  },
);

const visibleWarnings = ref<TimedWarning[]>([]);
const expiryTimers = new Map<string, number>();

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
  visibleWarnings.value = props.warnings.map((warning, index) => ({
    ...warning,
    id: `${props.scopeKey}:${index}:${warning.code}`,
  }));
  for (const warning of visibleWarnings.value) {
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
    <div v-for="warning in visibleWarnings" :key="warning.id" :class="warning.severity">
      <span>{{ warning.message }}</span>
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
  </div>
</template>
