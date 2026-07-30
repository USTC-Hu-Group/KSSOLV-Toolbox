import type { CrystalSceneSpec } from '@kssolv/atomic-scene';
import { describe, expect, it } from 'vitest';

import { AtomicOverlayLayer } from './AtomicOverlayLayer';

const scene = (): CrystalSceneSpec => ({
  schemaVersion: '2.0',
  kind: 'crystal',
  requestId: 'bounds-test',
  sites: [
    {
      id: 'site-0',
      siteIndex: 0,
      label: 'Si',
      species: [
        {
          symbol: 'Si',
          occupancy: 1,
          atomicNumber: 14,
          colorVesta: [35, 69, 250],
          colorJmol: [240, 200, 160],
          atomicRadius: 2,
        },
      ],
      fractional: [10, 0, 0],
      cartesian: [20, 0, 0],
    },
  ],
  atomInstances: [
    {
      id: 'site-0@10,0,0',
      siteId: 'site-0',
      siteIndex: 0,
      imageOffset: [10, 0, 0],
      position: [20, 0, 0],
      visibility: 'bonded',
    },
  ],
  bondRelations: [],
  bondInstances: [],
  polyhedra: [],
  structure: {
    formula: 'Si',
    lattice: [
      [2, 0, 0],
      [0, 2, 0],
      [0, 0, 2],
    ],
    periodic: [true, true, true],
    repeat: [1, 1, 1],
    siteCount: 1,
    isOrdered: true,
  },
  analysis: {
    algorithm: 'CrystalNN',
    parameters: {},
    source: 'matgenlab',
    sourceVersion: 'test',
    elapsedMilliseconds: 0,
  },
  warnings: [],
});

describe('atomic overlay bounds', () => {
  it('include atoms outside the unit cell for joint camera fitting', () => {
    const layer = new AtomicOverlayLayer(scene());
    const bounds = layer.getBounds();

    expect(bounds.min.x).toBeLessThanOrEqual(0);
    expect(bounds.max.x).toBeGreaterThan(20.5);

    layer.dispose();
  });
});
