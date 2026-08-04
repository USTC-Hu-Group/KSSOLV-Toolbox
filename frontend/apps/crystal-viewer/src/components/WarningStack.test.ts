import { mount } from '@vue/test-utils';
import { afterEach, describe, expect, it, vi } from 'vitest';

import WarningStack from './WarningStack.vue';

describe('warning stack', () => {
  afterEach(() => vi.useRealTimers());

  it('shows only warning messages and supports manual or timed dismissal', async () => {
    vi.useFakeTimers();
    const wrapper = mount(WarningStack, {
      props: {
        warnings: [
          {
            code: 'CONNECTIVITY_FALLBACK',
            message:
              'CrystalNN could not resolve this geometry; VESTA cutoff connectivity is shown instead.',
            severity: 'warning',
          },
          {
            code: 'SECOND_WARNING',
            message: 'A second warning.',
            severity: 'info',
          },
        ],
        scopeKey: 'scene-1',
      },
    });

    expect(wrapper.text()).not.toContain('CONNECTIVITY_FALLBACK');
    expect(wrapper.text()).not.toContain('SECOND_WARNING');
    expect(wrapper.text()).toContain('CrystalNN could not resolve this geometry');
    expect(wrapper.findAll('[aria-label="Dismiss warning"]')).toHaveLength(2);

    await wrapper.findAll('[aria-label="Dismiss warning"]')[0].trigger('click');
    expect(wrapper.text()).not.toContain('CrystalNN could not resolve this geometry');
    expect(wrapper.text()).toContain('A second warning.');

    await vi.advanceTimersByTimeAsync(4999);
    expect(wrapper.text()).toContain('A second warning.');
    await vi.advanceTimersByTimeAsync(1);
    expect(wrapper.find('.warning-stack').exists()).toBe(false);
  });
});
