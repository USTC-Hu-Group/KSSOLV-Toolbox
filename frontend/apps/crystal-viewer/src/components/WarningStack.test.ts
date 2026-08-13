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
            siteIndices: [2, 4],
          },
        ],
        scopeKey: 'scene-1',
      },
    });

    expect(wrapper.text()).not.toContain('CONNECTIVITY_FALLBACK');
    expect(wrapper.text()).not.toContain('SECOND_WARNING');
    expect(wrapper.text()).toContain('CrystalNN could not resolve this geometry');
    expect(wrapper.findAll('[aria-label="Dismiss warning"]')).toHaveLength(2);
    await wrapper.get('[aria-label="Locate affected atoms"]').trigger('click');
    expect(wrapper.emitted('locate')).toEqual([[[2, 4]]]);

    await wrapper.findAll('[aria-label="Dismiss warning"]')[0].trigger('click');
    expect(wrapper.text()).not.toContain('CrystalNN could not resolve this geometry');
    expect(wrapper.text()).toContain('A second warning.');

    await vi.advanceTimersByTimeAsync(4999);
    expect(wrapper.text()).toContain('A second warning.');
    await vi.advanceTimersByTimeAsync(1);
    expect(wrapper.find('.warning-stack').exists()).toBe(false);
  });

  it('keeps large diagnostic sets compact until the user expands them', async () => {
    const warnings = Array.from({ length: 7 }, (_, index) => ({
      code: `VALENCE_${index}`,
      message: `Atom ${index + 1} has open valence.`,
      severity: 'info' as const,
      siteIndices: [index],
    }));
    const wrapper = mount(WarningStack, {
      props: { warnings, timeoutMilliseconds: 0, scopeKey: 'large-scene' },
    });

    expect(wrapper.findAll('.warning-stack > div')).toHaveLength(3);
    expect(wrapper.text()).toContain('Show 4 more warnings');
    await wrapper.get('.warning-summary').trigger('click');
    expect(wrapper.findAll('.warning-stack > div')).toHaveLength(7);
    expect(wrapper.text()).toContain('Show fewer warnings');
    await wrapper.get('.warning-summary').trigger('click');
    expect(wrapper.findAll('.warning-stack > div')).toHaveLength(3);
  });
});
