<script setup lang="ts">
  import type { Node } from '@antv/x6';
  import { computed, inject, onMounted, ref } from 'vue';
  import successIcon from '../assets/icons/success.svg';
  import failedIcon from '../assets/icons/failed.svg';
  import settingsIcon from '../assets/icons/settings.svg';
  import loadingIcon from '../assets/icons/loading.svg';

  declare const MATLAB: any;

  interface NodeStatus {
    status: 'default' | 'success' | 'failed' | 'running';
    label?: string;
  }

  const node = ref<NodeStatus>({
    label: '测试节点',
    status: 'success',
  });

  const status = computed(() => node.value.status);
  const icon = computed(() => {
    switch (status.value) {
      case 'success':
        return successIcon;
      case 'failed':
        return failedIcon;
      case 'running':
        return loadingIcon;
      default:
        return null;
    }
  });

  // getNode 部分代码可以参考 https://blog.csdn.net/qq_40934617/article/details/132234040
  const getNode = inject<() => Node>('getNode');

  onMounted(() => {
    const thisNode = getNode?.();
    if (!thisNode) return;

    // 根据 graph.addNode() 中传入的 data 来初始化节点
    node.value = thisNode.getData<NodeStatus>();
    // 监听 node.setData() 函数触发的 data 变化事件来更新节点
    thisNode.on('change:data', ({ current }: { current: NodeStatus }) => {
      node.value = current;
      // console.log(current);
    });
  });

  const openSettingsWindow = ref(false);
  const clickSettings = () => {
    openSettingsWindow.value = !openSettingsWindow.value;
    // 向 MATLAB 发送事件，决定打开或关闭节点设置窗口
    if (typeof MATLAB !== 'undefined') {
      const thisNode = getNode?.();
      MATLAB.sendEventToMATLAB('OpenSettingsWindow', thisNode?.id);
    }
  };
</script>

<template>
  <div :class="`node ${status}`" @dblclick="clickSettings">
    <img class="button" :src="settingsIcon" alt="settings" @click="clickSettings" />

    <span class="label">{{ node.label }}</span>

    <img
      v-if="icon"
      class="icon"
      :class="{ rotate: status === 'running' }"
      :src="icon"
      :alt="status"
    />
  </div>
</template>

<style scoped>
  .button {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
    margin-left: 8px;
  }

  .button:hover {
    background-color: grey;
  }

  .button:focus {
    outline: none;
    box-shadow: 0 0 3px #0d8bf2;
  }

  .button:active {
    background-color: #0b6de1;
    transform: translateY(1px);
  }

  .icon {
    margin-left: auto;
    margin-right: 8px;
  }

  .rotate {
    animation: rotate 1s linear infinite;
  }

  @keyframes rotate {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }
</style>
