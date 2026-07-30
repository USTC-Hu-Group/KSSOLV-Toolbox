import {
  BufferGeometry,
  Float32BufferAttribute,
  Mesh,
  MeshStandardMaterial,
} from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';

const triangleNormal = (
  positions: Float32Array,
  offset: number,
): [number, number, number] => {
  const ax = positions[offset];
  const ay = positions[offset + 1];
  const az = positions[offset + 2];
  const ux = positions[offset + 3] - ax;
  const uy = positions[offset + 4] - ay;
  const uz = positions[offset + 5] - az;
  const vx = positions[offset + 6] - ax;
  const vy = positions[offset + 7] - ay;
  const vz = positions[offset + 8] - az;
  const nx = uy * vz - uz * vy;
  const ny = uz * vx - ux * vz;
  const nz = ux * vy - uy * vx;
  const length = Math.hypot(nx, ny, nz) || 1;
  return [nx / length, ny / length, nz / length];
};

export const encodePly = (positions: Float32Array): string => {
  const vertices = positions.length / 3;
  const triangles = positions.length / 9;
  const lines = [
    'ply',
    'format ascii 1.0',
    'comment KSSOLV Toolbox volume isosurface',
    `element vertex ${vertices}`,
    'property float x',
    'property float y',
    'property float z',
    `element face ${triangles}`,
    'property list uchar int vertex_indices',
    'end_header',
  ];
  for (let offset = 0; offset < positions.length; offset += 3) {
    lines.push(`${positions[offset]} ${positions[offset + 1]} ${positions[offset + 2]}`);
  }
  for (let triangle = 0; triangle < triangles; triangle += 1) {
    const first = triangle * 3;
    lines.push(`3 ${first} ${first + 1} ${first + 2}`);
  }
  return `${lines.join('\n')}\n`;
};

export const encodeStl = (positions: Float32Array, name = 'isosurface'): string => {
  const lines = [`solid ${name}`];
  for (let offset = 0; offset < positions.length; offset += 9) {
    const normal = triangleNormal(positions, offset);
    lines.push(`  facet normal ${normal.join(' ')}`, '    outer loop');
    for (let vertex = 0; vertex < 3; vertex += 1) {
      const index = offset + vertex * 3;
      lines.push(
        `      vertex ${positions[index]} ${positions[index + 1]} ${positions[index + 2]}`,
      );
    }
    lines.push('    endloop', '  endfacet');
  }
  lines.push(`endsolid ${name}`);
  return `${lines.join('\n')}\n`;
};

const withExportMesh = async <T>(
  positions: Float32Array,
  operation: (mesh: Mesh) => Promise<T>,
): Promise<T> => {
  const geometry = new BufferGeometry();
  geometry.setAttribute('position', new Float32BufferAttribute(positions, 3));
  geometry.computeVertexNormals();
  const material = new MeshStandardMaterial({
    color: 0x43bada,
    roughness: 0.3,
    metalness: 0,
  });
  const mesh = new Mesh(geometry, material);
  mesh.name = 'KSSOLV volume isosurface';
  try {
    return await operation(mesh);
  } finally {
    geometry.dispose();
    material.dispose();
  }
};

export const encodeGlb = async (positions: Float32Array): Promise<ArrayBuffer> =>
  withExportMesh(positions, async (mesh) => {
    const result = await new GLTFExporter().parseAsync(mesh, {
      binary: true,
      onlyVisible: true,
    });
    if (!(result instanceof ArrayBuffer)) {
      throw new Error('GLTFExporter did not produce a binary GLB payload.');
    }
    return result;
  });

export const encodeGltf = async (positions: Float32Array): Promise<string> =>
  withExportMesh(positions, async (mesh) => {
    const result = await new GLTFExporter().parseAsync(mesh, {
      binary: false,
      onlyVisible: true,
    });
    if (result instanceof ArrayBuffer) {
      throw new Error('GLTFExporter did not produce a JSON glTF payload.');
    }
    return JSON.stringify(result, null, 2);
  });
