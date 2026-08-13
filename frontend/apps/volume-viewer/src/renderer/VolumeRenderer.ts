import {
  AmbientLight,
  DirectionalLight,
  Fog,
  Group,
  OrthographicCamera,
  Quaternion,
  Raycaster,
  Scene,
  Sphere,
  Vector2,
  Vector3,
  WebGLRenderer,
} from 'three';
import { TrackballControls } from 'three/addons/controls/TrackballControls.js';

import {
  cameraAxisFrameFromVectors,
  configureViewerInteraction,
  defaultCameraDirection,
  fitOrthographicCamera,
  viewerInteractionProfile,
} from '@kssolv/three-scene';
import type { CrystalCameraAxis } from '@kssolv/three-scene';
import type { VolumeChannelSpec, VolumeSceneSpec } from '@kssolv/volume-scene';
import type { SelectionInfo } from '@kssolv/atomic-scene';

import type { VolumeOptions } from '../state/volumeStore';
import { appearanceScale, volumeViewerThemes } from '../themes';
import { AtomicOverlayLayer } from './AtomicOverlayLayer';
import {
  decodeValues,
  gridBounds,
  sampleTrilinear,
  worldToGrid,
} from './gridMath';
import { VolumeLayer } from './VolumeLayer';
import { OrientationAxes } from './OrientationAxes';
import {
  encodeCanvasImage,
  flipRgbaRows,
  rgbaToTiffBlob,
  type ImageExportFormat,
} from './imageExport';
import { encodeGlb, encodeGltf, encodePly, encodeStl } from './meshExport';
import type {
  IsosurfaceExportFormat,
  VolumeProbe,
  VolumeRendererApi,
  VolumeRendererDiagnostics,
} from './VolumeRendererApi';
import {
  encodeSliceCsv,
  encodeSlicePng,
  extractMillerSlice,
} from './sliceExport';

export class VolumeRenderer implements VolumeRendererApi {
  readonly backend = 'webgl2' as const;
  private readonly renderer: WebGLRenderer;
  private readonly scene = new Scene();
  private readonly camera = new OrthographicCamera(-5, 5, 5, -5, 0.01, 5000);
  private readonly controls: TrackballControls;
  private readonly root = new Group();
  private readonly ambientLight = new AmbientLight(0xffffff, 1.35);
  private readonly keyLight = new DirectionalLight(0xffffff, 2.1);
  private readonly fillLight = new DirectionalLight(0xbfd8ff, 1.1);
  private readonly orientationScene = new Scene();
  private readonly orientationCamera = new OrthographicCamera(-1.35, 1.35, 1.35, -1.35, 0.01, 20);
  private readonly raycaster = new Raycaster();
  private readonly pointer = new Vector2();
  private readonly resizeObserver: ResizeObserver;
  private animationFrame = 0;
  private sceneSpec?: VolumeSceneSpec;
  private channel?: VolumeChannelSpec;
  private sourceBuffer?: ArrayBuffer;
  private values?: Float32Array | Float64Array;
  private volumeLayer?: VolumeLayer;
  private atomicLayer?: AtomicOverlayLayer;
  private orientationAxes?: OrientationAxes;
  private options?: VolumeOptions;
  private contextLost = false;
  private contextLossExtension?: WEBGL_lose_context;
  private pointerPrevious?: { x: number; y: number };
  private mouseRotating = false;
  private pointerTravel = 0;
  private suppressNextClick = false;
  private autoRotating = false;
  private autoRotationTimestamp?: number;

