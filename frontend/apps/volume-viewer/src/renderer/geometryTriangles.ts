import { BufferGeometry, Matrix4, Vector3 } from 'three';

/**
 * Expand indexed or non-indexed geometry into non-indexed world-space
 * triangles. Scientific exporters use this single path so indexed smoothing
 * never drops faces or accidentally exports grid coordinates.
 */
export const geometryTriangles = (
  geometry: BufferGeometry,
  transform = new Matrix4(),
): Float32Array => {
  const position = geometry.getAttribute('position');
  if (!position || position.itemSize !== 3) {
    throw new Error('Export geometry must contain three-component positions.');
  }
  const indices = geometry.getIndex();
  const count = indices?.count ?? position.count;
  if (count % 3 !== 0) {
    throw new Error('Export geometry must contain complete triangles.');
  }
  const output = new Float32Array(count * 3);
  const vertex = new Vector3();
  for (let index = 0; index < count; index += 1) {
    const vertexIndex = indices ? indices.getX(index) : index;
    vertex.fromBufferAttribute(position, vertexIndex).applyMatrix4(transform);
    output.set([vertex.x, vertex.y, vertex.z], index * 3);
  }
  return output;
};
