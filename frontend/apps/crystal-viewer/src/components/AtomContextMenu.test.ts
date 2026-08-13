import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import { createDebugScene } from '../scene/debugScene';
import AtomContextMenu from './AtomContextMenu.vue';

const site = createDebugScene().sites[0];

const mountMenu = (overrides: Partial<InstanceType<typeof AtomContextMenu>['$props']> = {}) =>
  mount(AtomContextMenu, {
    props: {
      x: 40,
      y: 60,
      site,
      selectionCount: 1,
      selectedSiteCount: 1,
      backendAvailable: true,
      ...overrides,
    },
    attachTo: document.body,
  });

describe('atom context modeling menu', () => {
  it('keeps same-element selection available while disabling modeling commands offline', async () => {
    const wrapper = mountMenu({ backendAvailable: false });
    expect(wrapper.text()).toContain('Select All Na Atoms');
    expect(wrapper.text()).toContain('Replace Element…');
    expect(wrapper.text()).toContain('Move Atom…');
    expect(wrapper.text()).toContain('Translate Atom…');
    expect(wrapper.text()).toContain('Delete Atom');
    expect(wrapper.text()).not.toContain('Modeling');
    expect(wrapper.text()).toContain('Requires KSSOLV Toolbox');
    const actions = wrapper.findAll('[role="menuitem"]');
    expect(actions[0].attributes('disabled')).toBeUndefined();
    expect(actions.slice(1, 5).every((item) => item.attributes('disabled') !== undefined)).toBe(
      true,
    );
    expect(actions[5].attributes('disabled')).toBeUndefined();
    await actions[0].trigger('click');
    expect(wrapper.emitted('selectSameElement')?.[0]).toEqual(['Na']);
    wrapper.unmount();
  });

  it('submits replacement and translation parameters from frontend dialogs', async () => {
    const wrapper = mountMenu({ selectionCount: 2, selectedSiteCount: 2 });
    await wrapper.findAll('[role="menuitem"]')[1].trigger('click');
    await wrapper.get('input[name="species"]').setValue('Ge');
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('command')?.[0]).toEqual(['substitute_atoms', { species: 'Ge' }]);
    wrapper.unmount();

    const translate = mountMenu({
      selectionCount: 2,
      selectedSiteCount: 2,
    });
    await translate.findAll('[role="menuitem"]')[3].trigger('click');
    const inputs = translate.findAll('.atom-vector-fields input');
    await inputs[0].setValue('1.5');
    await inputs[1].setValue('-2');
    await inputs[2].setValue('0.25');
    await translate.get('.atom-modeling-check input').setValue(true);
    await translate.get('form').trigger('submit');
    expect(translate.emitted('command')?.[0]).toEqual([
      'translate_atoms',
      { vector: [1.5, -2, 0.25], fractional: true },
    ]);
    translate.unmount();
  });

  it('submits move coordinates and confirms deletion in frontend dialogs', async () => {
    const move = mountMenu();
    await move.findAll('[role="menuitem"]')[2].trigger('click');
    const coordinates = move.findAll('.atom-vector-fields input');
    await coordinates[0].setValue('1');
    await coordinates[1].setValue('2');
    await coordinates[2].setValue('3');
    await move.get('form').trigger('submit');
    expect(move.emitted('command')?.[0]).toEqual([
      'move_atoms',
      { coordinates: [1, 2, 3], cartesian: true },
    ]);
    move.unmount();

    const deletion = mountMenu();
    await deletion.findAll('[role="menuitem"]')[4].trigger('click');
    expect(deletion.text()).toContain('This can be undone from the Modeling tab.');
    await deletion.get('form').trigger('submit');
    expect(deletion.emitted('command')?.[0]).toEqual(['delete_atoms', {}]);
    deletion.unmount();
  });

  it('uses Cartesian-only controls and payloads for molecule sites', async () => {
    const moleculeSite = structuredClone(site);
    delete moleculeSite.fractional;

    const move = mountMenu({ site: moleculeSite });
    await move.findAll('[role="menuitem"]')[2].trigger('click');
    expect(move.find('.atom-modeling-check').exists()).toBe(false);
    await move.get('form').trigger('submit');
    expect(move.emitted('command')?.[0]).toEqual([
      'move_atoms',
      { coordinates: moleculeSite.cartesian, cartesian: true },
    ]);
    move.unmount();

    const translate = mountMenu({ site: moleculeSite });
    await translate.findAll('[role="menuitem"]')[3].trigger('click');
    expect(translate.find('.atom-modeling-check').exists()).toBe(false);
    await translate.get('form').trigger('submit');
    expect(translate.emitted('command')?.[0]).toEqual([
      'translate_atoms',
      { vector: [0, 0, 0], fractional: false },
    ]);
    translate.unmount();
  });

  it('shows indeterminate progress while MATLAB applies a structure edit', async () => {
    const wrapper = mountMenu();
    await wrapper.findAll('[role="menuitem"]')[1].trigger('click');
    await wrapper.setProps({ pending: true });
    expect(wrapper.get('.atom-modeling-progress').text()).toContain('Applying structure edit');
    expect(wrapper.get('progress').attributes('aria-label')).toBe('Structure edit progress');
    expect(
      wrapper.findAll('button').every((button) => button.attributes('disabled') !== undefined),
    ).toBe(true);
    wrapper.unmount();
  });

  it('requires one atom for moving while allowing the entire structure to be deleted', async () => {
    const wrapper = mountMenu({ selectionCount: 2, selectedSiteCount: 2 });
    const actions = wrapper.findAll('[role="menuitem"]');
    expect(actions[2].attributes('disabled')).toBeDefined();
    expect(actions[4].attributes('disabled')).toBeUndefined();
    await actions[4].trigger('click');
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('command')?.[0]).toEqual(['delete_atoms', {}]);
    wrapper.unmount();
  });

  it('describes multiple rendered images without limiting selection to unique sites', () => {
    const wrapper = mountMenu({
      selectionCount: 4,
      selectedSiteCount: 1,
    });
    expect(wrapper.text()).toContain('4 atoms selected');
    expect(wrapper.text()).toContain('4 displayed atoms represent 1 structure site.');
    expect(wrapper.findAll('[role="menuitem"]')[2].attributes('disabled')).toBeUndefined();
    expect(wrapper.findAll('[role="menuitem"]')[4].attributes('disabled')).toBeUndefined();
    wrapper.unmount();
  });

  it('offers bonded-component expansion for one selected source site', async () => {
    const wrapper = mountMenu();
    const connected = wrapper
      .findAll('[role="menuitem"]')
      .find((item) => item.text() === 'Select Connected Component');
    expect(connected).toBeDefined();
    await connected!.trigger('click');
    expect(wrapper.emitted('selectConnected')?.[0]).toEqual([site.siteIndex]);
    wrapper.unmount();
  });
});
