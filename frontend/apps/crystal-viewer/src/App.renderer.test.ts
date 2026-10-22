import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import App from './App.vue';
import { matlabBridge } from './bridge/matlabBridge';

vi.mock('./renderer/CrystalRenderer', () => ({
  CrystalRenderer: class {
    constructor() {
      throw new Error('Error creating WebGL context.');
    }
  },
}));

describe('renderer startup failure', () => {
  it('explains an unavailable WebGL view and still reports the failure to MATLAB', async () => {
    const emit = vi.spyOn(matlabBridge, 'emit');
    const wrapper = mount(App);
    await flushPromises();

    expect(wrapper.get('[role="alert"]').text()).toContain(
      '3D view unavailable: Error creating WebGL context.',
    );
    expect(emit).toHaveBeenCalledWith(
      'viewer:error',
      expect.objectContaining({ code: 'RENDERER_INIT', message: 'Error creating WebGL context.' }),
    );

    wrapper.unmount();
    emit.mockRestore();
  });
});
