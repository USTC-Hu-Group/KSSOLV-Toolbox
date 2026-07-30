import {
  AmbientLight,
  Box3,
  ConeGeometry,
  CylinderGeometry,
  DirectionalLight,
  FrontSide,
  Group,
  Mesh,
  MeshBasicMaterial,
  NoToneMapping,
  OrthographicCamera,
  PMREMGenerator,
  Quaternion,
  Raycaster,
  Scene,
  Sphere,
  SphereGeometry,
  Vector2,
  Vector3,
  WebGLRenderer,
  type BufferGeometry,
  type Intersection,
  type Material,
  type Object3D,
  type Texture,
} from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { TrackballControls } from 'three/examples/jsm/controls/TrackballControls.js';

import type {
  CameraSnapshot,
  AtomHoverInfo,
  AtomicSceneSpec,
  RendererStatistics,
  SelectionInfo,
  ThemeId,
  Vector3Tuple,
  ViewerOptions,
} from '../scene/types';
import { themes } from '../themes/themes';
import {
  cameraAxisFrame,
  defaultCameraDirection,
  latticeAxisDirections,
  type CrystalCameraAxis,
} from './cameraAxis';
import { projectedFitHeight, vector, type FitSphere } from './geometry';
import {
  configureViewerInteraction,
  exceedsDragThreshold,
  viewerInteractionProfile,
} from './interaction';
import { AtomLayer } from './layers/AtomLayer';
import { BondLayer } from './layers/BondLayer';
import { CellLayer } from './layers/CellLayer';
import { MagmomLayer } from './layers/MagmomLayer';
import { PolyhedronLayer } from './layers/PolyhedronLayer';
import { exportPixelRatio, interactivePixelRatio, renderQualityProfile } from './quality';
import { viewportLayout } from './viewport';

export interface CrystalRendererCallbacks {
  onSelection?: (selection?: SelectionInfo) => void;
  onAtomHover?: (hover?: AtomHoverInfo) => void;
  onCameraSettled?: (snapshot: CameraSnapshot) => void;
  onStatistics?: (statistics: RendererStatistics) => void;
  onError?: (error: Error) => void;
}

interface BatchIntersection extends Intersection<Object3D> {
  batchId?: number;
}

const tuple = (value: Vector3): Vector3Tuple => [value.x, value.y, value.z];

interface AxisStyle {
  shaftLength: number;
  shaftRadius: number;
  headLength: number;
  headRadius: number;
}

const createAxisArrow = (
  direction: Vector3,
  color: number,
  style: AxisStyle,
  opacity: number,
): Group => {
  const axis = new Group();
  const unitDirection = direction.clone().normalize();
  const material = new MeshBasicMaterial({
    color,
    transparent: opacity < 1,
    opacity,
  });
  const shaft = new Mesh(
    new CylinderGeometry(style.shaftRadius, style.shaftRadius, style.shaftLength, 16),
    material,
  );
  const head = new Mesh(new ConeGeometry(style.headRadius, style.headLength, 18), material);
  shaft.position.set(0, style.shaftLength / 2, 0);
  head.position.set(0, style.shaftLength + style.headLength / 2, 0);
  axis.add(shaft, head);
  axis.quaternion.setFromUnitVectors(new Vector3(0, 1, 0), unitDirection);
  return axis;
};

const updateOrientationAxisDirections = (
  axes: Group,
  directions: [Vector3, Vector3, Vector3],
): void => {
  const localUp = new Vector3(0, 1, 0);
  directions.forEach((direction, index) => {
    axes.children[index]?.quaternion.setFromUnitVectors(localUp, direction);
  });
};

const createOrientationAxes = (theme: ThemeId): Group => {
  const axes = new Group();
  const materialsStyle = {
    shaftLength: 1.08,
    shaftRadius: 0.065,
    headLength: 0.3,
    headRadius: 0.17,
  };
  const prettyStyle = {
    shaftLength: 1.08,
    shaftRadius: 0.05,
    headLength: 0.3,
    headRadius: 0.15,
  };
  const style = theme === 'materials' ? materialsStyle : prettyStyle;
  const colors =
    theme === 'materials' ? [0xf01818, 0x00b82e, 0x143cff] : [0xff5c5c, 0x57cf72, 0x4d8cff];
  const opacity = theme === 'materials' ? 0.94 : 1;
  axes.add(
    createAxisArrow(new Vector3(1, 0, 0), colors[0], style, opacity),
    createAxisArrow(new Vector3(0, 1, 0), colors[1], style, opacity),
    createAxisArrow(new Vector3(0, 0, 1), colors[2], style, opacity),
  );
  if (theme === 'materials') {
    axes.add(
      new Mesh(
        new SphereGeometry(0.105, 24, 18),
        new MeshBasicMaterial({
          color: 0x4b4b4b,
          transparent: true,
          opacity,
        }),
      ),
    );
  }
  return axes;
};

