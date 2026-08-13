import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import { AUTO_ROTATE_ICON_PATH } from '@kssolv/three-scene';

import ViewerToolbar from './ViewerToolbar.vue';

describe('volume viewer toolbar', () => {
  it('exposes auto rotation and structure information controls', async () => {
    const wrapper = mount(ViewerToolbar, {
      props: {
        settingsOpen: false,
        informationAvailable: true,
        informationOpen: false,
        autoRotating: false,
      },
    });
    expect(wrapper.get('svg.auto-rotate-icon path').attributes('d')).toBe(AUTO_ROTATE_ICON_PATH);
    await wrapper.get('[aria-label="Auto rotate"]').trigger('click');
    await wrapper.get('[aria-label="Structure information"]').trigger('click');
    expect(wrapper.emitted('toggleAutoRotation')).toHaveLength(1);
    expect(wrapper.emitted('toggleInformation')).toHaveLength(1);

    await wrapper.setProps({ autoRotating: true, informationOpen: true });
    expect(wrapper.get('[aria-label="Stop rotation"]').attributes('aria-pressed')).toBe('true');
    expect(wrapper.get('[aria-label="Structure information"]').attributes('aria-pressed')).toBe(
      'true',
    );
  });

  it('keeps direct and reciprocal axes in stable semantic groups', () => {
    const wrapper = mount(ViewerToolbar, { props: { settingsOpen: false } });
    expect(wrapper.findAll('[data-toolbar-axis]').map((button) => button.text())).toEqual([
      'a',
      'b',
      'c',
      'a*',
      'b*',
      'c*',
    ]);
    expect(wrapper.get('[aria-label="Structure information"]').attributes('disabled')).toBe('');
  });

  it('matches the structure viewer image export submenu', async () => {
    const wrapper = mount(ViewerToolbar, { props: { settingsOpen: false } });
    const trigger = wrapper.get('[aria-label="Export image"]');
    expect(trigger.attributes('aria-expanded')).toBe('false');

    await trigger.trigger('click');

    expect(trigger.attributes('aria-expanded')).toBe('true');
    expect(wrapper.get('[aria-label="Image formats"]').text()).toContain(
      'Lossless high-resolution image',
    );
    expect(
      wrapper.findAll('[aria-label="Image formats"] [role="menuitem"] strong').map((item) =>
        item.text(),
      ),
    ).toEqual(['PNG', 'JPEG', 'TIFF', 'SVG', 'PDF (Vector)', 'PDF (Raster)']);

    await wrapper.findAll('[aria-label="Image formats"] [role="menuitem"]')[2].trigger('click');
    expect(wrapper.emitted('exportImage')).toEqual([['tiff']]);
    expect(wrapper.find('[aria-label="Image formats"]').exists()).toBe(false);
  });
});
