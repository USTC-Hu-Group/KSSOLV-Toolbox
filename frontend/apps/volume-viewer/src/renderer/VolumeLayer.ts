import {
  BoxGeometry,
  BufferGeometry,
  ClampToEdgeWrapping,
  Data3DTexture,
  DataTexture,
  DoubleSide,
  FloatType,
  Float32BufferAttribute,
  Group,
  LinearFilter,
  Material,
  Matrix4,
  Mesh,
  MeshPhongMaterial,
  NearestFilter,
  RedFormat,
  RGBAFormat,
  ShaderMaterial,
  Texture,
  Vector2,
} from 'three';
import { mergeVertices } from 'three/addons/utils/BufferGeometryUtils.js';

import type { VolumeChannelSpec, VolumeGridSpec } from '@kssolv/volume-scene';

import type { VolumeOptions } from '../state/volumeStore';
import {
  createDirectVolumeMaterial,
  updateDirectVolumeMaterial,
} from './directVolumeMaterial';
import { gridMatrix } from './gridMath';
import { geometryTriangles } from './geometryTriangles';

const colorTexture = (
  start: [number, number, number],
  end: [number, number, number],
  opacity: number | ((fraction: number) => number) = 1,
): DataTexture => {
  const bytes = new Uint8Array(256 * 4);
  for (let index = 0; index < 256; index += 1) {
    const fraction = index / 255;
    for (let component = 0; component < 3; component += 1) {
      bytes[index * 4 + component] = Math.round(
        start[component] * (1 - fraction) + end[component] * fraction,
      );
    }
    const alpha = typeof opacity === 'function' ? opacity(fraction) : opacity;
    bytes[index * 4 + 3] = Math.round(Math.min(1, Math.max(0, alpha)) * 255);
  }
  const texture = new DataTexture(bytes, 256, 1, RGBAFormat);
  texture.needsUpdate = true;
  return texture;
};

const paletteTexture = (
  palette: VolumeOptions['colormap'],
  opacity: number | ((fraction: number) => number) = 1,
): DataTexture => {
  const palettes = {
    viridis: [
      [68, 1, 84],
      [33, 145, 140],
      [253, 231, 37],
    ],
    coolwarm: [
      [59, 76, 192],
      [245, 245, 245],
      [180, 4, 38],
    ],
    density: [
      [4, 12, 35],
      [52, 130, 164],
      [255, 224, 54],
    ],
  } satisfies Record<VolumeOptions['colormap'], number[][]>;
  const stops = palettes[palette];
  const bytes = new Uint8Array(256 * 4);
  for (let index = 0; index < 256; index += 1) {
    const fraction = index / 255;
    const scaled = fraction * (stops.length - 1);
    const lower = Math.min(stops.length - 2, Math.floor(scaled));
    const local = scaled - lower;
    for (let component = 0; component < 3; component += 1) {
      bytes[index * 4 + component] = Math.round(
        stops[lower][component] * (1 - local) + stops[lower + 1][component] * local,
      );
    }
    const alpha = typeof opacity === 'function' ? opacity(fraction) : opacity;
    bytes[index * 4 + 3] = Math.round(Math.min(1, Math.max(0, alpha)) * 255);
  }
  const texture = new DataTexture(bytes, 256, 1, RGBAFormat);
  texture.needsUpdate = true;
  return texture;
};

const createTexture = (
  values: Float32Array,
  grid: VolumeGridSpec,
  interpolation: VolumeOptions['interpolation'],
): Data3DTexture => {
  const texture = new Data3DTexture(values, ...grid.dimensions);
  texture.format = RedFormat;
  texture.type = FloatType;
  texture.minFilter = interpolation === 'nearest' ? NearestFilter : LinearFilter;
  texture.magFilter = texture.minFilter;
  texture.wrapS = ClampToEdgeWrapping;
  texture.wrapT = ClampToEdgeWrapping;
  texture.wrapR = ClampToEdgeWrapping;
  texture.unpackAlignment = 1;
  texture.needsUpdate = true;
  return texture;
};

