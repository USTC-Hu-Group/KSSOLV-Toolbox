<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    initialTier?: 'common' | 'advanced';
    locale?: 'en-US' | 'zh-CN';
  }>(),
  { initialTier: 'common', locale: 'en-US' },
);
defineEmits<{ close: [] }>();

type ShortcutJoin = 'plus' | 'then' | 'or';
type ShortcutToken = {
  label: string;
  join?: ShortcutJoin;
};
type ShortcutItem = {
  id: string;
  label: string;
  tokens: ShortcutToken[];
};
type ShortcutGroup = {
  id: string;
  title: string;
  items: ShortcutItem[];
};
type ShortcutTier = {
  id: string;
  title: string;
  groups: ShortcutGroup[];
};

const shortcutGroups: ShortcutGroup[] = [
  {
    id: 'selection',
    title: 'Selection',
    items: [
      {
        id: 'select-atom',
        label: 'Select atom',
        tokens: [{ label: 'Click' }],
      },
      {
        id: 'toggle-atom',
        label: 'Add or remove atom',
        tokens: [{ label: 'Shift/Ctrl' }, { label: 'Click', join: 'plus' }],
      },
      {
        id: 'connected-structure',
        label: 'Select connected structure',
        tokens: [{ label: 'Double-click' }],
      },
      {
        id: 'box-select',
        label: 'Box selection',
        tokens: [{ label: 'B' }, { label: 'Drag', join: 'then' }],
      },
      {
        id: 'lasso-select',
        label: 'Lasso selection',
        tokens: [{ label: 'L' }, { label: 'Drag', join: 'then' }],
      },
      {
        id: 'select-all',
        label: 'Select all atoms',
        tokens: [{ label: '⌘/Ctrl' }, { label: 'A', join: 'plus' }],
      },
    ],
  },
  {
    id: 'transform',
    title: 'Direct transform',
    items: [
      {
        id: 'move-selection',
        label: 'Move selection',
        tokens: [{ label: 'G' }, { label: 'Drag', join: 'then' }],
      },
      {
        id: 'mouse-move-selection',
        label: 'Move with mouse',
        tokens: [{ label: 'Shift' }, { label: 'Middle-drag', join: 'plus' }],
      },
      {
        id: 'rotate-selection',
        label: 'Rotate selection',
        tokens: [{ label: 'R' }, { label: 'Drag', join: 'then' }],
      },
      {
        id: 'mouse-rotate-selection',
        label: 'Rotate with mouse',
        tokens: [{ label: 'Shift' }, { label: 'Right-drag', join: 'plus' }],
      },
      {
        id: 'axis-constraint',
        label: 'Constrain transform',
        tokens: [{ label: 'X' }, { label: 'Y', join: 'or' }, { label: 'Z', join: 'or' }],
      },
    ],
  },
  {
    id: 'molecule-sketch',
    title: 'Molecule 3D sketch',
    items: [
      {
        id: 'sketch-isolated-atom',
        label: 'Place isolated atom',
        tokens: [{ label: 'S' }, { label: 'Click blank', join: 'then' }],
      },
      {
        id: 'sketch-connected-atom',
        label: 'Drag out atom and bond',
        tokens: [{ label: 'Atom' }, { label: 'Left-drag', join: 'then' }],
      },
      {
        id: 'sketch-existing-bond',
        label: 'Bond existing atoms',
        tokens: [{ label: 'Atom' }, { label: 'Drag to atom', join: 'then' }],
      },
      {
        id: 'edit-bond-order',
        label: 'Edit selected bond order',
        tokens: [{ label: 'Click bond' }, { label: 'Choose order', join: 'then' }],
      },
    ],
  },
  {
    id: 'mouse-view',
    title: 'Mouse & view',
    items: [
      {
        id: 'rotate-view',
        label: 'Rotate view',
        tokens: [{ label: 'Left-drag' }],
      },
      {
        id: 'pan-view',
        label: 'Pan view',
        tokens: [{ label: 'Right-drag' }],
      },
      {
        id: 'zoom-view',
        label: 'Zoom view',
        tokens: [{ label: 'Middle-drag' }, { label: 'Wheel', join: 'or' }],
      },
      {
        id: 'center-view',
        label: 'Center view',
        tokens: [{ label: 'Space' }],
      },
      {
        id: 'content-zoom-in',
        label: 'Increase interface zoom',
        tokens: [{ label: '⌘/Ctrl' }, { label: '+', join: 'plus' }],
      },
      {
        id: 'content-zoom-out',
        label: 'Decrease interface zoom',
        tokens: [{ label: '⌘/Ctrl' }, { label: '−', join: 'plus' }],
      },
      {
        id: 'content-zoom-reset',
        label: 'Reset interface zoom',
        tokens: [{ label: '⌘/Ctrl' }, { label: '0', join: 'plus' }],
      },
    ],
  },
  {
    id: 'adsorbate',
    title: 'Surface adsorbate sketch',
    items: [
      {
        id: 'adsorbate-fragment',
        label: 'Choose a preset, project molecule, or user fragment',
        tokens: [{ label: 'O' }, { label: 'Fragment palette', join: 'then' }],
      },
      {
        id: 'adsorbate-anchor',
        label: 'Drag host–adsorbate anchor bond',
        tokens: [
          { label: 'O' },
          { label: 'Surface atom', join: 'then' },
          { label: 'Left-drag', join: 'then' },
        ],
      },
      {
        id: 'adsorbate-orient',
        label: 'Orient the complete adsorbate',
        tokens: [{ label: 'O' }, { label: 'Left-drag', join: 'then' }],
      },
      {
        id: 'adsorbate-depth',
        label: 'Adjust host bond length',
        tokens: [{ label: 'Alt' }, { label: 'Left-drag', join: 'plus' }],
      },
      {
        id: 'adsorbate-rotate',
        label: 'Rotate adsorbate about host bond',
        tokens: [{ label: 'Right-drag' }],
      },
      {
        id: 'adsorbate-apply',
        label: 'Apply adsorbate transaction',
        tokens: [{ label: 'Enter' }],
      },
    ],
  },
  {
    id: 'general',
    title: 'Edit & history',
    items: [
      {
        id: 'undo',
        label: 'Undo',
        tokens: [{ label: '⌘/Ctrl' }, { label: 'Z', join: 'plus' }],
      },
      {
        id: 'redo',
        label: 'Redo',
        tokens: [
          { label: 'Shift' },
          { label: '⌘/Ctrl', join: 'plus' },
          { label: 'Z', join: 'plus' },
        ],
      },
      {
        id: 'delete-selection',
        label: 'Delete selection',
        tokens: [{ label: 'Delete' }, { label: 'Backspace', join: 'or' }],
      },
      {
        id: 'cancel-tool',
        label: 'Cancel active tool or clear selection',
        tokens: [{ label: 'Esc' }],
      },
    ],
  },
  {
    id: 'precise-interface',
    title: 'Precise tools & interface',
    items: [
      {
        id: 'exact-translation',
        label: 'Enter an exact Cartesian or fractional translation',
        tokens: [{ label: 'Modeling tab' }, { label: 'Move atoms', join: 'then' }],
      },
      {
        id: 'exact-rotation',
        label: 'Enter an exact rotation angle and axis',
        tokens: [{ label: 'Modeling tab' }, { label: 'Rotate atoms', join: 'then' }],
      },
      {
        id: 'minimal-ui',
        label: 'Toggle the minimal viewer interface',
        tokens: [{ label: 'I' }],
      },
      {
        id: 'shortcut-help',
        label: 'Open or close this shortcut guide',
        tokens: [{ label: '?' }, { label: '/', join: 'or' }],
      },
    ],
  },
];

