import type {
  AtomInstanceSpec,
  BondInstanceSpec,
  BondRelationSpec,
  CrystalSceneSpec,
  MoleculeSceneSpec,
  RgbTuple,
  SiteSpec,
  Vector3Tuple,
} from './types';

const lattice = 5.64;
const colors: Record<string, RgbTuple> = {
  Na: [249, 220, 60],
  Cl: [49, 252, 2],
};

const jmol: Record<string, RgbTuple> = {
  Na: [171, 92, 242],
  Cl: [31, 240, 31],
};

const sites: SiteSpec[] = [
  {
    id: 'site-0',
    siteIndex: 0,
    label: 'Na',
    fractional: [0, 0, 0],
    cartesian: [0, 0, 0],
    species: [
      {
        symbol: 'Na',
        occupancy: 1,
        atomicNumber: 11,
        colorVesta: colors.Na,
        colorJmol: jmol.Na,
        atomicRadius: 1.8,
      },
    ],
  },
  {
    id: 'site-1',
    siteIndex: 1,
    label: 'Cl',
    fractional: [0.5, 0.5, 0.5],
    cartesian: [lattice / 2, lattice / 2, lattice / 2],
    species: [
      {
        symbol: 'Cl',
        occupancy: 1,
        atomicNumber: 17,
        colorVesta: colors.Cl,
        colorJmol: jmol.Cl,
        atomicRadius: 1,
      },
    ],
  },
];

const offsets: Vector3Tuple[] = [
  [0, 0, 0],
  [1, 0, 0],
  [0, 1, 0],
  [0, 0, 1],
  [1, 1, 0],
  [1, 0, 1],
  [0, 1, 1],
  [1, 1, 1],
];

const atomInstances: AtomInstanceSpec[] = offsets.map((offset, index) => ({
  id: `site-0@${offset.join(',')}`,
  siteId: 'site-0',
  siteIndex: 0,
  imageOffset: offset,
  position: [offset[0] * lattice, offset[1] * lattice, offset[2] * lattice],
  visibility: index === 0 ? 'base' : 'boundary',
}));
atomInstances.push({
  id: 'site-1@0,0,0',
  siteId: 'site-1',
  siteIndex: 1,
  imageOffset: [0, 0, 0],
  position: [lattice / 2, lattice / 2, lattice / 2],
  visibility: 'base',
});

const bondRelations: BondRelationSpec[] = offsets.map((offset, index) => ({
  id: `bond-relation-${index}`,
  fromSiteIndex: 1,
  toSiteIndex: 0,
  relativeImage: offset,
  distance: Math.sqrt(3 * (lattice / 2) ** 2),
  weight: 1,
}));

const bondInstances: BondInstanceSpec[] = offsets.map((offset, index) => ({
  id: `bond-${index}`,
  relationId: `bond-relation-${index}`,
  fromSiteIndex: 1,
  toSiteIndex: 0,
  fromImage: [0, 0, 0],
  toImage: offset,
  start: [lattice / 2, lattice / 2, lattice / 2],
  end: [offset[0] * lattice, offset[1] * lattice, offset[2] * lattice],
  distance: Math.sqrt(3 * (lattice / 2) ** 2),
  visibility: index === 0 ? 'base' : 'bonded',
}));

export const createDebugScene = (): CrystalSceneSpec =>
  structuredClone({
    schemaVersion: '2.0',
    kind: 'crystal',
    requestId: 'debug-1',
    structure: {
      formula: 'NaCl',
      lattice: [
        [lattice, 0, 0],
        [0, lattice, 0],
        [0, 0, lattice],
      ],
      periodic: [true, true, true],
      repeat: [1, 1, 1],
      siteCount: sites.length,
      isOrdered: true,
    },
    sites,
    atomInstances,
    bondRelations,
    bondInstances,
    polyhedra: [
      {
        id: 'polyhedron-0',
        centerSiteIndex: 1,
        center: [lattice / 2, lattice / 2, lattice / 2],
        vertices: offsets.map((offset) => [
          offset[0] * lattice,
          offset[1] * lattice,
          offset[2] * lattice,
        ]),
        color: colors.Na,
        visibility: 'base',
      },
    ],
    analysis: {
      algorithm: 'CrystalNN',
      parameters: {},
      source: 'matgenlab',
      sourceVersion: 'debug',
      elapsedMilliseconds: 0,
    },
    warnings: [],
  } satisfies CrystalSceneSpec);

