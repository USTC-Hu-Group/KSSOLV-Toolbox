import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import { isProxy } from 'vue';

import { createDebugMoleculeScene, createDebugScene } from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import ElementLegend from './ElementLegend.vue';
import SelectionInspector from './SelectionInspector.vue';
import SettingsPanel from './SettingsPanel.vue';
import ViewerToolbar from './ViewerToolbar.vue';

describe('viewer controls', () => {
  it('exposes the Materials Project control surface with accessible names', () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    expect(wrapper.find('[aria-label="Crystal display settings"]').exists()).toBe(true);
    expect(wrapper.findAll('input[type="checkbox"]')).toHaveLength(10);
    expect(wrapper.text()).not.toContain('Ordered ·');
    expect(wrapper.text()).toContain('CrystalNN · accurate');
    expect(wrapper.text()).toContain('Jmol bonding');
    expect(wrapper.text()).toContain("O'Keeffe's algorithm");
    expect(wrapper.text()).toContain("Hoppe's ECoN algorithm");
    expect(wrapper.text()).toContain("Brunner's reciprocal algorithm");
    expect(wrapper.text()).toContain('High-quality exporting');
    expect(wrapper.text()).toContain('Fast interactive · Phong');
    const sectionHeadings = wrapper.findAll('h3').map((heading) => heading.text());
    expect(sectionHeadings.indexOf('High-quality exporting')).toBeGreaterThan(
      sectionHeadings.indexOf('Scientific scene'),
    );
    const qualityControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Quality level'));
    expect(qualityControl!.get('select').attributes('disabled')).toBeDefined();
    expect(wrapper.text()).toContain('Unit-cell representation');
    expect(wrapper.text()).toContain('Repeat cell');
  });

  it('emits a complete immutable option update', async () => {
    const options = defaultViewerOptions();
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene() },
    });
    await wrapper.get('select').setValue('pretty');
    const emitted = wrapper.emitted('update:modelValue');
    expect(emitted).toHaveLength(1);
    expect((emitted?.[0][0] as typeof options).theme).toBe('pretty');
    expect(options.theme).toBe('materials');
  });

  it('enables selectable physical-rendering quality without changing the fast default', async () => {
    const options = defaultViewerOptions();
    expect(options.renderMode).toBe('fast');
    expect(options.renderQuality).toBe('high');
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene() },
    });
    const renderingPath = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Rendering path'));
    await renderingPath!.get('select').setValue('quality');
    const next = wrapper.emitted('update:modelValue')?.[0][0] as typeof options;
    expect(next.renderMode).toBe('quality');
    expect(next.renderQuality).toBe('high');
    expect(options.renderMode).toBe('fast');

    await wrapper.setProps({ modelValue: next });
    const qualityControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Quality level'));
    expect(qualityControl!.get('select').attributes('disabled')).toBeUndefined();
    await qualityControl!.get('select').setValue('ultra');
    const ultra = wrapper.emitted('update:modelValue')?.[1][0] as typeof options;
    expect(ultra.renderQuality).toBe('ultra');
  });

  it('shows molecule controls without crystal-only settings', () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugMoleculeScene(),
      },
    });
    expect(wrapper.find('[aria-label="Molecule display settings"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('Source topology · preferred');
    expect(wrapper.text()).toContain('Hydrogens');
    expect(wrapper.text()).toContain('Multiple bond order');
    expect(wrapper.text()).not.toContain('Unit-cell representation');
    expect(wrapper.text()).not.toContain('Repeat cell');
  });

  it('makes scene rebuild progress and completion explicit', async () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugMoleculeScene(),
        rebuildPhase: 'building',
        rebuildMessage: 'Computing bonds and rebuilding the scene…',
        rebuilding: true,
      },
    });
    const bondingControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Bonding strategy'))!
      .get('select');
    expect(bondingControl.attributes('disabled')).toBeDefined();
    expect(wrapper.find('.primary-button').exists()).toBe(false);
    const feedback = wrapper.get('.rebuild-feedback');
    expect(feedback.text()).toContain('Computing bonds');
    expect(feedback.classes()).toContain('is-building');
    expect(feedback.find('.feedback-spinner').exists()).toBe(true);

    await wrapper.setProps({
      rebuildPhase: 'success',
      rebuildMessage: 'Scene rebuilt in 0.4 s.',
      rebuilding: false,
    });
    expect(bondingControl.attributes('disabled')).toBeUndefined();
    expect(feedback.text()).toContain('Scene rebuilt');
    expect(feedback.classes()).toContain('is-success');
    expect(feedback.find('.feedback-spinner').exists()).toBe(false);
  });

  it('rebuilds immediately from scientific controls with MATLAB-serializable payloads', async () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    const bondingControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Bonding strategy'))!
      .get('select');
    await bondingControl.setValue('JmolNN');
    const payload = wrapper.emitted('rebuild')?.[0][0] as {
      algorithm: string;
      cell: string;
      repeat: [number, number, number];
    };
    expect(payload.algorithm).toBe('JmolNN');
    expect(payload.cell).toBe('input');
    expect(payload.repeat).toEqual([1, 1, 1]);
    expect(isProxy(payload.repeat)).toBe(false);

    const cellControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Unit-cell representation'))!
      .get('select');
    await cellControl.setValue('primitive');
    expect((wrapper.emitted('rebuild')?.[1][0] as { cell: string }).cell).toBe('primitive');

    const repeatA = wrapper.get('fieldset input');
    await repeatA.setValue(2);
    expect((wrapper.emitted('rebuild')?.[2][0] as { repeat: number[] }).repeat).toEqual([2, 1, 1]);
    expect(wrapper.text()).not.toContain('Theme changes never alter scientific connectivity');
  });

  it('hides performance statistics by default and allows them to be enabled', async () => {
    expect(defaultViewerOptions().showStatistics).toBe(false);
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    const statisticsControl = wrapper
      .findAll('label.check')
      .find((control) => control.text().includes('Performance statistics'));
    await statisticsControl!.get('input').setValue(true);
    const options = wrapper.emitted('update:modelValue')?.[0][0] as ReturnType<
      typeof defaultViewerOptions
    >;
    expect(options.showStatistics).toBe(true);
  });

  it('renders deterministic element legend and toolbar commands', async () => {
    const legend = mount(ElementLegend, {
      props: { scene: createDebugScene(), colorMode: 'vesta' },
    });
    expect(legend.text()).toBe('Cl Na');
    const toolbar = mount(ViewerToolbar, { props: { settingsOpen: false, crystal: true } });
    await toolbar.get('[aria-label="Reset camera"]').trigger('click');
    expect(toolbar.emitted('reset')).toHaveLength(1);
    expect(toolbar.findAll('button')).toHaveLength(12);
    expect(toolbar.findAll('svg')).toHaveLength(5);
    const autoRotate = toolbar.get('[aria-label="Auto rotate"]');
    expect(autoRotate.attributes('aria-pressed')).toBe('false');
    await autoRotate.trigger('click');
    expect(toolbar.emitted('toggleAutoRotation')).toHaveLength(1);
    await toolbar.setProps({ autoRotating: true });
    expect(toolbar.find('[aria-label="Auto rotate"]').exists()).toBe(false);
    const stopRotation = toolbar.get('[aria-label="Stop rotation"]');
    expect(stopRotation.attributes('aria-pressed')).toBe('true');
    await stopRotation.trigger('click');
    expect(toolbar.emitted('toggleAutoRotation')).toHaveLength(2);
    expect(
      toolbar.findAll('.reciprocal-axis-button').map((button) => button.text().trim()),
    ).toEqual(['a*', 'b*', 'c*']);
    const reciprocalA = toolbar.findAll('button').find((button) => button.text() === 'a*');
    await reciprocalA!.trigger('click');
    const emittedAxes = toolbar.emitted('axis')!;
    expect(emittedAxes[emittedAxes.length - 1]).toEqual(['a*']);
  });

  it('does not expose reciprocal-lattice views for molecules', () => {
    const toolbar = mount(ViewerToolbar, { props: { settingsOpen: false, crystal: false } });
    expect(toolbar.findAll('button')).toHaveLength(9);
    expect(toolbar.text()).not.toContain('a*');
  });

  it('shows scientific atom and bond selection details', async () => {
    const scene = createDebugScene();
    const atom = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'atom',
          id: scene.atomInstances[0].id,
          atom: scene.atomInstances[0],
          site: scene.sites[0],
          clientX: 0,
          clientY: 0,
        },
      },
    });
    expect(atom.text()).toContain('Site 1');
    expect(atom.text()).toContain('Occupancy');
    await atom.setProps({
      selection: {
        kind: 'bond',
        id: scene.bondInstances[0].id,
        bond: scene.bondInstances[0],
        clientX: 0,
        clientY: 0,
      },
    });
    expect(atom.text()).toContain('Distance');
    expect(atom.text()).toContain('Å');
  });
});
