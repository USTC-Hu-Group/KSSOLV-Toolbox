import { crc32, type VolumeSceneSpec } from '@kssolv/volume-scene';

export const shouldUseDebugVolume = (
  search: string,
  bridgeConnected: boolean,
): boolean =>
  !bridgeConnected &&
  new URLSearchParams(search).get('debugVolume') === '1';

export const createDebugVolume = (): { scene: VolumeSceneSpec; buffer: ArrayBuffer } => {
  const dimensions: [number, number, number] = [48, 48, 48];
  const values = new Float32Array(dimensions[0] * dimensions[1] * dimensions[2]);
  let offset = 0;
  for (let z = 0; z < dimensions[2]; z += 1) {
    for (let y = 0; y < dimensions[1]; y += 1) {
      for (let x = 0; x < dimensions[0]; x += 1) {
        const positive =
          ((x - 17) / 8) ** 2 + ((y - 23.5) / 11) ** 2 + ((z - 23.5) / 9) ** 2;
        const negative =
          ((x - 31) / 8) ** 2 + ((y - 23.5) / 11) ** 2 + ((z - 23.5) / 9) ** 2;
        values[offset] = Math.exp(-positive) - Math.exp(-negative);
        offset += 1;
      }
    }
  }
  const transferId = 'debug:density';
  const scene: VolumeSceneSpec = {
    schemaVersion: '1.0',
    kind: 'volume',
    requestId: 'debug',
    source: {
      format: 'cube',
      name: 'Analytic ellipsoid',
      normalization: 'analytic',
    },
    grid: {
      dimensionality: 3,
      dimensions,
      origin: [-4.7, -4.7, -4.7],
      voxelVectors: [
        [0.2, 0, 0],
        [0.05, 0.2, 0],
        [0, 0.03, 0.2],
      ],
      periodic: [false, false, false],
      indexOrder: 'x-fastest',
      sampling: 'point-inclusive',
    },
    channels: [
      {
        id: 'density',
        label: 'Analytic density',
        units: 'arbitrary',
        signed: true,
        minimum: -0.78,
        maximum: 0.78,
        mean: 0,
        standardDeviation: 0.14,
        integral: null,
        transport: {
          transferId,
          valueEncoding: 'float32-le',
          elementCount: values.length,
          byteLength: values.byteLength,
          crc32: crc32(new Uint8Array(values.buffer)),
        },
      },
    ],
    warnings: [],
    atomicOverlay: null,
    transport: { protocol: 'chunked-binary', chunkBytes: 4 * 1024 * 1024 },
  };
  return { scene, buffer: values.buffer };
};
