import { NoBlending, OrthographicCamera } from 'three';
import { describe, expect, it, vi } from 'vitest';

import { createDebugScene } from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import { themes } from '../themes/themes';
import { GleamoePathTracer } from './GleamoePathTracer';

const mocks = vi.hoisted(() => ({
  tracer: {
    target: { texture: { name: 'completed accumulation' } },
    tiles: { set: vi.fn() },
    textureSize: { set: vi.fn() },
    setScene: vi.fn(),
    reset: vi.fn(),
    dispose: vi.fn(),
    renderSample: vi.fn(),
  },
  quads: [] as Array<{
    material: any;
    render: ReturnType<typeof vi.fn>;
    dispose: ReturnType<typeof vi.fn>;
  }>,
}));

vi.mock('three-gpu-pathtracer', async () => {
  const { Color } = await import('three');
  return {
    DenoiseMaterial: class {
      uniforms = {};
      fragmentShader = '';
      dispose = vi.fn();
    },
    GradientEquirectTexture: class {
      image: { width: number };
      topColor = new Color();
      bottomColor = new Color();
      update = vi.fn();
      dispose = vi.fn();
      constructor(width: number) {
        this.image = { width };
      }
    },
    WebGLPathTracer: class {
      constructor() {
        return mocks.tracer;
      }
    },
  };
});

vi.mock('three/examples/jsm/postprocessing/Pass.js', () => ({
  FullScreenQuad: class {
    render = vi.fn();
    dispose = vi.fn();
    constructor(public material: any) {
      mocks.quads.push(this);
    }
  },
}));

describe('completed Gleamoe export frame', () => {
  it('draws the accumulated texture at full opacity without advancing or resetting samples', () => {
    const renderer = { autoClear: true };
    const camera = new OrthographicCamera();
    camera.position.set(15, 15, 15);
    const pathTracer = new GleamoePathTracer(renderer as never, camera as never);
    pathTracer.rebuild(
      createDebugScene(),
      {
        ...defaultViewerOptions(),
        renderMode: 'quality',
        renderQuality: 'ultra',
      },
      themes['gleamoe-premiror'],
    );
    mocks.tracer.reset.mockClear();
    const quad = mocks.quads[mocks.quads.length - 1]!;
    quad.material.opacity = 0.1;
    quad.material.transparent = true;

    pathTracer.renderFinal();

    expect(quad.render).toHaveBeenCalledWith(renderer);
    expect(quad.material.map).toBe(mocks.tracer.target.texture);
    expect(quad.material.opacity).toBe(1);
    expect(quad.material.transparent).toBe(false);
    expect(quad.material.blending).toBe(NoBlending);
    expect(mocks.tracer.renderSample).not.toHaveBeenCalled();
    expect(mocks.tracer.reset).not.toHaveBeenCalled();
    expect(renderer.autoClear).toBe(true);
    pathTracer.dispose();
    expect(quad.dispose).toHaveBeenCalled();
  });
});
