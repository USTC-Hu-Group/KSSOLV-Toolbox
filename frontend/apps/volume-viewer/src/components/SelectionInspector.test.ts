import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import type { SelectionInfo } from '@kssolv/atomic-scene';

import SelectionInspector from './SelectionInspector.vue';

const atomSelection: SelectionInfo = {
  kind: 'atom',
  id: 'si@1,0,0',
  clientX: 20,
  clientY: 30,
  atom: {
    id: 'si@1,0,0',
    siteId: 'si',
    siteIndex: 0,
    imageOffset: [1, 0, 0],
    position: [3.25, 2.5, 1.75],
    visibility: 'boundary',
  },
  site: {
    id: 'si',
    siteIndex: 0,
    label: 'Si',
    species: [{
      symbol: 'Si',
      occupancy: 1,
      atomicNumber: 14,
      colorVesta: [35, 69, 250],
      colorJmol: [240, 200, 160],
      atomicRadius: 1.1,
    }],
    fractional: [0.25, 0.5, 0.75],
    cartesian: [1.25, 2.5, 1.75],
  },
};

describe('volume selection inspector', () => {
  it('matches the structure inspector atom fields', () => {
    const wrapper = mount(SelectionInspector, {
      props: { selection: atomSelection },
    });
    expect(wrapper.text()).toContain('Si');
    expect(wrapper.text()).toContain('Site 1');
    expect(wrapper.text()).toContain('3.250, 2.500, 1.750 Å');
    expect(wrapper.text()).toContain('1.250, 0.500, 0.750');
    expect(wrapper.text()).toContain('Image');
    expect(wrapper.text()).toContain('Si 1');
  });

  it('shows bond length and image metadata', () => {
    const wrapper = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'bond',
          id: 'bond',
          clientX: 20,
          clientY: 30,
          bond: {
            id: 'bond',
            relationId: 'relation',
            fromSiteIndex: 0,
            toSiteIndex: 1,
            fromImage: [0, 0, 0],
            toImage: [1, 0, 0],
            start: [0, 0, 0],
            end: [2.35, 0, 0],
            distance: 2.35,
            visibility: 'base',
          },
        },
      },
    });
    expect(wrapper.text()).toContain('Sites 1–2');
    expect(wrapper.text()).toContain('2.35000 Å');
    expect(wrapper.text()).toContain('1, 0, 0');
  });
});