const sliceGeometry = (
  grid: VolumeGridSpec,
  axis: VolumeOptions['sliceAxis'],
  index: number,
): BufferGeometry => {
  const [nx, ny, nz] = grid.dimensions;
  const maximum = axis === 'i' ? nx - 1 : axis === 'j' ? ny - 1 : nz - 1;
  const coordinate = Math.min(maximum, Math.max(0, index));
  let vertices: number[];
  if (axis === 'i') {
    vertices = [
      coordinate, 0, 0, coordinate, ny - 1, 0, coordinate, ny - 1, nz - 1,
      coordinate, 0, 0, coordinate, ny - 1, nz - 1, coordinate, 0, nz - 1,
    ];
  } else if (axis === 'j') {
    vertices = [
      0, coordinate, 0, nx - 1, coordinate, 0, nx - 1, coordinate, nz - 1,
      0, coordinate, 0, nx - 1, coordinate, nz - 1, 0, coordinate, nz - 1,
    ];
  } else {
    vertices = [
      0, 0, coordinate, nx - 1, 0, coordinate, nx - 1, ny - 1, coordinate,
      0, 0, coordinate, nx - 1, ny - 1, coordinate, 0, ny - 1, coordinate,
    ];
  }
  const geometry = new BufferGeometry();
  geometry.setAttribute('position', new Float32BufferAttribute(vertices, 3));
  geometry.setAttribute(
    'uv',
    new Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1], 2),
  );
  geometry.computeVertexNormals();
  return geometry;
};

const createSliceTexture = (
  values: Float32Array,
  grid: VolumeGridSpec,
  axis: VolumeOptions['sliceAxis'],
  requestedIndex: number,
  interpolation: VolumeOptions['interpolation'],
): DataTexture => {
  const [nx, ny, nz] = grid.dimensions;
  const maximum = axis === 'i' ? nx - 1 : axis === 'j' ? ny - 1 : nz - 1;
  const selected = Math.min(maximum, Math.max(0, Math.round(requestedIndex)));
  const width = axis === 'i' ? ny : nx;
  const height = axis === 'k' ? ny : nz;
  const output = new Float32Array(width * height);
  const sourceIndex = (x: number, y: number, z: number) => x + nx * (y + ny * z);
  let offset = 0;
  for (let row = 0; row < height; row += 1) {
    for (let column = 0; column < width; column += 1) {
      const x = axis === 'i' ? selected : column;
      const y = axis === 'i' ? column : axis === 'j' ? selected : row;
      const z = axis === 'k' ? selected : row;
      output[offset] = values[sourceIndex(x, y, z)];
      offset += 1;
    }
  }
  const texture = new DataTexture(output, width, height, RedFormat, FloatType);
  texture.minFilter = interpolation === 'nearest' ? NearestFilter : LinearFilter;
  texture.magFilter = texture.minFilter;
  texture.wrapS = ClampToEdgeWrapping;
  texture.wrapT = ClampToEdgeWrapping;
  texture.unpackAlignment = 1;
  texture.needsUpdate = true;
  return texture;
};

const sliceMaterial = (
  texture: DataTexture,
  colormap: DataTexture,
  range: [number, number],
): ShaderMaterial =>
  new ShaderMaterial({
    transparent: true,
    side: 2,
    uniforms: {
      u_data: { value: texture },
      u_range: { value: new Vector2(...range) },
      u_colormap: { value: colormap },
    },
    vertexShader: `
      varying vec2 v_tex;
      void main() {
        v_tex = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      precision highp float;
      uniform sampler2D u_data;
      uniform sampler2D u_colormap;
      uniform vec2 u_range;
      varying vec2 v_tex;
      void main() {
        float value = texture(u_data, v_tex).r;
        float normalized = clamp((value-u_range.x)/max(u_range.y-u_range.x, 1e-12), 0.0, 1.0);
        gl_FragColor = texture2D(u_colormap, vec2(normalized, 0.5));
      }
    `,
  });

