import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import { isProxy, nextTick } from 'vue';

import { measureScene, type MeasurementRecord } from '../measurement';
import {
  createBlankDebugScene,
  createDebugMoleculeScene,
  createDebugScene,
} from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import ElementLegend from './ElementLegend.vue';
import FractionalCoordinatesPanel from './FractionalCoordinatesPanel.vue';
import HeroToolbar from './HeroToolbar.vue';
import SelectionInspector from './SelectionInspector.vue';
import SettingsPanel from './SettingsPanel.vue';
import ViewerToolbar from './ViewerToolbar.vue';

describe('viewer controls', () => {
  it('shows fractional crystal coordinates without a selected column', () => {
    const scene = createDebugScene();
    scene.sites[0].label = 'Na1';
    const wrapper = mount(FractionalCoordinatesPanel, { props: { scene } });

    expect(wrapper.attributes('aria-label')).toBe('Fractional coordinates');
    expect(wrapper.findAll('th').map((heading) => heading.text())).toEqual([
      'ID',
      'Symbol',
      'Label',
      'x',
      'y',
      'z',
    ]);
    expect(wrapper.findAll('tbody tr')).toHaveLength(2);
    expect(wrapper.find('tbody tr').text()).toContain('1NaNa10.000000.000000.00000');
    expect(wrapper.text()).not.toContain('2 sites');
    expect(wrapper.text()).not.toContain('Selected');
  });

  it('exposes the Materials Project control surface with accessible names', () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    expect(wrapper.find('[aria-label="Crystal display settings"]').exists()).toBe(true);
    expect(wrapper.findAll('input[type="checkbox"]')).toHaveLength(12);
    expect(wrapper.text()).not.toContain('Ordered ·');
    expect(wrapper.text()).toContain('CrystalNN · accurate');
    expect(wrapper.text()).toContain('Jmol bonding');
    expect(wrapper.text()).toContain("O'Keeffe's algorithm");
    expect(wrapper.text()).toContain("Hoppe's ECoN algorithm");
    expect(wrapper.text()).toContain("Brunner's reciprocal algorithm");
    expect(wrapper.text()).not.toContain('Preview rendering');
    expect(wrapper.text()).not.toContain('High quality · Physical');
    expect(wrapper.text()).toContain('Change unit cell');
    expect(wrapper.text()).toContain('Repeat cell');
  });

  it('toggles depth cueing from display settings', async () => {
    const options = defaultViewerOptions();
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene() },
    });
    const control = wrapper
      .findAll('label.check')
      .find((label) => label.text().includes('Depth Cueing'))!;

    expect(options.depthCueing).toBe(true);
    expect(control.get('input').element.checked).toBe(true);
    await control.get('input').setValue(false);

    const next = wrapper.emitted('update:modelValue')?.[0][0] as typeof options;
    expect(next.depthCueing).toBe(false);
  });

  it('offers only Materials Project and Gleamoe Noir with Materials selected by default', () => {
    const options = defaultViewerOptions();
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene() },
    });
    const theme = wrapper.get('select');
    expect(theme.element.value).toBe('materials');
    expect(theme.findAll('option').map((option) => option.text())).toEqual([
      'Materials Project',
      'Gleamoe Noir',
    ]);
    expect(wrapper.text()).not.toContain('Pretty Lattice');
    expect(wrapper.text()).not.toContain('Ray traced');
  });

  it('provides calibrated lighting, material, and image controls with reset', async () => {
    const options = defaultViewerOptions();
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene() },
    });
    const appearance = wrapper.get('.appearance-settings');
    const labels = appearance.findAll('label').map((label) => label.text());

    expect(labels).toEqual(
      expect.arrayContaining([
        expect.stringContaining('Ambient light'),
        expect.stringContaining('Directional light'),
        expect.stringContaining('Metalness'),
        expect.stringContaining('Roughness'),
        expect.stringContaining('Brightness'),
        expect.stringContaining('Contrast'),
      ]),
    );
    expect(appearance.findAll('input[type="range"]')).toHaveLength(6);
    expect(appearance.text()).toContain('50%');
    expect(appearance.text()).not.toContain('preserves the current theme');
    const sections = wrapper.findAll('section');
    expect(sections[sections.length - 1].classes()).toContain('appearance-settings');
    expect(appearance.get('.appearance-reset-button').attributes('disabled')).toBeDefined();

    const brightness = appearance
      .findAll('label')
      .find((label) => label.text().includes('Brightness'))!
      .get('input');
    await brightness.setValue(0.75);
    const next = wrapper.emitted('update:modelValue')?.[0][0] as typeof options;
    expect(next.brightness).toBe(0.75);

    await wrapper.setProps({ modelValue: next });
    const reset = appearance.get('.appearance-reset-button');
    expect(reset.attributes('disabled')).toBeUndefined();
    await reset.trigger('click');
    const restored = wrapper.emitted('update:modelValue')?.[1][0] as typeof options;
    expect(restored.brightness).toBe(0.5);
    expect(restored.ambientLight).toBe(0.5);
    expect(restored.metalness).toBe(0.5);
  });

  it('changes to Gleamoe without exposing preview-rendering presets', async () => {
    const options = defaultViewerOptions();
    const wrapper = mount(SettingsPanel, {
      props: { modelValue: options, scene: createDebugScene(), sceneAvailable: true },
    });

    await wrapper.get('select').setValue('gleamoe-premiror');

    const next = wrapper.emitted('update:modelValue')?.[0][0] as typeof options;
    expect(next.theme).toBe('gleamoe-premiror');
    expect(next.renderMode).toBe(options.renderMode);
    expect(next.renderQuality).toBe(options.renderQuality);
    expect(wrapper.text()).not.toContain('Quality level');
    expect(wrapper.text()).not.toContain('Hero Shot');

    await wrapper.setProps({ modelValue: next });
    const hero = wrapper.get('.hero-settings');
    expect(hero.text()).toContain('cinematic, path-traced view');
    expect(hero.text()).toContain('Enter Hero mode');
    expect(hero.find('select').exists()).toBe(false);
    expect(hero.find('dl').exists()).toBe(false);
    const sections = wrapper.findAll('section');
    expect(sections[sections.length - 1].classes()).toContain('hero-settings');
    await hero.get('.hero-mode-button').trigger('click');
    expect(wrapper.emitted('toggleHeroShot')).toHaveLength(1);
    expect(hero.find('.hero-export-button').exists()).toBe(false);
  });

  it('provides Hero composition axes, resolution export, and exit controls', async () => {
    const toolbar = mount(HeroToolbar, {
      props: { crystal: true, exportScale: 2.5 },
    });

    expect(toolbar.attributes('aria-label')).toBe('Hero mode tools');
    expect(toolbar.findAll('.axis-button').map((button) => button.text().trim())).toEqual([
      'a',
      'b',
      'c',
      'a*',
      'b*',
      'c*',
    ]);
    await toolbar.get('[aria-label="Reset camera"]').trigger('click');
    expect(toolbar.emitted('reset')).toHaveLength(1);
    await toolbar.get('[data-toolbar-axis="b*"]').trigger('click');
    expect(toolbar.emitted('axis')).toEqual([['b*']]);

    const exportButton = toolbar.get('[aria-label="Export Hero Shot"]');
    await exportButton.trigger('click');
    expect(exportButton.attributes('aria-expanded')).toBe('true');
    const resolutionMenu = toolbar.get('[aria-label="Hero export resolution"]');
    expect(resolutionMenu.findAll('[role="menuitemradio"]')).toHaveLength(3);
    expect(resolutionMenu.text()).toContain('2.5× viewport · PNG');
    expect(resolutionMenu.text()).toContain('4× viewport · PNG');
    const poster = resolutionMenu
      .findAll('[role="menuitemradio"]')
      .find((option) => option.text().includes('Poster'))!;
    await poster.trigger('click');
    expect(toolbar.emitted('update:exportScale')).toEqual([[4]]);
    expect(toolbar.emitted('export')).toEqual([[4]]);
    expect(toolbar.find('[aria-label="Hero export resolution"]').exists()).toBe(false);

    await toolbar.get('[aria-label="Exit Hero mode"]').trigger('click');
    expect(toolbar.emitted('exit')).toHaveLength(1);
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

  it('disables scientific rebuild controls for a blank structure', () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createBlankDebugScene(),
      },
    });
    expect(wrapper.text()).toContain('Bond analysis becomes available');
    expect(
      wrapper
        .findAll('section')[3]
        .findAll('select')
        .every((select) => select.attributes('disabled') !== undefined),
    ).toBe(true);
    expect(
      wrapper
        .findAll('fieldset input')
        .every((input) => input.attributes('disabled') !== undefined),
    ).toBe(true);
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
    expect(feedback.get('progress').attributes('aria-label')).toBe('Scientific scene progress');

    await wrapper.setProps({
      rebuildPhase: 'success',
      rebuildMessage: 'Scene rebuilt in 0.4 s.',
      rebuilding: false,
    });
    expect(bondingControl.attributes('disabled')).toBeUndefined();
    expect(feedback.text()).toContain('Scene rebuilt');
    expect(feedback.classes()).toContain('is-success');
    expect(feedback.find('.feedback-spinner').exists()).toBe(false);
    expect(feedback.find('progress').exists()).toBe(false);
  });

  it('rebuilds immediately from scientific controls with MATLAB-serializable payloads', async () => {
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    const scientificSection = wrapper
      .findAll('section')
      .find((section) => section.get('h3').text() === 'Scientific scene')!;
    expect(scientificSection.findAll(':scope > label').map((label) => label.text())).toEqual([
      expect.stringContaining('Change unit cell'),
      expect.stringContaining('Bonding strategy'),
    ]);
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
      .find((control) => control.text().includes('Change unit cell'))!
      .get('select');
    expect(cellControl.findAll('option').map((option) => option.text())).toEqual([
      'Input cell',
      'Primitive cell',
      'Conventional cell',
      'Reduced cell (Niggli)',
      'Reduced cell (LLL)',
    ]);
    await cellControl.setValue('primitive');
    expect((wrapper.emitted('rebuild')?.[1][0] as { cell: string }).cell).toBe('primitive');

    const repeatA = wrapper.get('fieldset input');
    await repeatA.setValue(2);
    expect((wrapper.emitted('rebuild')?.[2][0] as { repeat: number[] }).repeat).toEqual([2, 1, 1]);
    expect(wrapper.text()).not.toContain('Theme changes never alter scientific connectivity');
  });

  it('restores the active unit-cell representation when settings are reopened', () => {
    const scene = createDebugScene();
    scene.analysis.parameters.cell = 'conventional';
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene,
      },
    });
    const cellControl = wrapper
      .findAll('label')
      .find((control) => control.text().includes('Change unit cell'))!
      .get('select');

    expect((cellControl.element as HTMLSelectElement).value).toBe('conventional');
  });

  it('restores the current visual repeat when settings are reopened', async () => {
    const scene = createDebugScene();
    scene.structure.repeat = [1, 2, 2];
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene,
      },
    });
    const repeatInputs = wrapper.findAll('fieldset input');

    expect(repeatInputs.map((input) => (input.element as HTMLInputElement).value)).toEqual([
      '1',
      '2',
      '2',
    ]);

    await repeatInputs[1].setValue(1);
    expect((wrapper.emitted('rebuild')?.[0][0] as { repeat: number[] }).repeat).toEqual([1, 1, 2]);

    const reset = wrapper.get('.repeat-reset-button');
    expect(reset.attributes('disabled')).toBeUndefined();
    await reset.trigger('click');
    expect((wrapper.emitted('rebuild')?.[1][0] as { repeat: number[] }).repeat).toEqual([1, 1, 1]);
    expect(reset.attributes('disabled')).toBeDefined();
  });

  it('stops after one measurement by default and can enable continuous measurement', async () => {
    expect(defaultViewerOptions().continuousMeasurement).toBe(false);
    const wrapper = mount(SettingsPanel, {
      props: {
        modelValue: defaultViewerOptions(),
        scene: createDebugScene(),
      },
    });
    const continuousControl = wrapper
      .findAll('label.check')
      .find((control) => control.text().includes('Continuous measurement'));
    expect(continuousControl).toBeDefined();
    expect(continuousControl!.get('input').element.checked).toBe(false);

    await continuousControl!.get('input').setValue(true);
    const options = wrapper.emitted('update:modelValue')?.[0][0] as ReturnType<
      typeof defaultViewerOptions
    >;
    expect(options.continuousMeasurement).toBe(true);
  });

  it('renders deterministic element legend and toolbar commands', async () => {
    const legend = mount(ElementLegend, {
      props: { scene: createDebugScene(), colorMode: 'vesta' },
    });
    expect(legend.text()).toBe('Cl Na');
    const toolbar = mount(ViewerToolbar, {
      props: {
        settingsOpen: false,
        informationAvailable: true,
        crystal: true,
        sceneAvailable: true,
        structureExportFormats: [
          { format: 'cif', label: 'CIF', extension: 'cif', detail: '.cif' },
          {
            format: 'poscar',
            label: 'VASP POSCAR',
            extension: 'poscar',
            detail: '.poscar',
          },
        ],
      },
    });
    const informationButton = toolbar.get('[aria-label="Structure information"]');
    expect(informationButton.attributes('aria-pressed')).toBe('false');
    expect(informationButton.attributes('disabled')).toBeUndefined();
    expect(informationButton.get('svg').classes()).not.toContain('toolbar-filled-icon');
    expect(informationButton.findAll('svg path')).toHaveLength(2);
    await informationButton.trigger('click');
    expect(toolbar.emitted('toggleInformation')).toHaveLength(1);
    await toolbar.get('[aria-label="Reset camera"]').trigger('click');
    expect(toolbar.emitted('reset')).toHaveLength(1);
    const autoRotate = toolbar.get('[aria-label="Auto rotate"]');
    expect(autoRotate.attributes('aria-pressed')).toBe('false');
    await autoRotate.trigger('click');
    expect(toolbar.emitted('toggleAutoRotation')).toHaveLength(1);
    await toolbar.setProps({ autoRotating: true });
    expect(toolbar.find('[aria-label="Auto rotate"]').exists()).toBe(false);
    expect(toolbar.find('svg.auto-rotate-icon').exists()).toBe(false);
    const stopRotation = toolbar.get('[aria-label="Stop rotation"]');
    expect(stopRotation.attributes('aria-pressed')).toBe('true');
    await stopRotation.trigger('click');
    expect(toolbar.emitted('toggleAutoRotation')).toHaveLength(2);
    expect(toolbar.find('.toolbar-hero').exists()).toBe(false);
    expect(toolbar.find('[aria-label="Hero Shot preview"]').exists()).toBe(false);
    expect(
      toolbar.findAll('.reciprocal-axis-button').map((button) => button.text().trim()),
    ).toEqual(['a*', 'b*', 'c*']);
    const reciprocalA = toolbar.findAll('button').find((button) => button.text() === 'a*');
    await reciprocalA!.trigger('click');
    const emittedAxes = toolbar.emitted('axis')!;
    expect(emittedAxes[emittedAxes.length - 1]).toEqual(['a*']);

    const measurementButton = toolbar.get('[aria-label="Measurements"]');
    await measurementButton.trigger('click');
    expect(measurementButton.attributes('aria-expanded')).toBe('true');
    const measurementMenu = toolbar.get('[aria-label="Measurement tools"]');
    const measurementItems = measurementMenu.findAll('[role="menuitem"]');
    expect(measurementItems).toHaveLength(9);
    expect(measurementItems.map((item) => item.text().trim())).toEqual([
      'Atom-to-atom distance',
      'Bond angle',
      'Dihedral angle',
      'Cell parameters',
      'Bond statistics',
      'Atom-to-plane distance',
      'Plane-to-plane angle',
      'Coordination number',
      'Nearest neighbors',
    ]);
    const angle = measurementMenu
      .findAll('button')
      .find((button) => button.text().includes('Bond angle'))!;
    const cell = measurementMenu
      .findAll('button')
      .find((button) => button.text().includes('Cell parameters'))!;
    expect(angle.attributes('disabled')).toBeUndefined();
    expect(cell.attributes('disabled')).toBeUndefined();
    await cell.trigger('click');
    expect(toolbar.emitted('measure')).toEqual([['cell']]);
    expect(toolbar.find('[aria-label="Measurement tools"]').exists()).toBe(false);

    const imageExportButton = toolbar.get('[aria-label="Export image"]');
    expect(imageExportButton.attributes('aria-expanded')).toBe('false');
    await imageExportButton.trigger('click');
    expect(imageExportButton.attributes('aria-expanded')).toBe('true');
    expect(toolbar.classes()).toContain('has-open-export-menu');
    expect(toolbar.findAll('[role="menuitem"]')).toHaveLength(6);
    expect(toolbar.text()).not.toContain('Hero Shot PNG');
    expect(toolbar.text()).toContain('Lossless high-resolution image');
    expect(toolbar.text()).toContain('Lossless TIFF image (.tif)');
    expect(toolbar.text()).toContain('PDF (Vector)');
    expect(toolbar.text()).toContain('PDF (Raster)');
    const imageFormatButton = (label: string) =>
      toolbar.findAll('[role="menuitem"]').find((button) => button.text().startsWith(label))!;
    await imageFormatButton('TIFF').trigger('click');
    expect(toolbar.emitted('exportImage')).toEqual([['tiff']]);
    expect(toolbar.find('[role="menu"]').exists()).toBe(false);
    expect(toolbar.classes()).not.toContain('has-open-export-menu');

    await imageExportButton.trigger('click');
    await imageFormatButton('SVG').trigger('click');
    await imageExportButton.trigger('click');
    await imageFormatButton('PDF (Vector)').trigger('click');
    await imageExportButton.trigger('click');
    await imageFormatButton('PDF (Raster)').trigger('click');
    expect(toolbar.emitted('exportImage')).toEqual([
      ['tiff'],
      ['svg'],
      ['pdf-vector'],
      ['pdf-raster'],
    ]);

    const fileExportButton = toolbar.get('[aria-label="Export file"]');
    await fileExportButton.trigger('click');
    expect(fileExportButton.attributes('aria-expanded')).toBe('true');
    expect(toolbar.classes()).toContain('has-open-export-menu');
    expect(toolbar.findAll('[role="menuitem"]')).toHaveLength(3);
    const structureSubmenu = toolbar.get('.toolbar-export-submenu');
    const structureExportButton = structureSubmenu.get('button');
    expect(structureExportButton.attributes('aria-expanded')).toBe('false');
    await structureSubmenu.trigger('mouseenter');
    expect(structureExportButton.attributes('aria-expanded')).toBe('true');
    expect(toolbar.get('[aria-label="Structure file formats"]').text()).toContain('VASP POSCAR');
    await structureSubmenu.trigger('mouseleave');
    expect(structureExportButton.attributes('aria-expanded')).toBe('false');
    await structureExportButton.trigger('click');
    expect(structureExportButton.attributes('aria-expanded')).toBe('true');
    const cifButton = toolbar
      .findAll('[aria-label="Structure file formats"] button')
      .find((button) => button.text().includes('CIF'))!;
    await cifButton.trigger('click');
    expect(toolbar.emitted('exportStructure')).toEqual([['cif']]);

    await fileExportButton.trigger('click');
    const offlineHtmlButton = toolbar
      .findAll('[aria-label="File exports"] > button')
      .find((button) => button.text().includes('Offline HTML'))!;
    await offlineHtmlButton.trigger('click');
    expect(toolbar.emitted('exportOfflineHtml')).toHaveLength(1);
    await fileExportButton.trigger('click');
    const sceneJsonButton = toolbar
      .findAll('[aria-label="File exports"] > button')
      .find((button) => button.text().includes('Scene JSON'))!;
    await sceneJsonButton.trigger('click');
    expect(toolbar.emitted('exportScene')).toHaveLength(1);

    const fullscreenButton = toolbar.get('[aria-label="Fullscreen"]');
    await fullscreenButton.trigger('click');
    expect(toolbar.emitted('fullscreen')).toHaveLength(1);
  });

  it('raises the image export menu when the viewport has insufficient space below', async () => {
    const originalInnerHeight = window.innerHeight;
    Object.defineProperty(window, 'innerHeight', { configurable: true, value: 500 });
    const bounds = (top: number, height: number): DOMRect =>
      ({
        top,
        bottom: top + height,
        left: 0,
        right: 30,
        width: 30,
        height,
        x: 0,
        y: top,
        toJSON: () => ({}),
      }) as DOMRect;
    const boundsSpy = vi
      .spyOn(HTMLElement.prototype, 'getBoundingClientRect')
      .mockImplementation(function (this: HTMLElement) {
        if (this.getAttribute('aria-label') === 'Export image') return bounds(420, 30);
        if (this.classList.contains('toolbar-export-menu')) return bounds(420, 30);
        return bounds(0, 0);
      });
    const scrollHeightSpy = vi
      .spyOn(HTMLElement.prototype, 'scrollHeight', 'get')
      .mockReturnValue(280);
    try {
      const toolbar = mount(ViewerToolbar, {
        props: { settingsOpen: false, crystal: true, sceneAvailable: true },
      });
      await toolbar.get('[aria-label="Export image"]').trigger('click');
      await nextTick();

      const menu = toolbar.get('[aria-label="Image formats"]');
      const initialTop = Number.parseFloat((menu.element as HTMLElement).style.top);
      expect(initialTop).toBeLessThan(0);
      expect(menu.attributes('style')).toContain('max-height: 476px');
      expect(menu.classes()).toContain('toolbar-image-export-popover');
      expect(menu.classes()).not.toContain('is-positioning');

      Object.defineProperty(window, 'innerHeight', { configurable: true, value: 360 });
      window.dispatchEvent(new Event('resize'));
      await nextTick();
      await nextTick();
      expect(Number.parseFloat((menu.element as HTMLElement).style.top)).toBeLessThanOrEqual(
        initialTop,
      );
      expect(menu.attributes('style')).toContain('max-height: 336px');

      toolbar.unmount();
    } finally {
      boundsSpy.mockRestore();
      scrollHeightSpy.mockRestore();
      Object.defineProperty(window, 'innerHeight', {
        configurable: true,
        value: originalInnerHeight,
      });
    }
  });

  it('disables measurements when no atomic geometry is available', async () => {
    const toolbar = mount(ViewerToolbar, {
      props: { settingsOpen: false, crystal: true, sceneAvailable: false },
    });
    const measurementButton = toolbar.get('[aria-label="Measurements"]');
    expect(measurementButton.attributes('disabled')).toBeDefined();
    await measurementButton.trigger('click');
    expect(toolbar.find('[aria-label="Measurement tools"]').exists()).toBe(false);
    const informationButton = toolbar.get('[aria-label="Structure information"]');
    expect(informationButton.attributes('disabled')).toBeDefined();
    await informationButton.trigger('click');
    expect(toolbar.emitted('toggleInformation')).toBeUndefined();
  });

  it('does not expose reciprocal-lattice views for molecules', () => {
    const toolbar = mount(ViewerToolbar, { props: { settingsOpen: false, crystal: false } });
    expect(toolbar.findAll('button')).toHaveLength(10);
    expect(toolbar.text()).not.toContain('a*');
  });

  it('turns the measurement tool into a stop button while measuring', async () => {
    const toolbar = mount(ViewerToolbar, {
      props: {
        settingsOpen: false,
        crystal: true,
        sceneAvailable: true,
        activeMeasurementKind: 'dihedral',
      },
    });
    expect(toolbar.find('[aria-label="Measurements"]').exists()).toBe(false);
    const stop = toolbar.get('[aria-label="Stop measurement"]');
    expect(stop.attributes('aria-pressed')).toBe('true');
    expect(stop.find('svg.measurement-stop-icon').exists()).toBe(true);
    expect(toolbar.find('[aria-label="Measurement tools"]').exists()).toBe(false);
    await stop.trigger('click');
    expect(toolbar.emitted('stopMeasurement')).toHaveLength(1);
  });

  it('offers the same host-provided export submenu for molecules', async () => {
    const toolbar = mount(ViewerToolbar, {
      props: {
        settingsOpen: false,
        crystal: false,
        structureExportFormats: [
          { format: 'xyz', label: 'XYZ', extension: 'xyz', detail: '.xyz' },
          { format: 'pdb', label: 'PDB', extension: 'pdb', detail: '.pdb' },
        ],
      },
    });

    await toolbar.get('[aria-label="Export file"]').trigger('click');
    await toolbar.get('.toolbar-export-submenu-trigger').trigger('click');
    const moleculeFormats = toolbar.get('[aria-label="Structure file formats"]');
    expect(moleculeFormats.text()).toContain('XYZ');
    expect(moleculeFormats.text()).toContain('PDB');
    const pdb = moleculeFormats.findAll('button').find((button) => button.text().includes('PDB'))!;
    await pdb.trigger('click');
    expect(toolbar.emitted('exportStructure')).toEqual([['pdb']]);
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
    expect(atom.text()).toContain('Cartesian');
    expect(atom.text()).toContain('0.000, 0.000, 0.000 Å');
    expect(atom.text()).toContain('Fractional');
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
    expect(atom.text()).toContain('Bond length');
    expect(atom.text()).toContain(scene.bondInstances[0].distance.toFixed(5));
    expect(atom.text()).toContain('Å');
  });

  it('shows the current species when a modeled site retains an older label', () => {
    const scene = createDebugScene();
    const site = {
      ...scene.sites[0],
      label: 'B',
      species: [{ ...scene.sites[0].species[0], symbol: 'C' }],
    };
    const atom = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'atom',
          id: scene.atomInstances[0].id,
          atom: scene.atomInstances[0],
          site,
          clientX: 0,
          clientY: 0,
        },
      },
    });

    expect(atom.get('.selection-heading h2').text()).toBe('C');
    expect(atom.text()).toContain('C 1');
  });

  it('reports the rendered periodic image in the atom information card', () => {
    const scene = createDebugScene();
    const repeatedAtom = scene.atomInstances.find((atom) => atom.imageOffset[0] === 1)!;
    const atom = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'atom',
          id: repeatedAtom.id,
          atom: repeatedAtom,
          site: scene.sites[repeatedAtom.siteIndex],
          clientX: 0,
          clientY: 0,
        },
      },
    });
    expect(atom.text()).toContain('1.000, 0.000, 0.000');
    expect(atom.text()).toContain('Image');
    expect(atom.text()).toContain('1, 0, 0');
  });

  it('copies full-precision atom coordinates while displaying three decimals', async () => {
    const scene = createDebugScene();
    const writeText = vi.fn(async () => undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });
    const atom = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'atom',
          id: 'precise-atom',
          atom: {
            ...scene.atomInstances[0],
            id: 'precise-atom',
            position: [1.251113, -3.611651, 6.765654],
          },
          site: {
            ...scene.sites[0],
            fractional: [1 / 3, -1 / 3, 1],
          },
          clientX: 0,
          clientY: 0,
        },
      },
    });
    expect(atom.text()).toContain('1.251, -3.612, 6.766 Å');
    expect(atom.text()).toContain('0.333, -0.333, 1.000');

    await atom.get('[aria-label="Copy Cartesian coordinates"]').trigger('click');
    expect(writeText).toHaveBeenLastCalledWith('1.251113, -3.611651, 6.765654 Å');
    expect(atom.find('[aria-label="Cartesian coordinates copied"]').exists()).toBe(true);

    await atom.get('[aria-label="Copy Fractional coordinates"]').trigger('click');
    expect(writeText).toHaveBeenLastCalledWith('0.3333333333333333, -0.3333333333333333, 1');
  });

  it('reuses the selection card for compact measurement results', async () => {
    const scene = createDebugScene();
    const wrapper = mount(SelectionInspector, {
      props: {
        selection: {
          kind: 'atom',
          id: scene.atomInstances[0].id,
          atom: scene.atomInstances[0],
          site: scene.sites[0],
          clientX: 0,
          clientY: 0,
        },
        measurement: {
          id: 'measurement-2',
          kind: 'distance',
          title: 'Bond length',
          summary: 'Distance: 1.23456 Å',
          details: 'Sites: #1 C – #2 O',
          annotation: {
            id: 'measurement-2',
            kind: 'distance',
            label: 'Distance: 1.23456 Å',
            points: [],
            segments: [],
            planePoints: [],
          },
        },
      },
    });
    expect(wrapper.text()).not.toContain('saved');
    expect(wrapper.get('.measurement-result > span').text()).toBe('Distance');
    expect(wrapper.get('.measurement-result strong').text()).toBe('1.23456 Å');
    expect(wrapper.findAll('.measurement-site-token').map((item) => item.text())).toEqual([
      '#1 C',
      '#2 O',
    ]);
    expect(wrapper.findAll('.measurement-path-arrow')).toHaveLength(1);
    expect(wrapper.text()).not.toContain('Site 1');
    await wrapper.get('[aria-label="Close measurement result"]').trigger('click');
    expect(wrapper.emitted('closeMeasurement')).toHaveLength(1);
    expect(wrapper.get('[aria-live="polite"]').attributes('aria-live')).toBe('polite');
  });

  it('replaces geometric site paths with pose-preserving measurement diagrams', async () => {
    const dihedral: MeasurementRecord = {
      id: 'dihedral',
      kind: 'dihedral',
      title: 'Dihedral angle',
      summary: 'Dihedral: 129.114°',
      details: 'Sites: #3 Al – #9 O – #1 Al – #2 Al',
      siteLabels: ['#3 Al', '#9 O', '#1 Al', '#2 Al'],
      diagram: {
        points: [
          [-0.9, -0.45],
          [-0.25, 0.15],
          [0.3, -0.05],
          [0.9, 0.5],
        ],
      },
      annotation: {
        id: 'dihedral',
        kind: 'dihedral',
        label: 'Dihedral: 129.114°',
        points: [
          [0, 0, 0],
          [1, 0, 0],
          [1, 1, 0],
          [1, 1, 1],
        ],
        segments: [],
        planePoints: [],
      },
    };
    const wrapper = mount(SelectionInspector, { props: { measurement: dihedral } });

    const diagram = wrapper.get('svg.measurement-geometry');
    expect(diagram.attributes('aria-label')).toContain('#3 Al to #9 O to #1 Al to #2 Al');
    expect(wrapper.get('.measurement-detail-label').text()).toBe('Geometry');
    expect(diagram.findAll('.measurement-geometry-site')).toHaveLength(4);
    expect(
      diagram
        .findAll('.measurement-geometry-site')
        .map((site) => site.attributes('data-site-label')),
    ).toEqual(['#3 Al', '#9 O', '#1 Al', '#2 Al']);
    expect(diagram.findAll('.measurement-geometry-plane')).toHaveLength(2);
    expect(diagram.findAll('.measurement-geometry-bond')).toHaveLength(3);
    expect(wrapper.find('.measurement-site-path').exists()).toBe(false);

    const atomPlane: MeasurementRecord = {
      ...dihedral,
      id: 'atom-plane',
      kind: 'atom_plane',
      title: 'Atom-to-plane distance',
      summary: 'Atom-to-plane distance: 2.00000 Å',
      details: 'Sites: #7 C – #2 C – #1 C – #3 C',
      siteLabels: ['#7 C', '#2 C', '#1 C', '#3 C'],
      diagram: {
        points: [
          [0, -0.8],
          [-0.8, 0.45],
          [0.8, 0.45],
          [0, 0.05],
        ],
        projection: [0, 0.05],
      },
      annotation: {
        ...dihedral.annotation,
        id: 'atom-plane',
        kind: 'atom_plane',
        label: 'Atom-to-plane distance: 2.00000 Å',
      },
    };
    await wrapper.setProps({ measurement: atomPlane });
    expect(wrapper.findAll('.measurement-geometry-plane')).toHaveLength(1);
    expect(wrapper.find('.measurement-geometry-distance').exists()).toBe(true);
    expect(wrapper.find('.measurement-geometry-projection').exists()).toBe(true);
    expect(wrapper.find('.measurement-geometry-perpendicular').text()).toBe('⊥');
    const projection = wrapper.get('.measurement-geometry-projection');
    const lastPlaneSite = wrapper.findAll('.measurement-geometry-site')[3];
    const match = /translate\(([-\d.]+) ([-\d.]+)\)/.exec(
      lastPlaneSite.attributes('transform') ?? '',
    );
    expect(`${projection.attributes('cx')},${projection.attributes('cy')}`).not.toBe(
      `${match?.[1]},${match?.[2]}`,
    );
  });

  it('keeps nearest-neighbor distances and units together in structured rows', () => {
    const scene = createDebugScene();
    const nearest = mount(SelectionInspector, {
      props: { measurement: measureScene(scene, 'nearest_neighbors', [1], 'nearest') },
    });
    const rows = nearest.findAll('.measurement-neighbor-list li');

    expect(rows).toHaveLength(8);
    expect(rows[0].get('.measurement-neighbor-identity').text()).toContain('image [');
    expect(rows[0].get('.measurement-neighbor-distance').text()).toMatch(/^\d+\.\d{5}\sÅ$/);
    expect(nearest.find('.measurement-details').exists()).toBe(false);

    const coordination = mount(SelectionInspector, {
      props: { measurement: measureScene(scene, 'coordination', [1], 'coordination') },
    });
    expect(coordination.findAll('.measurement-neighbor-list li')).toHaveLength(8);
  });

  it('lays out cell parameters in copyable rows without retained-result labels', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });
    const record = measureScene(createDebugScene(), 'cell', [], 'cell');
    const wrapper = mount(SelectionInspector, { props: { measurement: record } });

    expect(wrapper.text()).not.toContain('saved');
    expect(wrapper.findAll('.cell-parameter-list > div')).toHaveLength(6);
    expect(wrapper.findAll('.cell-parameter-list > div').map((row) => row.text())).toEqual([
      'a5.64000Å',
      'b5.64000Å',
      'c5.64000Å',
      'α90.000°',
      'β90.000°',
      'γ90.000°',
    ]);

    await wrapper.get('[aria-label="Copy cell lengths"]').trigger('click');
    expect(writeText).toHaveBeenLastCalledWith('a = 5.64 Å\nb = 5.64 Å\nc = 5.64 Å');
    expect(wrapper.find('[aria-label="Cell lengths copied"]').exists()).toBe(true);

    await wrapper.get('[aria-label="Copy cell angles"]').trigger('click');
    expect(writeText).toHaveBeenLastCalledWith('α = 90°\nβ = 90°\nγ = 90°');

    await wrapper.get('[aria-label="Copy cell volume"]').trigger('click');
    expect(writeText).toHaveBeenLastCalledWith(`Volume = ${record.cellValues!.volume} Å³`);
  });

  it('separates bond count, average, range, and empty-state statistics', () => {
    const scene = createDebugScene();
    const populatedRecord = measureScene(scene, 'bond_stats', [0, 1], 'populated');
    const populated = mount(SelectionInspector, {
      props: { measurement: populatedRecord },
    });

    expect(populated.find('.measurement-result').exists()).toBe(false);
    expect(populated.findAll('.bond-statistics-primary > div')).toHaveLength(2);
    expect(populated.findAll('.bond-statistics-primary > div').map((item) => item.text())).toEqual([
      'Bonds8',
      `Average${populatedRecord.bondStatistics!.average!.toFixed(5)} Å`,
    ]);
    expect(populated.findAll('.bond-statistics-range > div')).toHaveLength(2);
    expect(populated.get('.bond-statistics-summary').text()).not.toContain('·');

    scene.bondRelations = [];
    const empty = mount(SelectionInspector, {
      props: { measurement: measureScene(scene, 'bond_stats', [0, 1], 'empty') },
    });
    expect(empty.get('.bond-statistics-empty').text()).toBe('No bonds found');
    expect(empty.find('.bond-statistics-primary').exists()).toBe(false);
    expect(empty.find('.bond-statistics-range').exists()).toBe(false);
    expect(empty.get('.bond-statistics-algorithm').text()).toBe('AlgorithmCrystalNN');
    expect(empty.text()).not.toContain('found no matching bonds');
  });

  it('guides ordered atom picking for geometric measurements', () => {
    const wrapper = mount(SelectionInspector, {
      props: {
        measurementKind: 'atom_plane',
        measurementSelectionCount: 2,
      },
    });
    expect(wrapper.text()).toContain('Measurement mode');
    expect(wrapper.text()).toContain('Atom-to-plane distance');
    expect(wrapper.text()).toContain('2/4');
    expect(wrapper.text()).toContain('second plane atom');
    expect(wrapper.get('.measurement-guide').text()).not.toContain('stop button');
    expect(wrapper.get('.measurement-stop-hint').text()).toContain(
      'Click the stop button at any time to end measurement mode.',
    );
    expect(wrapper.find('.measurement-stop-hint em').exists()).toBe(true);
    expect(wrapper.classes()).toContain('measurement-mode');
  });
});
