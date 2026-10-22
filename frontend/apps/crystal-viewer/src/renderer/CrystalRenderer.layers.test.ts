import { Scene, Vector2 } from 'three';
import { describe, expect, it, vi } from 'vitest';

import { createDebugScene } from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import { CrystalRenderer } from './CrystalRenderer';

const renderedScenes = vi.hoisted(() => [] as Scene[]);

vi.mock('./GleamoePathTracer', () => ({ GleamoePathTracer: class {} }));

// Keep real scene geometry and controls; replace only the GPU boundary.
vi.mock('three', async (importOriginal) => ({
  ...(await importOriginal<typeof import('three')>()),
  WebGLRenderer: class {
    info = { autoReset: false, reset() {}, render: { calls: 0, triangles: 0 } };
    shadowMap = { enabled: false, type: 0 };
    setPixelRatio() {}
    setClearColor() {}
    setSize() {}
    getSize(target: Vector2) {
      return target.set(800, 600);
    }
    setScissorTest() {}
    setViewport() {}
    setScissor() {}
    clear() {}
    clearDepth() {}
    render(scene: Scene) {
      renderedScenes.push(scene);
    }
    dispose() {}
    forceContextLoss() {}
  },
}));

describe('optional scene layers', () => {
  it('creates hidden overlays on demand, reuses them, and drops them on scene replacement', () => {
    const canvas = document.createElement('canvas');
    document.body.append(canvas);
    const options = { ...defaultViewerOptions(), showPolyhedra: false, showMagmoms: false };
    const renderer = new CrystalRenderer(canvas, options);
    try {
      const scene = createDebugScene();
      scene.sites[0].magmom = [0, 0, 1];
      renderer.setScene(scene);
      const world = renderedScenes.find((entry) => entry.getObjectByName('crystal-unit-cell'))!;
      expect(world.getObjectByName('crystal-polyhedron-layer')).toBeUndefined();
      expect(world.getObjectByName('crystal-magnetic-moments')).toBeUndefined();

      renderer.setOptions({ ...options, showPolyhedra: true, showMagmoms: true });
      const polyhedra = world.getObjectByName('crystal-polyhedra');
      const magmoms = world.getObjectByName('crystal-magnetic-moments');
      expect(polyhedra).toBeDefined();
      expect(magmoms).toBeDefined();
      renderer.setOptions(options);
      expect(magmoms?.visible).toBe(false);
      renderer.setOptions({ ...options, showPolyhedra: true, showMagmoms: true });
      expect(world.getObjectByName('crystal-polyhedra')).toBe(polyhedra);
      expect(world.getObjectByName('crystal-magnetic-moments')).toBe(magmoms);
      expect(magmoms?.visible).toBe(true);

      renderer.setOptions(options);
      renderer.setScene(createDebugScene());
      expect(world.getObjectByName('crystal-polyhedron-layer')).toBeUndefined();
      expect(world.getObjectByName('crystal-magnetic-moments')).toBeUndefined();
    } finally {
      renderer.dispose();
      canvas.remove();
      renderedScenes.length = 0;
    }
  });
});
