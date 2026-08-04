import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createBlankDebugScene, createDebugScene } from '../scene/debugScene';

describe('viewer store event ordering', () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it('rejects stale scenes after a newer request begins', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    matlabBridge.dispatchForTesting('scene:begin', { requestId: 'current' });
    const stale = createDebugScene();
    stale.requestId = 'stale';
    matlabBridge.dispatchForTesting('scene:set', stale);
    expect(store.scene.value).toBeUndefined();
    const current = createDebugScene();
    current.requestId = 'current';
    matlabBridge.dispatchForTesting('scene:set', current);
    expect(store.scene.value?.requestId).toBe('current');
    expect(store.status.loading).toBe(false);
  });

  it('changes themes without resetting current display settings', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    store.updateOptions({
      radiusMode: 'uniform',
      showAtoms: false,
      showBonds: false,
      showUnitCell: false,
      showPolyhedra: false,
      showAxes: false,
      showBoundaryAtoms: false,
      showBondedOutside: false,
      hideIncompleteBonds: true,
      showMagmoms: true,
      showStatistics: true,
    });
    const materialsSettings = { ...store.options };

    store.setTheme('pretty');
    expect({ ...store.options, theme: materialsSettings.theme }).toEqual(materialsSettings);

    matlabBridge.dispatchForTesting('theme:set', 'materials');
    expect({ ...store.options }).toEqual(materialsSettings);
  });

  it('reports invalid scenes', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const emit = vi.spyOn(matlabBridge, 'emit');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    matlabBridge.dispatchForTesting('scene:set', { schemaVersion: '0' });
    expect(store.status.error).toContain('schemaVersion');
    expect(emit).toHaveBeenCalledWith(
      'viewer:error',
      expect.objectContaining({ code: 'SCENE_VALIDATION' }),
    );
  });

  it('accepts blank structures without reporting an error or warning banner', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const emit = vi.spyOn(matlabBridge, 'emit');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();

    matlabBridge.dispatchForTesting('scene:set', createBlankDebugScene());

    expect(store.isBlankStructure.value).toBe(true);
    expect(store.formula.value).toBe('Blank structure');
    expect(store.warnings.value).toEqual([]);
    expect(store.status.error).toBe('');
    expect(emit).not.toHaveBeenCalledWith(
      'viewer:error',
      expect.objectContaining({ code: 'SCENE_VALIDATION' }),
    );
  });

  it('reports queued, building, and completed rebuild states', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const emit = vi.spyOn(matlabBridge, 'emit');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    const scene = createDebugScene();
    scene.requestId = 'rebuilt';

    store.requestAnalysis({
      requestId: 'previous',
      algorithm: 'CrystalNN',
      cell: 'input',
      repeat: [1, 1, 1],
    });
    expect(store.status.activityPhase).toBe('queued');
    expect(store.status.loading).toBe(true);
    expect(emit).toHaveBeenCalledWith(
      'viewer:analysisRequested',
      expect.objectContaining({ algorithm: 'CrystalNN' }),
    );

    matlabBridge.dispatchForTesting('scene:begin', { requestId: 'rebuilt' });
    expect(store.status.activityPhase).toBe('building');
    matlabBridge.dispatchForTesting('scene:set', scene);
    expect(store.status.activityPhase).toBe('success');
    expect(store.status.activityMessage).toContain('Scene rebuilt');
    expect(store.status.loading).toBe(false);
    store.clearActivity();
    expect(store.status.activityPhase).toBe('idle');
  });

  it('stops waiting when MATLAB does not acknowledge a rebuild', async () => {
    vi.useFakeTimers();
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    store.requestAnalysis({
      requestId: 'previous',
      algorithm: 'CrystalNN',
      cell: 'input',
      repeat: [1, 1, 1],
    });

    await vi.advanceTimersByTimeAsync(5_000);
    expect(store.status.loading).toBe(false);
    expect(store.status.activityPhase).toBe('error');
    expect(store.status.activityMessage).toContain('did not acknowledge');
    vi.useRealTimers();
  });

  it('emits zero-based multi-site selections for MATLAB conversion', async () => {
    const { matlabBridge } = await import('../bridge/matlabBridge');
    const emit = vi.spyOn(matlabBridge, 'emit');
    const { useViewerStore } = await import('./viewerStore');
    const store = useViewerStore();
    const scene = createDebugScene();
    store.setScene(scene);

    store.setSelection({
      kind: 'atom',
      id: scene.atomInstances[0].id,
      atom: scene.atomInstances[0],
      site: scene.sites[0],
      clientX: 0,
      clientY: 0,
    });
    store.setSelection(
      {
        kind: 'atom',
        id: scene.atomInstances[1].id,
        atom: scene.atomInstances[1],
        site: scene.sites[1],
        clientX: 0,
        clientY: 0,
      },
      { additive: true },
    );

    expect(store.selectedSiteIndices.value).toEqual([0, 1]);
    expect(emit).toHaveBeenLastCalledWith(
      'viewer:selection',
      expect.objectContaining({ siteIndex: 1, siteIndices: [0, 1] }),
    );
  });
});