export class CrystalRenderer {
  private readonly renderer: WebGLRenderer;
  private readonly scene = new Scene();
  private readonly crystal = new Group();
  private readonly ambientLight = new AmbientLight(0xffffff, 1.8);
  private readonly keyLight = new DirectionalLight(0xffffff, 3.4);
  private readonly fillLight = new DirectionalLight(0x9bbcff, 1.1);
  private readonly camera = new OrthographicCamera(-1, 1, 1, -1, 0.01, 10000);
  private readonly controls: TrackballControls;
  private readonly raycaster = new Raycaster();
  private readonly pointer = new Vector2();
  private readonly viewportSize = new Vector2();
  private readonly callbacks: CrystalRendererCallbacks;
  private readonly orientationScene = new Scene();
  // A fixed orthographic inset keeps every arrow head inside the scissor
  // rectangle at all camera rotations, including skewed crystal axes.
  private readonly orientationCamera = new OrthographicCamera(-1.55, 1.55, 1.55, -1.55, 0.1, 20);
  private readonly prettyAxes = createOrientationAxes('pretty');
  private readonly materialsAxes = createOrientationAxes('materials');
  private materialsEnvironment?: Texture;
  private readonly selectionMarker = new Mesh(
    new SphereGeometry(1, 24, 16),
    new MeshBasicMaterial({
      color: themes.pretty.selection,
      transparent: true,
      opacity: 0.25,
      depthWrite: false,
    }),
  );
  private readonly resizeObserver?: ResizeObserver;
  private sceneSpec?: AtomicSceneSpec;
  private options: ViewerOptions;
  private atomLayer?: AtomLayer;
  private bondLayer?: BondLayer;
  private cellLayer?: CellLayer;
  private polyhedronLayer?: PolyhedronLayer;
  private magmomLayer?: MagmomLayer;
  private requestedFrame?: number;
  private cameraTimer?: number;
  private hoverFrame?: number;
  private hoverPoint?: { clientX: number; clientY: number };
  private hoveredAtomId?: string;
  private viewHeight = 10;
  private disposed = false;
  private pointerStart?: { x: number; y: number };
  private pointerPrevious?: { x: number; y: number };
  private pointerTravel = 0;
  private mouseRotating = false;
  private suppressNextClick = false;
  private selected?: { kind: 'atom' | 'bond'; id: string; radius?: number };
  private readonly frameDurations: number[] = [];