export class VolumeLayer extends Group {
  readonly probeMesh: Mesh;
  private readonly textures: Texture[] = [];
  private readonly colorMaps: DataTexture[] = [];
  private readonly materials: Material[] = [];
  private readonly geometries: BufferGeometry[] = [];
  private readonly surfaceMeshes: Mesh[] = [];
  private readonly surfaceCache = new Map<
    string,
    { positions: Float32Array; truncated: boolean }
  >();
  private surfaceCacheBytes = 0;
  private values: Float32Array;
  private worker?: Worker;
  private workerTimeout?: number;
  private rebuildGeneration = 0;
  constructor(
    private readonly grid: VolumeGridSpec,
    private readonly channel: VolumeChannelSpec,
    input: Float32Array | Float64Array,
    options: VolumeOptions,
    private readonly onStatus: (
      phase: 'ready' | 'building' | 'error',
      message: string,
    ) => void = () => undefined,
  ) {
    super();
    this.matrixAutoUpdate = false;
    this.matrix.copy(gridMatrix(grid));
    this.values = input instanceof Float32Array ? input : Float32Array.from(input);
    const box = new BoxGeometry(...grid.dimensions);
    box.translate(
      (grid.dimensions[0] - 1) / 2,
      (grid.dimensions[1] - 1) / 2,
      (grid.dimensions[2] - 1) / 2,
    );
    this.geometries.push(box);
    this.probeMesh = new Mesh(
      box,
      new ShaderMaterial({
        transparent: true,
        opacity: 0,
        depthWrite: false,
        colorWrite: false,
      }),
    );
    this.probeMesh.name = 'volume-probe';
    this.add(this.probeMesh);
    this.rebuild(options);
  }

  rebuild(options: VolumeOptions): void {
    const generation = ++this.rebuildGeneration;
    this.worker?.terminate();
    this.worker = undefined;
    if (this.workerTimeout !== undefined) window.clearTimeout(this.workerTimeout);
    this.workerTimeout = undefined;
    this.surfaceMeshes.length = 0;
    for (const child of [...this.children]) {
      if (child !== this.probeMesh) this.remove(child);
    }
    for (const material of this.materials.splice(0)) material.dispose();
    for (const texture of this.textures.splice(0)) texture.dispose();
    for (const map of this.colorMaps.splice(0)) map.dispose();
    for (const geometry of this.geometries.splice(1)) geometry.dispose();

    const positiveMap = colorTexture([20, 60, 140], [60, 210, 255], options.opacity);
    const negativeMap = colorTexture([255, 210, 70], [225, 45, 30], options.opacity);
    const fullMap = paletteTexture(options.colormap);
    this.colorMaps.push(positiveMap, negativeMap, fullMap);
    if (options.mode === 'slices') {
      const texture = createSliceTexture(
        this.values,
        this.grid,
        options.sliceAxis,
        options.sliceIndex,
        options.interpolation,
      );
      const geometry = sliceGeometry(this.grid, options.sliceAxis, options.sliceIndex);
      const material = sliceMaterial(texture, fullMap, [
        options.rangeMinimum,
        options.rangeMaximum,
      ]);
      this.textures.push(texture);
      this.geometries.push(geometry);
      this.materials.push(material);
      this.add(new Mesh(geometry, material));
      this.onStatus('ready', 'Slice ready');
      return;
    }

    if (options.mode === 'volume') {
      const texture = createTexture(this.values, this.grid, options.interpolation);
      this.textures.push(texture);
      const material = createDirectVolumeMaterial(
        texture,
        fullMap,
        this.grid,
        options,
      );
      this.materials.push(material);
      this.add(new Mesh(this.geometries[0], material));
      this.onStatus('ready', 'GPU direct volume ready');
      return;
    }

    const requests: Array<{ threshold: number; color: number }> = [];
    if (options.showPositive) {
      requests.push({ threshold: options.positiveThreshold, color: 0x36c8f0 });
    }
    if (options.showNegative && this.channel.minimum < 0) {
      requests.push({ threshold: options.negativeThreshold, color: 0xe33d2e });
    }
    this.onStatus('building', 'Building isosurface…');
    this.buildIsosurfaces(
      requests,
      options.opacity,
      generation,
      options.smoothIsosurface,
      options.periodicWrap && this.grid.sampling === 'cell-periodic',
    );
  }