const group = (id: string): ShortcutGroup => shortcutGroups.find((value) => value.id === id)!;

const shortcutTiers: ShortcutTier[] = [
  {
    id: 'common',
    title: 'Everyday controls',
    groups: [group('mouse-view'), group('selection'), group('general'), group('transform')],
  },
  {
    id: 'advanced',
    title: 'Modeling tools',
    groups: [group('molecule-sketch'), group('adsorbate'), group('precise-interface')],
  },
];

const activeTier = ref<'common' | 'advanced'>(props.initialTier);
watch(
  () => props.initialTier,
  (value) => {
    activeTier.value = value;
  },
);
const activeTierIndex = computed(() =>
  shortcutTiers.findIndex((tier) => tier.id === activeTier.value),
);
const activateRelativeTier = (offset: number): void => {
  const count = shortcutTiers.length;
  const index = (activeTierIndex.value + offset + count) % count;
  activeTier.value = shortcutTiers[index]!.id as 'common' | 'advanced';
  void nextTick(() => document.getElementById(`shortcut-tab-${activeTier.value}`)?.focus());
};
const activateTier = (id: string): void => {
  activeTier.value = id === 'advanced' ? 'advanced' : 'common';
};

const chinese: Record<string, string> = {
  'Keyboard & mouse shortcuts': '键盘与鼠标快捷键',
  Close: '关闭',
  'Common controls first, advanced modeling tools afterward.': '常用操作优先，高级建模工具随后。',
  'Shortcut sections': '快捷键分区',
  'Everyday controls': '常用操作',
  'Modeling tools': '建模工具',
  'Mouse & view': '鼠标与视图',
  Selection: '选择',
  'Edit & history': '编辑与历史',
  'Direct transform': '直接变换',
  'Molecule 3D sketch': '分子 3D 草绘',
  'Surface adsorbate sketch': '表面吸附质草绘',
  'Precise tools & interface': '精确工具与界面',
  'Select atom': '选择原子',
  'Add or remove atom': '添加或移除原子',
  'Select connected structure': '选择连通结构',
  'Box selection': '框选',
  'Lasso selection': '套索选择',
  'Select all atoms': '选择全部原子',
  'Move selection': '移动选择',
  'Move with mouse': '使用鼠标移动',
  'Rotate selection': '旋转选择',
  'Rotate with mouse': '使用鼠标旋转',
  'Constrain transform': '约束变换轴',
  'Place isolated atom': '放置孤立原子',
  'Drag out atom and bond': '拖出原子和化学键',
  'Bond existing atoms': '连接已有原子',
  'Edit selected bond order': '编辑所选键级',
  'Rotate view': '旋转视图',
  'Pan view': '平移视图',
  'Zoom view': '缩放视图',
  'Center view': '居中视图',
  'Increase interface zoom': '放大界面内容',
  'Decrease interface zoom': '缩小界面内容',
  'Reset interface zoom': '重置界面缩放',
  'Choose a preset, project molecule, or user fragment': '选择预置、项目分子或用户片段',
  'Drag host–adsorbate anchor bond': '拖动宿主–吸附质锚定键',
  'Orient the complete adsorbate': '调整完整吸附质朝向',
  'Adjust host bond length': '调整宿主键长',
  'Rotate adsorbate about host bond': '绕宿主键旋转吸附质',
  'Apply adsorbate transaction': '提交吸附质事务',
  Undo: '撤销',
  Redo: '重做',
  'Delete selection': '删除选择',
  'Cancel active tool or clear selection': '取消当前工具或清除选择',
  'Enter an exact Cartesian or fractional translation': '输入精确笛卡尔或分数坐标位移',
  'Enter an exact rotation angle and axis': '输入精确旋转角和旋转轴',
  'Toggle the minimal viewer interface': '切换精简视窗界面',
  'Open or close this shortcut guide': '打开或关闭快捷键指南',
  Click: '单击',
  'Double-click': '双击',
  Drag: '拖动',
  'Middle-drag': '中键拖动',
  'Right-drag': '右键拖动',
  'Left-drag': '左键拖动',
  'Click blank': '单击空白处',
  Atom: '原子',
  'Drag to atom': '拖到原子',
  'Click bond': '单击化学键',
  'Choose order': '选择键级',
  Wheel: '滚轮',
  'Fragment palette': '片段选择器',
  'Surface atom': '表面原子',
  'Modeling tab': '建模选项卡',
  'Move atoms': '移动原子',
  'Rotate atoms': '旋转原子',
  then: '然后',
  or: '或',
};

