import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import { createDebugVolume } from '../state/debugVolume';
import { useVolumeStore } from '../state/volumeStore';
import SettingsPanel from './SettingsPanel.vue';

describe('volume display settings', () => {
  it('does not duplicate viewport PNG controls in settings', () => {
    const { scene } = createDebugVolume();
    const options = useVolumeStore().options;
    const wrapper = mount(SettingsPanel, {
      props: {
        scene,
        modelValue: { ...options, channelId: 'density', mode: 'isosurface' },
        displayUnit: 'angstrom-3',
      },
    });

    expect(wrapper.text()).not.toContain('Image export');
    expect(wrapper.text()).not.toContain('PNG scale');
    expect(wrapper.text()).toContain('Isosurface export');
  });
});