  constructor(
    private readonly canvas: HTMLCanvasElement,
    options: ViewerOptions,
    callbacks: CrystalRendererCallbacks = {},
  ) {
    this.options = { ...options };
    this.callbacks = callbacks;
    this.renderer = new WebGLRenderer({
      canvas,
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
      preserveDrawingBuffer: true,
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = 'srgb';
    this.renderer.autoClear = false;
    this.renderer.info.autoReset = false;
    this.scene.add(this.crystal);
    this.scene.add(this.ambientLight);
    this.keyLight.position.set(7, 10, 12);
    this.scene.add(this.keyLight);
    this.fillLight.position.set(-8, -4, 6);
    this.scene.add(this.fillLight);
    this.selectionMarker.visible = false;
    this.selectionMarker.renderOrder = 20;
    this.scene.add(this.selectionMarker);

    this.orientationScene.add(this.prettyAxes, this.materialsAxes);
    this.orientationCamera.position.set(3, 3, 3);
    this.orientationCamera.lookAt(0, 0, 0);

    this.camera.position.set(8, 7, 9);
    this.camera.up.set(0, 0, 1);
    this.controls = new TrackballControls(this.camera, canvas);
    // Programmatic a/b/c views must remain exact after controls.update().
    // Trackball damping retains a private residual angle which can otherwise
    // rotate the camera again after an axis button has been clicked.
    configureViewerInteraction(this.controls);
    // TrackballControls deliberately does not keep a fixed camera-up vector:
    // unlike OrbitControls it can cross both poles and continue rotating
    // through a complete 360 degrees without clamping the polar angle.
    this.controls.addEventListener('change', this.handleControlsChange);
    this.controls.addEventListener('end', this.handleControlsEnd);
    canvas.addEventListener('pointerdown', this.handlePointerDown);
    canvas.addEventListener('pointermove', this.handlePointerMove);
    canvas.addEventListener('pointerup', this.handlePointerUp);
    canvas.addEventListener('pointercancel', this.handlePointerUp);
    canvas.addEventListener('pointerleave', this.handlePointerLeave);
    canvas.addEventListener('click', this.handleClick);
    canvas.addEventListener('webglcontextlost', this.handleContextLost);
    canvas.addEventListener('webglcontextrestored', this.handleContextRestored);

    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(canvas.parentElement ?? canvas);
    } else {
      window.addEventListener('resize', this.resize);
    }
    this.applyTheme(options.theme);
    this.resize();
  }

  setScene(scene: AtomicSceneSpec, preserveCamera = false): void {
    const snapshot = preserveCamera && this.sceneSpec ? this.cameraSnapshot() : undefined;
    this.clearHover();
    this.clearSelection();
    this.sceneSpec = scene;
    const orientationDirections = latticeAxisDirections(scene);
    updateOrientationAxisDirections(this.prettyAxes, orientationDirections);
    updateOrientationAxisDirections(this.materialsAxes, orientationDirections);
    this.clearLayers();
    const materialsEnvironment =
      this.options.theme === 'materials' && this.options.renderMode === 'quality'
        ? this.ensureMaterialsEnvironment()
        : undefined;
    this.atomLayer = new AtomLayer(
      scene,
      this.options,
      themes[this.options.theme],
      materialsEnvironment,
    );
    this.bondLayer = new BondLayer(scene, this.options, themes[this.options.theme]);
    this.cellLayer =
      scene.kind === 'crystal' ? new CellLayer(scene, themes[this.options.theme]) : undefined;
    this.polyhedronLayer = new PolyhedronLayer(scene, this.options, themes[this.options.theme]);
    this.magmomLayer = new MagmomLayer(scene, this.options);
    this.crystal.add(this.atomLayer.mesh, this.bondLayer.mesh);
    if (this.cellLayer) this.crystal.add(this.cellLayer.lines);
    if (this.polyhedronLayer.mesh) this.crystal.add(this.polyhedronLayer.mesh);
    if (this.magmomLayer.mesh) this.crystal.add(this.magmomLayer.mesh);
    if (snapshot) {
      this.restoreCamera(snapshot);
    } else {
      this.resetView();
    }
    this.reportStatistics();
    if (this.options.renderMode === 'quality') this.prewarmQualityRenderer();
  }

  setOptions(options: ViewerOptions): void {
    const themeChanged = options.theme !== this.options.theme;
    const renderQualityChanged =
      options.renderMode !== this.options.renderMode ||
      options.renderQuality !== this.options.renderQuality;
    const rebuild =
      themeChanged ||
      renderQualityChanged ||
      options.colorMode !== this.options.colorMode ||
      options.radiusMode !== this.options.radiusMode ||
      options.atomScale !== this.options.atomScale ||
      options.bondRadius !== this.options.bondRadius ||
      options.showBondOrders !== this.options.showBondOrders;
    this.options = { ...options };
    if (themeChanged || renderQualityChanged) {
      this.applyTheme(options.theme);
      if (options.theme !== 'materials') this.clearHover();
    }
    if (rebuild && this.sceneSpec) {
      this.setScene(this.sceneSpec, true);
      return;
    }
    this.atomLayer?.updateVisibility(this.options);
    this.bondLayer?.updateVisibility(this.options);
    this.cellLayer?.setVisible(this.options.showUnitCell);
    this.polyhedronLayer?.updateVisibility(this.options);
    this.magmomLayer?.setVisible(this.options.showMagmoms);
    this.reconcileSelection();
    this.requestRender();
  }

  resetView = (): void => {
    if (!this.sceneSpec) return;
    this.fitScene(defaultCameraDirection());
  };

  centerView = (): void => {
    if (!this.sceneSpec) return;
    const bounds = this.sceneBounds(this.sceneSpec);
    const center = bounds.getCenter(new Vector3());
    const offset = this.camera.position.clone().sub(this.controls.target);
    if (offset.lengthSq() < 1e-8) offset.set(1.15, 1, 0.85).setLength(3);
    const viewDirection = offset.clone().normalize();
    const preservedUp = this.camera.up.clone();
    const preservedOrientation = this.camera.quaternion.clone();

    // Space is a framing command, not a camera-reset command. Translate the
    // camera and target together, then change only the orthographic scale.
    // Keeping the exact up vector and quaternion prevents c-axis views (and
    // arbitrary user rotations) from acquiring a new pitch or roll.
    this.controls.target.copy(center);
    this.camera.position.copy(center).add(offset);
    this.viewHeight = projectedFitHeight(
      this.sceneFitSpheres(this.sceneSpec),
      center,
      viewDirection,
      preservedUp,
      this.aspect(),
    );
    this.camera.zoom = 1;
    this.updateFrustum();
    this.camera.up.copy(preservedUp);
    this.camera.quaternion.copy(preservedOrientation);
    this.camera.updateMatrixWorld();
    this.controls.update();
    this.camera.up.copy(preservedUp);
    this.camera.quaternion.copy(preservedOrientation);
    this.camera.updateMatrixWorld();
    this.requestRender();
  };

  private fitScene(direction: Vector3): void {
    if (!this.sceneSpec) return;
    const bounds = this.sceneBounds(this.sceneSpec);
    const center = bounds.getCenter(new Vector3());
    const sphere = bounds.getBoundingSphere(new Sphere());
    const distance = Math.max(sphere.radius * 3.5, 3);
    const viewDirection = direction.clone().normalize();
    this.camera.position.copy(center).addScaledVector(viewDirection, distance * 1.7);
    this.camera.up.set(0, 0, 1);
    if (Math.abs(viewDirection.dot(this.camera.up)) > 0.98) this.camera.up.set(0, 1, 0);
    this.controls.target.copy(center);
    this.viewHeight = projectedFitHeight(
      this.sceneFitSpheres(this.sceneSpec),
      center,
      viewDirection,
      this.camera.up,
      this.aspect(),
    );
    this.camera.zoom = 1;
    this.updateFrustum();
    this.camera.lookAt(center);
    this.camera.updateProjectionMatrix();
    this.controls.update();
    this.requestRender();
  }

  setCameraAxis(axis: CrystalCameraAxis): void {
    if (!this.sceneSpec) return;
    const { direction: viewDirection, up } = cameraAxisFrame(this.sceneSpec, axis);
    const distance = this.camera.position.distanceTo(this.controls.target);
    this.camera.position
      .copy(this.controls.target)
      .add(viewDirection.clone().multiplyScalar(distance));
    this.camera.up.copy(up);
    this.camera.lookAt(this.controls.target);
    this.controls.update();
    this.requestRender();
    this.emitCamera();
  }

  screenshot(): string {
    const quality = renderQualityProfile(this.options.renderMode, this.options.renderQuality);
    if (quality.exportScale === 1) {
      this.render();
      return this.canvas.toDataURL('image/png');
    }
    const size = this.renderer.getSize(new Vector2());
    const previousPixelRatio = this.renderer.getPixelRatio();
    const outputPixelRatio = exportPixelRatio(
      window.devicePixelRatio || 1,
      this.options.renderMode,
      this.options.renderQuality,
    );
    this.renderer.setPixelRatio(outputPixelRatio);
    this.renderer.setSize(size.x, size.y, false);
    this.updateFrustum();
    try {
      this.render();
      return this.canvas.toDataURL('image/png');
    } finally {
      this.renderer.setPixelRatio(previousPixelRatio);
      this.renderer.setSize(size.x, size.y, false);
      this.updateFrustum();
      this.requestRender();
    }
  }

  cameraSnapshot(): CameraSnapshot {
    return {
      position: tuple(this.camera.position),
      target: tuple(this.controls.target),
      up: tuple(this.camera.up),
      zoom: this.camera.zoom,
    };
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    if (this.requestedFrame !== undefined) cancelAnimationFrame(this.requestedFrame);
    if (this.hoverFrame !== undefined) cancelAnimationFrame(this.hoverFrame);
    if (this.cameraTimer !== undefined) window.clearTimeout(this.cameraTimer);
    this.resizeObserver?.disconnect();
    window.removeEventListener('resize', this.resize);
    this.canvas.removeEventListener('pointerdown', this.handlePointerDown);
    this.canvas.removeEventListener('pointermove', this.handlePointerMove);
    this.canvas.removeEventListener('pointerup', this.handlePointerUp);
    this.canvas.removeEventListener('pointercancel', this.handlePointerUp);
    this.canvas.removeEventListener('pointerleave', this.handlePointerLeave);
    this.canvas.removeEventListener('click', this.handleClick);
    this.canvas.removeEventListener('webglcontextlost', this.handleContextLost);
    this.canvas.removeEventListener('webglcontextrestored', this.handleContextRestored);
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    this.controls.removeEventListener('change', this.handleControlsChange);
    this.controls.removeEventListener('end', this.handleControlsEnd);
    this.controls.dispose();
    this.clearLayers();
    this.selectionMarker.geometry.dispose();
    (this.selectionMarker.material as MeshBasicMaterial).dispose();
    const orientationGeometries = new Set<BufferGeometry>();
    const orientationMaterials = new Set<Material>();
    this.orientationScene.traverse((object) => {
      if (!(object instanceof Mesh)) return;
      orientationGeometries.add(object.geometry);
      const materials = Array.isArray(object.material) ? object.material : [object.material];
      for (const material of materials) orientationMaterials.add(material);
    });
    for (const geometry of orientationGeometries) geometry.dispose();
    for (const material of orientationMaterials) material.dispose();
    this.materialsEnvironment?.dispose();
    this.renderer.dispose();
    this.renderer.forceContextLoss();
  }

  private applyTheme(themeId: ThemeId): void {
    const theme = themes[themeId];
    const devicePixelRatio = window.devicePixelRatio || 1;
    const pixelRatio = interactivePixelRatio(
      devicePixelRatio,
      this.options.renderMode,
      this.options.renderQuality,
    );
    this.renderer.setPixelRatio(pixelRatio);
    this.renderer.toneMapping = NoToneMapping;
    this.renderer.toneMappingExposure = 1;
    const physicalMaterials = this.options.renderMode === 'quality';
    this.ambientLight.intensity =
      themeId === 'materials' ? (physicalMaterials ? 0.82 : 0.92) : physicalMaterials ? 1.8 : 0.9;
    this.keyLight.intensity =
      themeId === 'materials' ? (physicalMaterials ? 1.05 : 0.68) : physicalMaterials ? 3.4 : 0.9;
    this.fillLight.intensity =
      themeId === 'materials' ? (physicalMaterials ? 0.3 : 0.26) : physicalMaterials ? 1.1 : 0.3;
    this.fillLight.color.set(themeId === 'materials' ? 0xffffff : 0x9bbcff);
    this.prettyAxes.visible = themeId === 'pretty';
    this.materialsAxes.visible = themeId === 'materials';
    this.renderer.setClearColor(this.options.background ?? theme.background, 1);
    const selectionMaterial = this.selectionMarker.material as MeshBasicMaterial;
    selectionMaterial.color.set(theme.selection);
    selectionMaterial.transparent = true;
    selectionMaterial.opacity = themeId === 'pretty' ? 0.25 : 0.16;
    selectionMaterial.depthWrite = false;
    selectionMaterial.side = FrontSide;
    selectionMaterial.needsUpdate = true;
    if (this.selected?.kind === 'atom' && this.selected.radius) {
      this.selectionMarker.scale.setScalar(
        this.selected.radius * (themeId === 'materials' ? 1.14 : 1.16),
      );
    }
    this.atomLayer?.updateTheme(theme);
    this.bondLayer?.updateTheme(theme);
    this.cellLayer?.updateTheme(theme);
    this.requestRender();
  }

  private readonly handleControlsChange = (): void => {
    this.requestRender();
    if (this.cameraTimer !== undefined) window.clearTimeout(this.cameraTimer);
    this.cameraTimer = window.setTimeout(() => this.emitCamera(), 120);
  };

  private readonly handleControlsEnd = (): void => {
    this.emitCamera();
    this.reportStatistics();
  };

  private readonly handlePointerDown = (event: PointerEvent): void => {
    this.pointerStart = { x: event.clientX, y: event.clientY };
    this.pointerPrevious = { x: event.clientX, y: event.clientY };
    this.pointerTravel = 0;
    this.suppressNextClick = false;
    this.canvas.dataset.interaction = event.button === 2 ? 'pan' : 'rotate';
    if (event.pointerType === 'mouse' && event.button === 0) {
      this.mouseRotating = true;
      // TrackballControls provides touch rotation and mouse pan/zoom. Mouse
      // rotation is handled below from relative deltas so Pointer Lock can
      // continue beyond the physical viewport edge.
      this.controls.noRotate = true;
      const lockRequest = this.canvas.requestPointerLock?.();
      if (lockRequest) {
        void lockRequest
          .catch(() => undefined)
          .then(() => {
            if (!this.mouseRotating && document.pointerLockElement === this.canvas) {
              document.exitPointerLock();
            }
          });
      }
    }
  };

  private readonly handlePointerMove = (event: PointerEvent): void => {
    if (event.buttons !== 0) {
      this.clearHover();
      if (this.mouseRotating && (event.buttons & 1) !== 0) {
        const previous = this.pointerPrevious ?? {
          x: event.clientX,
          y: event.clientY,
        };
        const pointerLocked = document.pointerLockElement === this.canvas;
        const deltaX = pointerLocked ? event.movementX : event.clientX - previous.x;
        const deltaY = pointerLocked ? event.movementY : event.clientY - previous.y;
        this.pointerPrevious = { x: event.clientX, y: event.clientY };
        if (deltaX !== 0 || deltaY !== 0) {
          this.pointerTravel += Math.hypot(deltaX, deltaY);
          this.rotateCameraByPointerDelta(deltaX, deltaY);
          if (this.pointerTravel >= viewerInteractionProfile.dragThresholdPixels) {
            this.suppressNextClick = true;
          }
        }
        return;
      }
      // TrackballControls normally runs inside a permanent animation loop.
      // This viewer renders on demand, so several pointer events can otherwise
      // overwrite _movePrev/_moveCurr before the next frame and make the first
      // long drag feel artificially capped. The control's document listener
      // receives the event after this canvas listener; a microtask therefore
      // commits every relative movement once propagation has completed, while
      // WebGL painting remains coalesced by requestRender().
      queueMicrotask(() => {
        if (!this.disposed) this.controls.update();
      });
      if (
        this.pointerStart &&
        exceedsDragThreshold(this.pointerStart.x, this.pointerStart.y, event.clientX, event.clientY)
      ) {
        this.suppressNextClick = true;
      }
      return;
    }
    if (this.options.theme !== 'materials') return;
    this.hoverPoint = { clientX: event.clientX, clientY: event.clientY };
    if (this.hoverFrame !== undefined) return;
    this.hoverFrame = requestAnimationFrame(() => {
      this.hoverFrame = undefined;
      const point = this.hoverPoint;
      if (point) this.updateHover(point.clientX, point.clientY);
    });
  };

  private readonly handlePointerLeave = (): void => {
    // Entering Pointer Lock fires pointerleave even though the left button is
    // still held. Keep the active rotation alive; pointerup performs cleanup
    // and releases the lock.
    if (this.mouseRotating) {
      this.clearHover();
      return;
    }
    this.handlePointerUp();
    this.clearHover();
  };

  private readonly handlePointerUp = (): void => {
    this.pointerStart = undefined;
    this.pointerPrevious = undefined;
    this.pointerTravel = 0;
    if (this.mouseRotating) {
      this.mouseRotating = false;
      this.controls.noRotate = false;
      if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    }
    delete this.canvas.dataset.interaction;
  };

  private rotateCameraByPointerDelta(deltaX: number, deltaY: number): void {
    const width = Math.max(this.canvas.clientWidth, 1);
    const horizontal = (2 * deltaX) / width;
    const vertical = (-2 * deltaY) / width;
    const angle = Math.hypot(horizontal, vertical) * viewerInteractionProfile.rotateSpeed;
    if (angle === 0) return;

    const eye = this.camera.position.clone().sub(this.controls.target);
    const eyeDirection = eye.clone().normalize();
    const upDirection = this.camera.up.clone().normalize().multiplyScalar(vertical);
    const sidewaysDirection = this.camera.up
      .clone()
      .normalize()
      .cross(eyeDirection)
      .normalize()
      .multiplyScalar(horizontal);
    const movement = upDirection.add(sidewaysDirection);
    const axis = movement.cross(eye).normalize();
    if (axis.lengthSq() === 0) return;
    const rotation = new Quaternion().setFromAxisAngle(axis, angle);
    eye.applyQuaternion(rotation);
    this.camera.up.applyQuaternion(rotation).normalize();
    this.camera.position.copy(this.controls.target).add(eye);
    this.camera.lookAt(this.controls.target);
    this.handleControlsChange();
  }

  private emitCamera(): void {
    this.callbacks.onCameraSettled?.(this.cameraSnapshot());
  }

  private clearSelection(notify = true): void {
    const hadSelection = this.selectionMarker.visible || this.selected !== undefined;
    this.selected = undefined;
    this.selectionMarker.visible = false;
    if (notify && hadSelection) this.callbacks.onSelection?.();
  }

  private clearHover(): void {
    this.hoverPoint = undefined;
    if (this.hoverFrame !== undefined) cancelAnimationFrame(this.hoverFrame);
    this.hoverFrame = undefined;
    if (this.hoveredAtomId === undefined) return;
    this.hoveredAtomId = undefined;
    this.callbacks.onAtomHover?.();
  }

  private updateHover(clientX: number, clientY: number): void {
    if (!this.atomLayer || this.options.theme !== 'materials') return;
    const bounds = this.canvas.getBoundingClientRect();
    this.pointer.set(
      ((clientX - bounds.left) / bounds.width) * 2 - 1,
      -((clientY - bounds.top) / bounds.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const hit = (
      this.raycaster.intersectObject(this.atomLayer.mesh, false) as BatchIntersection[]
    )[0];
    const hovered = hit?.batchId === undefined ? undefined : this.atomLayer.get(hit.batchId);
    if (!hovered) {
      this.clearHover();
      return;
    }
    this.hoveredAtomId = hovered.atom.id;
    this.callbacks.onAtomHover?.({
      atom: hovered.atom,
      site: hovered.site,
      clientX,
      clientY,
    });
  }

  private reconcileSelection(): void {
    if (!this.selected) return;
    const visible =
      this.selected.kind === 'atom'
        ? this.atomLayer?.isAtomVisible(this.selected.id)
        : this.bondLayer?.isBondVisible(this.selected.id);
    if (visible) return;
    this.clearSelection();
  }

  private readonly handleClick = (event: MouseEvent): void => {
    if (this.suppressNextClick) {
      this.suppressNextClick = false;
      return;
    }
    if (!this.atomLayer || !this.bondLayer || !this.sceneSpec) return;
    const bounds = this.canvas.getBoundingClientRect();
    this.pointer.set(
      ((event.clientX - bounds.left) / bounds.width) * 2 - 1,
      -((event.clientY - bounds.top) / bounds.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const hits = this.raycaster.intersectObjects(
      [this.atomLayer.mesh, this.bondLayer.mesh],
      false,
    ) as BatchIntersection[];
    const hit = hits[0];
    if (!hit || hit.batchId === undefined) {
      this.clearSelection();
      this.requestRender();
      return;
    }
    if (hit.object === this.atomLayer.mesh) {
      const selected = this.atomLayer.get(hit.batchId);
      if (!selected) return;
      this.selectionMarker.position.copy(vector(selected.atom.position));
      this.selectionMarker.scale.setScalar(
        selected.radius * (this.options.theme === 'materials' ? 1.14 : 1.16),
      );
      this.selectionMarker.visible = true;
      this.selected = { kind: 'atom', id: selected.atom.id, radius: selected.radius };
      this.callbacks.onSelection?.({
        kind: 'atom',
        id: selected.atom.id,
        atom: selected.atom,
        site: selected.site,
        clientX: event.clientX,
        clientY: event.clientY,
      });
    } else {
      const bond = this.bondLayer.get(hit.batchId);
      if (!bond) return;
      this.clearSelection(false);
      this.selected = { kind: 'bond', id: bond.id };
      this.callbacks.onSelection?.({
        kind: 'bond',
        id: bond.id,
        bond,
        clientX: event.clientX,
        clientY: event.clientY,
      });
    }
    this.requestRender();
  };

  private readonly handleContextLost = (event: Event): void => {
    event.preventDefault();
    this.callbacks.onError?.(new Error('The WebGL context was lost.'));
  };

  private readonly handleContextRestored = (): void => {
    this.materialsEnvironment?.dispose();
    this.materialsEnvironment = undefined;
    if (this.sceneSpec) this.setScene(this.sceneSpec, true);
  };

  private ensureMaterialsEnvironment(): Texture {
    if (this.materialsEnvironment) return this.materialsEnvironment;
    const roomEnvironment = new RoomEnvironment();
    const environmentGenerator = new PMREMGenerator(this.renderer);
    this.materialsEnvironment = environmentGenerator.fromScene(roomEnvironment, 0.04).texture;
    environmentGenerator.dispose();
    roomEnvironment.dispose();
    return this.materialsEnvironment;
  }

  private prewarmQualityRenderer(): void {
    void this.renderer.compileAsync(this.scene, this.camera).catch((error: unknown) => {
      this.callbacks.onError?.(
        error instanceof Error ? error : new Error('Unable to precompile high-quality shaders.'),
      );
    });
  }

  private requestRender(): void {
    if (this.disposed || this.requestedFrame !== undefined) return;
    this.requestedFrame = requestAnimationFrame(() => {
      this.requestedFrame = undefined;
      this.render();
    });
  }

  private render(): void {
    if (this.disposed) return;
    const startedAt = performance.now();
    // WebGLRenderer.setViewport/setScissor accept CSS-pixel dimensions and
    // apply pixelRatio internally. canvas.width/height are already multiplied
    // by devicePixelRatio; passing them here doubles the viewport on Retina
    // uihtml surfaces and leaves only one quadrant visible.
    const viewport = this.renderer.getSize(this.viewportSize);
    const layout = viewportLayout(viewport.x, viewport.y);
    this.renderer.info.reset();
    this.controls.update();
    this.renderer.setScissorTest(false);
    this.renderer.setViewport(0, 0, layout.main.width, layout.main.height);
    this.renderer.clear(true, true, true);
    this.renderer.render(this.scene, this.camera);
    if (this.options.showAxes) {
      const relative = this.camera.position.clone().sub(this.controls.target).normalize();
      this.orientationCamera.position.copy(relative.multiplyScalar(4.75));
      this.orientationCamera.up.copy(this.camera.up);
      this.orientationCamera.lookAt(0, 0, 0);
      this.renderer.clearDepth();
      this.renderer.setScissorTest(true);
      this.renderer.setScissor(layout.axes.x, layout.axes.y, layout.axes.size, layout.axes.size);
      this.renderer.setViewport(layout.axes.x, layout.axes.y, layout.axes.size, layout.axes.size);
      this.renderer.render(this.orientationScene, this.orientationCamera);
      this.renderer.setScissorTest(false);
    }
    this.frameDurations.push(performance.now() - startedAt);
    if (this.frameDurations.length > 120) this.frameDurations.shift();
  }

  private readonly resize = (): void => {
    const parent = this.canvas.parentElement;
    const width = Math.max(parent?.clientWidth ?? this.canvas.clientWidth, 1);
    const height = Math.max(parent?.clientHeight ?? this.canvas.clientHeight, 1);
    this.renderer.setSize(width, height, false);
    this.controls.handleResize();
    this.updateFrustum();
    this.requestRender();
  };

  private updateFrustum(): void {
    const aspect = this.aspect();
    this.camera.left = (-this.viewHeight * aspect) / 2;
    this.camera.right = (this.viewHeight * aspect) / 2;
    this.camera.top = this.viewHeight / 2;
    this.camera.bottom = -this.viewHeight / 2;
    this.camera.updateProjectionMatrix();
  }

  private aspect(): number {
    return Math.max(this.canvas.clientWidth, 1) / Math.max(this.canvas.clientHeight, 1);
  }

  private sceneBounds(scene: AtomicSceneSpec): Box3 {
    const bounds = new Box3();
    for (const atom of scene.atomInstances) bounds.expandByPoint(vector(atom.position));
    if (scene.kind === 'crystal') {
      const [a, b, c] = scene.structure.lattice.map((entry, index) =>
        vector(entry).multiplyScalar(scene.structure.repeat[index]),
      );
      for (const x of [0, 1]) {
        for (const y of [0, 1]) {
          for (const z of [0, 1]) {
            bounds.expandByPoint(
              new Vector3().addScaledVector(a, x).addScaledVector(b, y).addScaledVector(c, z),
            );
          }
        }
      }
    }
    if (bounds.isEmpty()) bounds.setFromCenterAndSize(new Vector3(), new Vector3(3, 3, 3));
    return bounds;
  }

  private sceneFitSpheres(scene: AtomicSceneSpec): FitSphere[] {
    const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
    const spheres: FitSphere[] = scene.atomInstances.map((atom) => {
      const site = sites.get(atom.siteIndex);
      const radius =
        this.options.radiusMode === 'uniform'
          ? 0.5 * this.options.atomScale
          : Math.max(
              0.5,
              ...(site?.species.map((component) => Math.max(component.atomicRadius, 0.35)) ?? []),
            ) * this.options.atomScale;
      return { center: vector(atom.position), radius };
    });
    if (scene.kind === 'crystal') {
      const [a, b, c] = scene.structure.lattice.map((entry, index) =>
        vector(entry).multiplyScalar(scene.structure.repeat[index]),
      );
      for (const x of [0, 1]) {
        for (const y of [0, 1]) {
          for (const z of [0, 1]) {
            spheres.push({
              center: new Vector3()
                .addScaledVector(a, x)
                .addScaledVector(b, y)
                .addScaledVector(c, z),
              radius: 0,
            });
          }
        }
      }
    }
    return spheres;
  }

  private restoreCamera(snapshot: CameraSnapshot): void {
    this.camera.position.set(...snapshot.position);
    this.camera.up.set(...snapshot.up);
    this.camera.zoom = snapshot.zoom;
    this.controls.target.set(...snapshot.target);
    this.camera.lookAt(this.controls.target);
    this.camera.updateProjectionMatrix();
    this.controls.update();
  }

  private clearLayers(): void {
    this.crystal.clear();
    this.atomLayer?.dispose();
    this.bondLayer?.dispose();
    this.cellLayer?.dispose();
    this.polyhedronLayer?.dispose();
    this.magmomLayer?.dispose();
    this.atomLayer = undefined;
    this.bondLayer = undefined;
    this.cellLayer = undefined;
    this.polyhedronLayer = undefined;
    this.magmomLayer = undefined;
  }

  private reportStatistics(): void {
    if (!this.sceneSpec) return;
    this.render();
    const orderedFrames = [...this.frameDurations].sort((a, b) => a - b);
    const p95Index = Math.max(Math.ceil(orderedFrames.length * 0.95) - 1, 0);
    this.callbacks.onStatistics?.({
      atoms: this.sceneSpec.atomInstances.length,
      bonds: this.sceneSpec.bondInstances.length,
      polyhedra: this.sceneSpec.polyhedra.length,
      drawCalls: this.renderer.info.render.calls,
      triangles: this.renderer.info.render.triangles,
      p95FrameMilliseconds: orderedFrames[p95Index] ?? 0,
    });
  }
}