const translate = (value: string): string =>
  props.locale === 'zh-CN' ? (chinese[value] ?? value) : value;

const joinLabel = (join: ShortcutJoin): string =>
  join === 'plus' ? '+' : join === 'then' ? translate('then') : translate('or');

type MouseButton = 'left' | 'middle' | 'right';
const mouseButtonFor = (label: string): MouseButton | undefined => {
  if (label === 'Click' || label === 'Double-click' || label === 'Left-drag') return 'left';
  if (label === 'Middle-drag') return 'middle';
  if (label === 'Right-drag') return 'right';
  return undefined;
};
</script>

<template>
  <div class="shortcut-help-backdrop" role="presentation" @pointerdown.self="$emit('close')">
    <section
      class="shortcut-help-dialog"
      role="dialog"
      aria-modal="true"
      :aria-label="translate('Keyboard & mouse shortcuts')"
      :data-initial-tier="initialTier"
      :lang="locale"
    >
      <header class="shortcut-help-header">
        <div class="shortcut-help-title">
          <h2>{{ translate('Keyboard & mouse shortcuts') }}</h2>
          <div
            class="shortcut-tier-switch"
            role="tablist"
            :aria-label="translate('Shortcut sections')"
          >
            <button
              v-for="tier in shortcutTiers"
              :id="`shortcut-tab-${tier.id}`"
              :key="tier.id"
              type="button"
              role="tab"
              :aria-selected="activeTier === tier.id"
              :aria-controls="`shortcut-tier-${tier.id}`"
              :tabindex="activeTier === tier.id ? 0 : -1"
              @click="activateTier(tier.id)"
              @keydown.left.prevent="activateRelativeTier(-1)"
              @keydown.right.prevent="activateRelativeTier(1)"
            >
              <span>{{ translate(tier.title) }}</span>
              <small>{{ tier.groups.reduce((sum, value) => sum + value.items.length, 0) }}</small>
            </button>
          </div>
        </div>
        <button
          class="shortcut-help-close"
          type="button"
          :aria-label="translate('Close')"
          :title="translate('Close')"
          @click="$emit('close')"
        >
          ×
        </button>
      </header>

      <div class="shortcut-help-content">
        <section
          v-for="tier in shortcutTiers"
          v-show="activeTier === tier.id"
          :id="`shortcut-tier-${tier.id}`"
          :key="tier.id"
          class="shortcut-tier"
          :class="`shortcut-tier--${tier.id}`"
          role="tabpanel"
          :aria-labelledby="`shortcut-tab-${tier.id}`"
          :hidden="activeTier !== tier.id"
        >
          <div class="shortcut-groups">
            <section
              v-for="shortcutGroup in tier.groups"
              :key="shortcutGroup.id"
              class="shortcut-group"
              :aria-labelledby="`shortcut-group-${shortcutGroup.id}`"
            >
              <h4 :id="`shortcut-group-${shortcutGroup.id}`">
                {{ translate(shortcutGroup.title) }}
              </h4>
              <ul class="shortcut-list">
                <li v-for="item in shortcutGroup.items" :key="item.id" class="shortcut-row">
                  <div class="shortcut-copy">
                    <strong>{{ translate(item.label) }}</strong>
                  </div>
                  <div
                    class="shortcut-keys"
                    :aria-label="
                      locale === 'zh-CN' ? `${translate(item.label)}快捷键` : `${item.label} keys`
                    "
                  >
                    <template v-for="(token, index) in item.tokens" :key="`${item.id}-${index}`">
                      <span v-if="token.join" class="shortcut-key-join">{{
                        joinLabel(token.join)
                      }}</span>
                      <kbd class="shortcut-key">
                        <svg
                          v-if="mouseButtonFor(token.label)"
                          class="shortcut-mouse"
                          viewBox="0 0 16 18"
                          aria-hidden="true"
                        >
                          <path
                            d="M8 1.25c-3.04 0-5.5 2.3-5.5 5.15v5.2c0 2.85 2.46 5.15 5.5 5.15s5.5-2.3 5.5-5.15V6.4C13.5 3.55 11.04 1.25 8 1.25Z"
                          />
                          <path d="M8 1.5v5.25M2.75 6.75h10.5" />
                          <rect
                            v-if="mouseButtonFor(token.label) === 'left'"
                            x="3.45"
                            y="2.05"
                            width="3.8"
                            height="3.9"
                            rx="1"
                          />
                          <rect
                            v-else-if="mouseButtonFor(token.label) === 'middle'"
                            x="7.15"
                            y="2.05"
                            width="1.7"
                            height="3.9"
                            rx="0.75"
                          />
                          <rect v-else x="8.75" y="2.05" width="3.8" height="3.9" rx="1" />
                        </svg>
                        {{ translate(token.label) }}
                      </kbd>
                    </template>
                  </div>
                </li>
              </ul>
            </section>
          </div>
        </section>
      </div>
    </section>
  </div>
</template>
