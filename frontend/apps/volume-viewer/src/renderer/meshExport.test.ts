import { describe, expect, it } from 'vitest';
import { Box3, Mesh } from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

import { encodeGlb, encodeGltf, encodePly, encodeStl } from './meshExport';

const triangle = new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]);

describe('isosurface mesh export', () => {
  it('writes an ASCII PLY with matching vertex and face counts', () => {
    const output = encodePly(triangle);
    expect(output).toContain('element vertex 3');
    expect(output).toContain('element face 1');
    expect(output).toContain('3 0 1 2');
    const lines = output.trim().split('\n');
    const start = lines.indexOf('end_header') + 1;
    const roundTrip = lines
      .slice(start, start + 3)
      .map((line) => line.split(' ').map(Number));
    expect(roundTrip).toEqual([[0, 0, 0], [1, 0, 0], [0, 1, 0]]);
  });

  it('writes an STL with a normalized triangle normal', () => {
    const output = encodeStl(triangle);
    expect(output).toContain('facet normal 0 0 1');
    expect(output).toContain('vertex 1 0 0');
    const roundTrip = [...output.matchAll(/vertex ([^ ]+) ([^ ]+) ([^\n]+)/g)].map(
      (match) => match.slice(1).map(Number),
    );
    expect(roundTrip).toEqual([[0, 0, 0], [1, 0, 0], [0, 1, 0]]);
  });

  it('round-trips a binary glTF with the same world bounds', async () => {
    const glb = await encodeGlb(triangle);
    expect(new DataView(glb).getUint32(0, true)).toBe(0x46546c67);
    const result = await new GLTFLoader().parseAsync(glb, '');
    const bounds = new Box3();
    result.scene.traverse((object) => {
      if (object instanceof Mesh) bounds.expandByObject(object);
    });
    expect(bounds.min.toArray()).toEqual([0, 0, 0]);
    expect(bounds.max.toArray()).toEqual([1, 1, 0]);
  });

  it('round-trips a self-contained JSON glTF with the same world bounds', async () => {
    const gltf = await encodeGltf(triangle);
    const document = JSON.parse(gltf) as { asset: { version: string } };
    expect(document.asset.version).toBe('2.0');
    const result = await new GLTFLoader().parseAsync(gltf, '');
    const bounds = new Box3();
    result.scene.traverse((object) => {
      if (object instanceof Mesh) bounds.expandByObject(object);
    });
    expect(bounds.min.toArray()).toEqual([0, 0, 0]);
    expect(bounds.max.toArray()).toEqual([1, 1, 0]);
  });
});