  updateAppearance(options: VolumeOptions): void {
    for (const material of this.materials) {
      if (material instanceof MeshPhongMaterial) {
        material.opacity = options.opacity;
        material.transparent = options.opacity < 1;
        material.needsUpdate = true;
      } else if (material instanceof ShaderMaterial) {
        updateDirectVolumeMaterial(material, options);
        if (material.name !== 'kssolv-direct-volume' && material.uniforms.u_range) {
          material.uniforms.u_range.value.set(
            options.rangeMinimum,
            options.rangeMaximum,
          );
        }
      }
    }
  }

  /**
   * Return non-indexed triangles in world coordinates for scientific mesh export.
   */
  getSurfaceTriangles(): Float32Array {
    const transform = new Matrix4().copy(this.matrix);
    const parts = this.surfaceMeshes.map((mesh) =>
      geometryTriangles(mesh.geometry, transform),
    );
    const length = parts.reduce((sum, part) => sum + part.length, 0);
    const output = new Float32Array(length);
    let offset = 0;
    for (const part of parts) {
      output.set(part, offset);
      offset += part.length;
    }
    return output;
  }

  private buildIsosurfaces(
    requests: Array<{ threshold: number; color: number }>,
    opacity: number,
    generation: number,
    smoothing: boolean,
    periodicWrap: boolean,
  ): void {
    if (requests.length === 0) {
      this.onStatus('ready', 'No isosurface is enabled');
      return;
    }
    const jobs: Array<{ id: number; threshold: number; color: number; cacheKey: string }> = [];
    requests.forEach((request, id) => {
      const cacheKey = `${request.threshold.toPrecision(12)}:${periodicWrap ? 'wrap' : 'open'}`;
      const cached = this.surfaceCache.get(cacheKey);
      if (cached) {
        this.surfaceCache.delete(cacheKey);
        this.surfaceCache.set(cacheKey, cached);
        this.addSurfaceMesh(
          cached.positions,
          request.color,
          opacity,
          cached.truncated,
          smoothing,
        );
      } else {
        jobs.push({ ...request, id, cacheKey });
      }
    });
    if (jobs.length === 0) {
      this.onStatus('ready', 'Isosurface restored from cache');
      return;
    }
    const worker = new Worker(new URL('./isosurface.worker.ts', import.meta.url), {
      type: 'module',
    });
    this.worker = worker;
    this.workerTimeout = window.setTimeout(() => {
      if (worker !== this.worker) return;
      worker.terminate();
      this.worker = undefined;
      this.workerTimeout = undefined;
      this.onStatus('error', 'Isosurface extraction exceeded the 20 s safety limit.');
    }, 20_000);
    let completed = 0;
    let failed = false;
    let truncated = false;
    worker.onmessage = (
      event: MessageEvent<{
        id: number;
        positions?: ArrayBuffer;
        error?: string;
        truncated?: boolean;
      }>,
    ): void => {
      if (generation !== this.rebuildGeneration || worker !== this.worker) return;
      completed += 1;
      if (event.data.error) {
        failed = true;
        this.onStatus('error', event.data.error);
      }
      if (event.data.positions) {
        truncated ||= Boolean(event.data.truncated);
        const positions = new Float32Array(event.data.positions);
        const job = jobs.find(({ id }) => id === event.data.id);
        if (job) {
          this.rememberSurface(job.cacheKey, positions, Boolean(event.data.truncated));
          this.addSurfaceMesh(
            positions,
            job.color,
            opacity,
            Boolean(event.data.truncated),
            smoothing,
          );
        }
      }
      if (completed === jobs.length) {
        worker.terminate();
        if (this.worker === worker) this.worker = undefined;
        if (this.workerTimeout !== undefined) window.clearTimeout(this.workerTimeout);
        this.workerTimeout = undefined;
        if (!failed) {
          this.onStatus(
            'ready',
            truncated
              ? 'Isosurface reached the 4,000,000-triangle safety limit.'
              : '',
          );
        }
      }
    };
    worker.onerror = (event): void => {
      worker.terminate();
      if (this.worker === worker) this.worker = undefined;
      if (this.workerTimeout !== undefined) window.clearTimeout(this.workerTimeout);
      this.workerTimeout = undefined;
      this.onStatus('error', event.message || 'Isosurface worker failed.');
    };
    jobs.forEach((request) => {
      const values = this.values.slice();
      worker.postMessage(
        {
          id: request.id,
          dimensions: this.grid.dimensions,
          threshold: request.threshold,
          periodic: periodicWrap ? this.grid.periodic : [false, false, false],
          values: values.buffer,
        },
        [values.buffer],
      );
    });
  }