export const createStressScene = (count = 10_000): CrystalSceneSpec => {
  const scene = createDebugScene();
  const side = Math.ceil(Math.cbrt(count));
  scene.requestId = `stress-${count}`;
  scene.structure.formula = `C${count}`;
  scene.structure.siteCount = 1;
  scene.structure.lattice = [
    [side * 1.7, 0, 0],
    [0, side * 1.7, 0],
    [0, 0, side * 1.7],
  ];
  scene.sites = [
    {
      id: 'site-0',
      siteIndex: 0,
      label: 'C',
      fractional: [0, 0, 0],
      cartesian: [0, 0, 0],
      species: [
        {
          symbol: 'C',
          occupancy: 1,
          atomicNumber: 6,
          colorVesta: [76, 76, 76],
          colorJmol: [144, 144, 144],
          atomicRadius: 0.7,
        },
      ],
    },
  ];
  scene.atomInstances = Array.from({ length: count }, (_, index) => {
    const x = index % side;
    const y = Math.floor(index / side) % side;
    const z = Math.floor(index / side ** 2);
    return {
      id: `site-0@${x},${y},${z}`,
      siteId: 'site-0',
      siteIndex: 0,
      imageOffset: [x, y, z],
      position: [x * 1.7, y * 1.7, z * 1.7],
      visibility: 'repeat',
    } satisfies AtomInstanceSpec;
  });
  scene.bondRelations = [];
  scene.bondInstances = [];
  scene.polyhedra = [];
  scene.warnings = [];
  return scene;
};

export const createDebugMoleculeScene = (): MoleculeSceneSpec => {
  const moleculeSites: SiteSpec[] = [
    {
      id: 'site-0',
      siteIndex: 0,
      label: 'C',
      cartesian: [-0.67, 0, 0],
      species: [
        {
          symbol: 'C',
          occupancy: 1,
          atomicNumber: 6,
          colorVesta: [76, 76, 76],
          colorJmol: [144, 144, 144],
          atomicRadius: 0.7,
        },
      ],
    },
    {
      id: 'site-1',
      siteIndex: 1,
      label: 'C',
      cartesian: [0.67, 0, 0],
      species: [
        {
          symbol: 'C',
          occupancy: 1,
          atomicNumber: 6,
          colorVesta: [76, 76, 76],
          colorJmol: [144, 144, 144],
          atomicRadius: 0.7,
        },
      ],
    },
  ];
  const moleculeAtoms: AtomInstanceSpec[] = moleculeSites.map((site) => ({
    id: `${site.id}@0,0,0`,
    siteId: site.id,
    siteIndex: site.siteIndex,
    imageOffset: [0, 0, 0],
    position: site.cartesian,
    visibility: 'base',
  }));
  const relation: BondRelationSpec = {
    id: 'bond-relation-0',
    fromSiteIndex: 0,
    toSiteIndex: 1,
    relativeImage: [0, 0, 0],
    distance: 1.34,
    weight: 2,
    order: 2,
    origin: 'source',
  };
  const bond: BondInstanceSpec = {
    id: 'bond-0',
    relationId: relation.id,
    fromSiteIndex: 0,
    toSiteIndex: 1,
    fromImage: [0, 0, 0],
    toImage: [0, 0, 0],
    start: moleculeSites[0].cartesian,
    end: moleculeSites[1].cartesian,
    distance: 1.34,
    visibility: 'base',
    order: 2,
    origin: 'source',
  };
  return {
    schemaVersion: '2.0',
    kind: 'molecule',
    requestId: 'debug-molecule-1',
    molecule: {
      formula: 'C2',
      atomCount: 2,
      isOrdered: true,
      charge: 0,
      spinMultiplicity: 1,
      inputFormat: 'mol',
      frameIndex: 1,
      frameCount: 1,
    },
    sites: moleculeSites,
    atomInstances: moleculeAtoms,
    bondRelations: [relation],
    bondInstances: [bond],
    polyhedra: [],
    analysis: {
      algorithm: 'Source',
      parameters: {},
      source: 'matgenlab',
      sourceVersion: 'debug',
      elapsedMilliseconds: 0,
    },
    warnings: [],
  };
};