  constructor(
    private readonly container: HTMLElement,
    private readonly onProbe: (probe?: VolumeProbe) => void,
    private readonly onStatus: (
      phase: 'ready' | 'building' | 'error',
      message: string,
    ) => void = () => undefined,
    private readonly onSelection: (selection?: SelectionInfo) => void = () => undefined,
  ) {
    this.renderer = new WebGLRenderer({
      antialias: true,
      alpha: false,
      preserveDrawingBuffer: true,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setClearColor(0xffffff, 1);
    this.renderer.outputColorSpace = 'srgb';
    this.renderer.info.autoReset = false;
    this.container.append(this.renderer.domElement);
    this.scene.add(this.root);
    this.scene.add(this.ambientLight);
    this.keyLight.position.set(8, 10, 12);
    this.scene.add(this.keyLight);
    this.fillLight.position.set(-10, -4, 6);
    this.scene.add(this.fillLight);
    this.orientationScene.add(new AmbientLight(0xffffff, 1.45));
    const orientationLight = new DirectionalLight(0xffffff, 1.2);
    orientationLight.position.set(2, 3, 5);
    this.orientationScene.add(orientationLight);
    this.camera.position.copy(defaultCameraDirection().multiplyScalar(18));
    this.camera.lookAt(0, 0, 0);
    this.controls = new TrackballControls(this.camera, this.renderer.domElement);
    this.controls.addEventListener('change', this.handleControlsChange);
    configureViewerInteraction(this.controls, {
      zoomSpeed: 2.2,
      panSpeed: 1.4,
    });
    this.renderer.domElement.addEventListener('pointerdown', this.handlePointerDown);
    this.renderer.domElement.addEventListener('pointermove', this.handlePointerMove);
    this.renderer.domElement.addEventListener('pointerup', this.handlePointerUp);
    this.renderer.domElement.addEventListener('pointercancel', this.handlePointerUp);
    this.renderer.domElement.addEventListener('pointerleave', this.handlePointerLeave);
    this.renderer.domElement.addEventListener('dblclick', this.handleProbe);
    this.renderer.domElement.addEventListener('click', this.handleClick);
    this.renderer.domElement.addEventListener('webglcontextlost', this.handleContextLost);
    this.renderer.domElement.addEventListener('webglcontextrestored', this.handleContextRestored);
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(this.container);
    this.resize();
    this.animate();
  }

  setScene(
    scene: VolumeSceneSpec,
    channel: VolumeChannelSpec,
    buffer: ArrayBuffer,
    options: VolumeOptions,
    preserveCamera = false,
  ): void {
    this.sceneSpec = scene;
    this.onSelection(undefined);
    this.channel = channel;
    this.sourceBuffer = buffer;
    this.values = decodeValues(
      buffer,
      channel.transport.valueEncoding,
      channel.transport.scale,
      channel.transport.offset,
    );
    this.options = { ...options };
    this.applyAppearance(options);
    this.volumeLayer?.dispose();
    this.atomicLayer?.dispose();
    if (this.orientationAxes) {
      this.orientationScene.remove(this.orientationAxes);
      this.orientationAxes.dispose();
    }
    this.root.clear();
    const effectiveOptions = this.effectiveOptions(options, scene);
    this.volumeLayer = new VolumeLayer(
      scene.grid,
      channel,
      this.values,
      effectiveOptions,
      this.onStatus,
    );
    this.root.add(this.volumeLayer);
    if (scene.atomicOverlay) {
      this.atomicLayer = new AtomicOverlayLayer(scene.atomicOverlay, options);
      this.atomicLayer.setVisibility(effectiveOptions);
      this.root.add(this.atomicLayer);
    }
    this.orientationAxes = new OrientationAxes(scene.grid);
    this.orientationScene.add(this.orientationAxes);
    if (!preserveCamera) this.resetView();
  }

  setOptions(options: VolumeOptions): void {
    if (!this.sceneSpec || !this.channel || !this.values) return;
    const rebuildVolume =
      !this.options ||
      options.mode !== this.options.mode ||
      options.positiveThreshold !== this.options.positiveThreshold ||
      options.negativeThreshold !== this.options.negativeThreshold ||
      options.showPositive !== this.options.showPositive ||
      options.showNegative !== this.options.showNegative ||
      options.smoothIsosurface !== this.options.smoothIsosurface ||
      options.periodicWrap !== this.options.periodicWrap ||
      options.millerIndices.some(
        (index, axis) => index !== this.options!.millerIndices[axis],
      ) ||
      options.interpolation !== this.options.interpolation ||
      options.colormap !== this.options.colormap;
    const rebuildAtomicOverlay =
      !this.options ||
      options.theme !== this.options.theme ||
      options.colorMode !== this.options.colorMode ||
      options.radiusMode !== this.options.radiusMode ||
      options.atomScale !== this.options.atomScale ||
      options.bondRadius !== this.options.bondRadius ||
      options.metalness !== this.options.metalness ||
      options.roughness !== this.options.roughness;
    this.options = { ...options };
    this.applyAppearance(options);
    if (rebuildVolume) {
      this.volumeLayer?.rebuild(this.effectiveOptions(options, this.sceneSpec));
    } else {
      this.volumeLayer?.updateAppearance(
        this.effectiveOptions(options, this.sceneSpec),
      );
    }
    if (rebuildAtomicOverlay && this.sceneSpec.atomicOverlay) {
      if (this.atomicLayer) {
        this.root.remove(this.atomicLayer);
        this.atomicLayer.dispose();
      }
      this.atomicLayer = new AtomicOverlayLayer(
        this.sceneSpec.atomicOverlay,
        options,
      );
      this.root.add(this.atomicLayer);
    }
    this.atomicLayer?.setVisibility(options);
    if (this.orientationAxes) this.orientationAxes.visible = options.showAxes;
    this.updateDepthCueing();
  }

  centerView(): void {
    if (!this.sceneSpec) return;
    fitOrthographicCamera(this.camera, this.controls.target, this.sceneBounds(), 1.08);
    this.controls.update();
  }

  resetView(): void {
    if (!this.sceneSpec) return;
    const bounds = this.sceneBounds();
    const center = bounds.getCenter(new Vector3());
    const radius = Math.max(bounds.getSize(new Vector3()).length(), 1);
    this.controls.target.copy(center);
    this.camera.up.set(0, 0, 1);
    this.camera.position.copy(center).add(defaultCameraDirection().multiplyScalar(radius * 1.8));
    this.camera.lookAt(center);
    this.centerView();
    this.updateDepthCueing();
  }

  setCameraAxis(axis: CrystalCameraAxis): void {
    if (!this.sceneSpec) return;
    const { direction, up } = cameraAxisFrameFromVectors(
      this.sceneSpec.grid.voxelVectors,
      axis,
    );
    const distance = Math.max(
      this.camera.position.distanceTo(this.controls.target),
      1,
    );
    this.camera.position
      .copy(this.controls.target)
      .addScaledVector(direction, distance);
    this.camera.up.copy(up);
    this.camera.lookAt(this.controls.target);
    this.camera.updateProjectionMatrix();
    this.controls.update();
    this.updateDepthCueing();
  }

  setAutoRotation(enabled: boolean): void {
    if (enabled === this.autoRotating) return;
    this.autoRotating = enabled;
    this.autoRotationTimestamp = undefined;
  }

  private sceneBounds() {
    const bounds = gridBounds(this.sceneSpec!.grid);
    if (this.atomicLayer) bounds.union(this.atomicLayer.getBounds());
    return bounds;
  }

  private applyAppearance(options: VolumeOptions): void {
    const theme = volumeViewerThemes[options.theme];
    this.renderer.setClearColor(theme.background, 1);
    this.ambientLight.intensity = 1.35 * appearanceScale(options.ambientLight);
    this.keyLight.intensity = 2.1 * appearanceScale(options.directionalLight);
    this.fillLight.intensity = 1.1 * appearanceScale(options.directionalLight);
    this.renderer.domElement.style.filter = `brightness(${appearanceScale(options.brightness)}) contrast(${appearanceScale(options.contrast)})`;
    this.updateDepthCueing();
  }

  screenshot(scale = 1.5): string {
    const original = this.renderer.getSize(new Vector2());
    const originalPixelRatio = this.renderer.getPixelRatio();
    try {
      this.renderer.setPixelRatio(1);
      this.renderer.setSize(original.x * scale, original.y * scale, false);
      this.renderer.render(this.scene, this.camera);
      return this.renderer.domElement.toDataURL('image/png');
    } finally {
      this.renderer.setPixelRatio(originalPixelRatio);
      this.renderer.setSize(original.x, original.y, false);
      if (!this.contextLost) this.renderer.render(this.scene, this.camera);
    }
  }

  async exportImage(format: ImageExportFormat, scale = 1.5): Promise<Blob> {
    const original = this.renderer.getSize(new Vector2());
    const originalPixelRatio = this.renderer.getPixelRatio();
    try {
      this.renderer.setPixelRatio(1);
      this.renderer.setSize(original.x * scale, original.y * scale, false);
      this.renderer.render(this.scene, this.camera);
      if (format === 'tiff') {
        const width = this.renderer.domElement.width;
        const height = this.renderer.domElement.height;
        const rgba = new Uint8Array(width * height * 4);
        const context = this.renderer.getContext();
        context.readPixels(
          0,
          0,
          width,
          height,
          context.RGBA,
          context.UNSIGNED_BYTE,
          rgba,
        );
        return rgbaToTiffBlob(flipRgbaRows(rgba, width, height), width, height);
      }
      return await encodeCanvasImage(this.renderer.domElement, format);
    } finally {
      this.renderer.setPixelRatio(originalPixelRatio);
      this.renderer.setSize(original.x, original.y, false);
      if (!this.contextLost) this.renderer.render(this.scene, this.camera);
    }
  }

  async exportIsosurface(
    format: IsosurfaceExportFormat,
  ): Promise<{ data: ArrayBuffer | string; mime: string }> {
    const positions = this.volumeLayer?.getSurfaceTriangles();
    if (!positions?.length) {
      throw new Error('The isosurface is still building or contains no triangles.');
    }
    if (format === 'ply') {
      return { data: encodePly(positions), mime: 'application/octet-stream' };
    }
    if (format === 'stl') {
      return { data: encodeStl(positions), mime: 'model/stl' };
    }
    if (format === 'gltf') {
      return { data: await encodeGltf(positions), mime: 'model/gltf+json' };
    }
    return { data: await encodeGlb(positions), mime: 'model/gltf-binary' };
  }

  exportSliceCsv(): string {
    if (!this.sceneSpec || !this.values || !this.options) {
      throw new Error('No volume slice is available.');
    }
    return encodeSliceCsv(
      extractMillerSlice(
        this.values,
        this.sceneSpec.grid,
        this.options.millerIndices,
        this.options.interpolation,
      ),
    );
  }

  exportSlicePng(): string {
    if (!this.sceneSpec || !this.values || !this.options) {
      throw new Error('No volume slice is available.');
    }
    return encodeSlicePng(
      extractMillerSlice(
        this.values,
        this.sceneSpec.grid,
        this.options.millerIndices,
        this.options.interpolation,
      ),
      this.options.rangeMinimum,
      this.options.rangeMaximum,
      this.options.colormap,
      this.options.pngScale,
    );
  }

  orbitForAcceptance(deltaRadians: number): void {
    const relative = this.camera.position.clone().sub(this.controls.target);
    relative.applyAxisAngle(this.camera.up, deltaRadians);
    this.camera.position.copy(this.controls.target).add(relative);
    this.camera.lookAt(this.controls.target);
    this.controls.update();
  }

  /**
   * Production-build recovery seam used only by the opt-in acceptance page.
   * It invokes the browser's real context-loss extension instead of faking
   * renderer state.
   */
  loseContextForAcceptance(): boolean {
    const extension = this.renderer
      .getContext()
      .getExtension('WEBGL_lose_context');
    if (!extension) return false;
    this.contextLossExtension = extension;
    extension.loseContext();
    return true;
  }

  restoreContextForAcceptance(): boolean {
    if (!this.contextLossExtension) return false;
    this.contextLossExtension.restoreContext();
    return true;
  }

  diagnostics(): VolumeRendererDiagnostics {
    return {
      contextLost: this.contextLost,
      geometries: this.renderer.info.memory.geometries,
      textures: this.renderer.info.memory.textures,
      programs: this.renderer.info.programs?.length ?? 0,
      drawCalls: this.renderer.info.render.calls,
      triangles: this.renderer.info.render.triangles,
    };
  }

  dispose(): void {
    cancelAnimationFrame(this.animationFrame);
    this.resizeObserver.disconnect();
    this.renderer.domElement.removeEventListener('dblclick', this.handleProbe);
    this.renderer.domElement.removeEventListener('click', this.handleClick);
    this.renderer.domElement.removeEventListener('pointerdown', this.handlePointerDown);
    this.renderer.domElement.removeEventListener('pointermove', this.handlePointerMove);
    this.renderer.domElement.removeEventListener('pointerup', this.handlePointerUp);
    this.renderer.domElement.removeEventListener('pointercancel', this.handlePointerUp);
    this.renderer.domElement.removeEventListener('pointerleave', this.handlePointerLeave);
    this.renderer.domElement.removeEventListener('webglcontextlost', this.handleContextLost);
    this.renderer.domElement.removeEventListener('webglcontextrestored', this.handleContextRestored);
    this.controls.removeEventListener('change', this.handleControlsChange);
    this.controls.dispose();
    this.volumeLayer?.dispose();
    this.atomicLayer?.dispose();
    this.orientationAxes?.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
    if (document.pointerLockElement === this.renderer.domElement) {
      document.exitPointerLock();
    }
    this.sourceBuffer = undefined;
    this.values = undefined;
    this.contextLossExtension = undefined;
  }

  private readonly handleProbe = (event: MouseEvent): void => {
    if (!this.sceneSpec || !this.volumeLayer || !this.values) return;
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const hit = this.raycaster.intersectObject(this.volumeLayer.probeMesh, false)[0];
    if (!hit) {
      this.onProbe(undefined);
      return;
    }
    const grid = worldToGrid(this.sceneSpec.grid, hit.point);
    this.onProbe({
      world: hit.point.toArray(),
      grid: grid.toArray(),
      value: sampleTrilinear(this.values, this.sceneSpec.grid.dimensions, grid),
    });
  };

  private readonly handlePointerDown = (event: PointerEvent): void => {
    this.pointerPrevious = { x: event.clientX, y: event.clientY };
    this.pointerTravel = 0;
    this.suppressNextClick = false;
    this.renderer.domElement.dataset.interaction =
      event.button === 2 ? 'pan' : 'rotate';
    if (event.pointerType !== 'mouse' || event.button !== 0) return;
    this.mouseRotating = true;
    // Match the crystal viewer: TrackballControls keeps touch rotation and
    // right-button pan, while mouse rotation uses unbounded relative deltas.
    this.controls.noRotate = true;
    const lockRequest = this.renderer.domElement.requestPointerLock?.();
    if (lockRequest) {
      void lockRequest
        .catch(() => undefined)
        .then(() => {
          if (
            !this.mouseRotating &&
            document.pointerLockElement === this.renderer.domElement
          ) {
            document.exitPointerLock();
          }
        });
    }
  };

  private readonly handlePointerMove = (event: PointerEvent): void => {
    if (event.buttons === 0) return;
    const previous = this.pointerPrevious ?? { x: event.clientX, y: event.clientY };
    this.pointerTravel += Math.hypot(
      event.movementX || event.clientX - previous.x,
      event.movementY || event.clientY - previous.y,
    );
    if (this.pointerTravel > 4) this.suppressNextClick = true;
    if (this.mouseRotating && (event.buttons & 1) !== 0) {
      const pointerLocked =
        document.pointerLockElement === this.renderer.domElement;
      const deltaX = pointerLocked
        ? event.movementX
        : event.clientX - previous.x;
      const deltaY = pointerLocked
        ? event.movementY
        : event.clientY - previous.y;
      this.pointerPrevious = { x: event.clientX, y: event.clientY };
      if (deltaX !== 0 || deltaY !== 0) {
        this.rotateCameraByPointerDelta(deltaX, deltaY);
      }
      return;
    }
    // Commit every right-button pan movement instead of allowing a burst of
    // pointer events to collapse into one Trackball update.
    queueMicrotask(() => {
      if (!this.contextLost) this.controls.update();
    });
  };

  private readonly handlePointerLeave = (): void => {
    // Pointer Lock emits pointerleave while the left button is still held.
    if (this.mouseRotating) return;
    this.handlePointerUp();
  };

  private readonly handlePointerUp = (): void => {
    this.pointerPrevious = undefined;
    if (this.mouseRotating) {
      this.mouseRotating = false;
      this.controls.noRotate = false;
      if (document.pointerLockElement === this.renderer.domElement) {
        document.exitPointerLock();
      }
    }
    delete this.renderer.domElement.dataset.interaction;
  };

  private readonly handleClick = (event: MouseEvent): void => {
    if (this.suppressNextClick) {
      this.suppressNextClick = false;
      return;
    }
    if (!this.atomicLayer) {
      this.onSelection(undefined);
      return;
    }
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const hit = this.raycaster.intersectObjects(
      this.atomicLayer.pickableObjects(),
      false,
    )[0];
    const selected = hit
      ? this.atomicLayer.selectionForObject(hit.object)
      : undefined;
    this.onSelection(
      selected
        ? { ...selected, clientX: event.clientX, clientY: event.clientY }
        : undefined,
    );
  };

  private rotateCameraByPointerDelta(deltaX: number, deltaY: number): void {
    const width = Math.max(this.renderer.domElement.clientWidth, 1);
    const horizontal = (2 * deltaX) / width;
    const vertical = (-2 * deltaY) / width;
    const angle =
      Math.hypot(horizontal, vertical) *
      viewerInteractionProfile.rotateSpeed;
    if (angle === 0) return;

    const eye = this.camera.position.clone().sub(this.controls.target);
    const eyeDirection = eye.clone().normalize();
    const movement = this.camera.up
      .clone()
      .normalize()
      .multiplyScalar(vertical)
      .add(
        this.camera.up
          .clone()
          .normalize()
          .cross(eyeDirection)
          .normalize()
          .multiplyScalar(horizontal),
      );
    const axis = movement.cross(eye).normalize();
    if (axis.lengthSq() === 0) return;
    const rotation = new Quaternion().setFromAxisAngle(axis, angle);
    eye.applyQuaternion(rotation);
    this.camera.up.applyQuaternion(rotation).normalize();
    this.camera.position.copy(this.controls.target).add(eye);
    this.camera.lookAt(this.controls.target);
    this.updateDepthCueing();
  }

  private readonly handleControlsChange = (): void => {
    this.updateDepthCueing();
  };

  private updateDepthCueing(): void {
    if (!this.options?.depthCueing || !this.sceneSpec) {
      this.scene.fog = null;
      return;
    }
    const sphere = this.sceneBounds().getBoundingSphere(new Sphere());
    const cameraDirection = this.camera.getWorldDirection(new Vector3());
    const centerDepth = sphere.center
      .clone()
      .sub(this.camera.position)
      .dot(cameraDirection);
    const radius = Math.max(Number.isFinite(sphere.radius) ? sphere.radius : 0, 0.5);
    const safeCenter = Math.max(Number.isFinite(centerDepth) ? centerDepth : 0, radius);
    const near = Math.max(safeCenter - radius, 0);
    const far = Math.max(safeCenter + radius * 1.5, near + radius);
    const color = volumeViewerThemes[this.options.theme].background;
    if (this.scene.fog instanceof Fog) {
      this.scene.fog.color.set(color);
      this.scene.fog.near = near;
      this.scene.fog.far = far;
    } else {
      this.scene.fog = new Fog(color, near, far);
    }
  }

  private readonly handleContextLost = (event: Event): void => {
    event.preventDefault();
    this.contextLost = true;
    this.onStatus('error', 'WebGL context lost. Waiting for GPU recovery…');
  };

  private readonly handleContextRestored = (): void => {
    this.contextLost = false;
    if (
      !this.sceneSpec ||
      !this.channel ||
      !this.sourceBuffer ||
      !this.options
    ) {
      return;
    }
    this.onStatus('building', 'GPU restored. Rebuilding volume layers…');
    this.setScene(
      this.sceneSpec,
      this.channel,
      this.sourceBuffer,
      this.options,
      true,
    );
    this.onStatus('ready', 'GPU volume layers restored');
  };

  private effectiveOptions(options: VolumeOptions, scene: VolumeSceneSpec): VolumeOptions {
    if (options.mode !== 'volume') return options;
    if (scene.grid.dimensionality === 2) {
      this.onStatus('ready', 'Two-dimensional XSF grids use lattice-aligned slices.');
      return {
        ...options,
        mode: 'slices',
        millerIndices: [0, 0, 1],
      };
    }
    const gl = this.renderer.getContext() as WebGL2RenderingContext;
    const max3DTextureSize = gl.getParameter(gl.MAX_3D_TEXTURE_SIZE) as number;
    const requested = Math.max(...scene.grid.dimensions);
    if (!max3DTextureSize || requested > max3DTextureSize) {
      this.onStatus(
        'error',
        `Direct volume needs a ${requested}³ texture, but this GPU supports ${max3DTextureSize || 0}; showing a K slice instead.`,
      );
      return {
        ...options,
        mode: 'slices',
        millerIndices: [0, 0, 1],
      };
    }
    if (
      options.interpolation === 'linear' &&
      !this.renderer.extensions.has('OES_texture_float_linear')
    ) {
      this.onStatus(
        'ready',
        'Float-linear volume filtering is unavailable; using nearest-neighbor GPU sampling.',
      );
      return { ...options, interpolation: 'nearest' };
    }
    return options;
  }

  private resize(): void {
    const width = Math.max(1, this.container.clientWidth);
    const height = Math.max(1, this.container.clientHeight);
    const aspect = width / height;
    const extent = 5;
    this.camera.left = -extent * aspect;
    this.camera.right = extent * aspect;
    this.camera.top = extent;
    this.camera.bottom = -extent;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
    this.controls.handleResize();
  }

  private animate(timestamp = performance.now()): void {
    this.animationFrame = requestAnimationFrame((nextTimestamp) =>
      this.animate(nextTimestamp),
    );
    if (this.contextLost) return;
    this.renderer.info.reset();
    this.updateAutoRotation(timestamp);
    this.controls.update();
    this.renderer.setViewport(0, 0, this.container.clientWidth, this.container.clientHeight);
    this.renderer.setScissorTest(false);
    this.renderer.render(this.scene, this.camera);
    if (this.orientationAxes?.visible) {
      const size = Math.min(126, Math.max(86, this.container.clientWidth * 0.11));
      const offset = 15;
      const relative = this.camera.position.clone().sub(this.controls.target).normalize();
      this.orientationCamera.position.copy(relative.multiplyScalar(5));
      this.orientationCamera.up.copy(this.camera.up);
      this.orientationCamera.lookAt(0, 0, 0);
      this.renderer.clearDepth();
      this.renderer.setViewport(offset, offset, size, size);
      this.renderer.setScissor(offset, offset, size, size);
      this.renderer.setScissorTest(true);
      this.renderer.render(this.orientationScene, this.orientationCamera);
      this.renderer.setScissorTest(false);
    }
  }

  private updateAutoRotation(timestamp: number): void {
    if (!this.autoRotating || !this.sceneSpec) return;
    if (this.autoRotationTimestamp === undefined) {
      this.autoRotationTimestamp = timestamp;
      return;
    }
    const elapsedSeconds = Math.min(
      Math.max(timestamp - this.autoRotationTimestamp, 0) / 1000,
      0.1,
    );
    this.autoRotationTimestamp = timestamp;
    if (elapsedSeconds === 0) return;
    const eye = this.camera.position.clone().sub(this.controls.target);
    const axis = this.camera.up.clone().normalize();
    if (eye.lengthSq() === 0 || axis.lengthSq() === 0) return;
    eye.applyQuaternion(
      new Quaternion().setFromAxisAngle(axis, elapsedSeconds * -0.45),
    );
    this.camera.position.copy(this.controls.target).add(eye);
    this.camera.lookAt(this.controls.target);
    this.updateDepthCueing();
  }
}