  private addSurfaceMesh(
    positions: Float32Array,
    color: number,
    opacity: number,
    truncated: boolean,
    smoothing: boolean,
  ): void {
    const rawGeometry = new BufferGeometry();
    rawGeometry.setAttribute('position', new Float32BufferAttribute(positions, 3));
    const geometry = smoothing ? mergeVertices(rawGeometry, 1e-5) : rawGeometry;
    if (smoothing) rawGeometry.dispose();
    geometry.computeVertexNormals();
    const material = new MeshPhongMaterial({
      color,
      emissive: color,
      emissiveIntensity: 0.08,
      shininess: 95,
      specular: 0xffffff,
      transparent: opacity < 1,
      opacity,
      side: DoubleSide,
      // Keep depth writes enabled for a closed scientific surface. Disabling
      // them makes front/back tetrahedra blend in draw order and produces
      // a misleading stippled appearance.
      depthWrite: true,
    });
    const mesh = new Mesh(geometry, material);
    mesh.name = truncated ? 'isosurface-truncated' : 'isosurface';
    this.geometries.push(geometry);
    this.materials.push(material);
    this.surfaceMeshes.push(mesh);
    this.add(mesh);
  }

  private rememberSurface(
    key: string,
    positions: Float32Array,
    truncated: boolean,
  ): void {
    const existing = this.surfaceCache.get(key);
    if (existing) this.surfaceCacheBytes -= existing.positions.byteLength;
    this.surfaceCache.delete(key);
    this.surfaceCache.set(key, { positions, truncated });
    this.surfaceCacheBytes += positions.byteLength;
    while (this.surfaceCache.size > 6 || this.surfaceCacheBytes > 128 * 1024 * 1024) {
      const oldestKey = this.surfaceCache.keys().next().value as string | undefined;
      if (!oldestKey) break;
      const oldest = this.surfaceCache.get(oldestKey);
      if (oldest) this.surfaceCacheBytes -= oldest.positions.byteLength;
      this.surfaceCache.delete(oldestKey);
    }
  }

  dispose(): void {
    this.rebuildGeneration += 1;
    this.worker?.terminate();
    this.worker = undefined;
    if (this.workerTimeout !== undefined) window.clearTimeout(this.workerTimeout);
    this.workerTimeout = undefined;
    this.surfaceCache.clear();
    this.surfaceCacheBytes = 0;
    for (const material of this.materials) material.dispose();
    for (const texture of this.textures) texture.dispose();
    for (const map of this.colorMaps) map.dispose();
    for (const geometry of this.geometries) geometry.dispose();
    (this.probeMesh.material as ShaderMaterial).dispose();
    this.clear();
  }
}
