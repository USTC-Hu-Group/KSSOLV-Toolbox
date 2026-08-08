import {
  Box3,
  CircleGeometry,
  Color,
  CylinderGeometry,
  FrontSide,
  Mesh,
  MeshPhysicalMaterial,
  RectAreaLight,
  Scene,
  SphereGeometry,
  Vector3,
  type BufferGeometry,
  type Material,
  type OrthographicCamera,
  type WebGLRenderer,
} from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { DenoiseMaterial, GradientEquirectTexture, WebGLPathTracer } from 'three-gpu-pathtracer';

import type { AtomicSceneSpec, SpeciesComponent, ViewerOptions } from '../scene/types';
import type { ViewerTheme } from '../themes/themes';
import { appearanceScale, scaledMetalness, scaledRoughness } from './appearance';
import { cinematicPalette, elementMaterialProfile } from './artDirection';
import { isAtomVisible, isHydrogenSite } from './atomVisibility';
import { gleamoeGalaxyShader } from './GleamoeBackdrop';
import { color, cylinderMatrix, vector } from './geometry';
import { renderQualityProfile } from './quality';
import {
  pathTraceProgress,
  regionalSubmissionBatchSize,
  type PathTraceProgress,
} from './renderProgress';

const MAX_TRACE_ATOMS = 2_000;
const MAX_TRACE_BONDS = 6_000;

const sphereSegmentGeometry = (
  widthSegments: number,
  heightSegments: number,
  phiStart: number,
  phiLength: number,
): BufferGeometry => {
  const sphere = new SphereGeometry(
    1,
    widthSegments,
    heightSegments,
    phiStart,
    Math.max(phiLength, 0.001),
  );
  if (phiLength >= Math.PI * 2 - 1e-6) return sphere;
  const startCap = new CircleGeometry(1, heightSegments, -Math.PI / 2, Math.PI);
  startCap.rotateX(Math.PI / 2);
  startCap.rotateZ(phiStart);
  const endCap = startCap.clone();
  endCap.rotateZ(phiLength);
  const merged = mergeGeometries([sphere, startCap, endCap], false);
  sphere.dispose();
  startCap.dispose();
  endCap.dispose();
  return merged ?? new SphereGeometry(1, widthSegments, heightSegments);
};

const componentRadius = (component: SpeciesComponent | null, options: ViewerOptions): number => {
  if (options.radiusMode === 'uniform' || !component) return 0.5 * options.atomScale;
  return Math.max(component.atomicRadius, 0.35) * options.atomScale;
};

const componentColor = (component: SpeciesComponent | null, options: ViewerOptions): Color =>
  component
    ? color(options.colorMode === 'vesta' ? component.colorVesta : component.colorJmol)
    : new Color(0.68, 0.74, 0.82);

const bondOffsets = (
  start: AtomicSceneSpec['bondInstances'][number]['start'],
  end: AtomicSceneSpec['bondInstances'][number]['end'],
  lanes: number,
  radius: number,
): Vector3[] => {
  if (lanes === 1) return [new Vector3()];
  const direction = vector(end).sub(vector(start)).normalize();
  const candidates = [new Vector3(1, 0, 0), new Vector3(0, 1, 0), new Vector3(0, 0, 1)];
  candidates.sort(
    (first, second) => Math.abs(direction.dot(first)) - Math.abs(direction.dot(second)),
  );
  const perpendicular = new Vector3().crossVectors(direction, candidates[0]).normalize();
  const spacing = Math.max(radius * 2.6, 0.08);
  const positions = lanes === 2 ? [-0.5, 0.5] : [-1, 0, 1];
  return positions.map((position) => perpendicular.clone().multiplyScalar(position * spacing));
};

/**
 * Progressive GPU path tracing backend for the Gleamoe Noir theme.
 *
 * The interactive renderer uses BatchedMesh, which the path tracer cannot flatten reliably.
 * This class therefore builds a visually equivalent static scene while preserving the original
 * scene for picking, measurement, unit-cell lines, and fast interaction feedback.
 */
export class GleamoePathTracer {
  private readonly tracer: WebGLPathTracer;
  private readonly denoiseMaterial = new DenoiseMaterial({
    sigma: 1.25,
    kSigma: 1,
    threshold: 0.5,
  });
  private environment?: GradientEquirectTexture;
  private readonly geometries = new Set<BufferGeometry>();
  private readonly materials = new Set<Material>();
  private readonly lightCenter = new Vector3();
  private lightRadius = 1;
  private keyLight?: RectAreaLight;
  private rimLight?: RectAreaLight;
  private baseTargetSamples = 0;
  private baseRenderScale = 0.9;
  private targetSamples = 0;
  private ready = false;
  private suspended = false;

  constructor(
    renderer: WebGLRenderer,
    private readonly camera: OrthographicCamera,
    rasterizePreview?: () => void,
  ) {
    this.tracer = new WebGLPathTracer(renderer);
    this.tracer.rasterizeScene = true;
    this.tracer.dynamicLowRes = false;
    this.tracer.renderDelay = 80;
    this.tracer.fadeDuration = 280;
    this.tracer.minSamples = 16;
    this.tracer.filterGlossyFactor = 0.35;
    this.tracer.multipleImportanceSampling = true;
    this.tracer.tiles.set(1, 1);
    if (rasterizePreview) {
      this.tracer.rasterizeSceneCallback = () => rasterizePreview();
    }
    this.installCinematicGrade();
    this.tracer.renderToCanvasCallback = (target, activeRenderer, quad) => {
      const previousMaterial = quad.material;
      const previousAutoClear = activeRenderer.autoClear;
      this.denoiseMaterial.map = target.texture;
      this.denoiseMaterial.opacity = quad.material.opacity;
      this.denoiseMaterial.transparent = quad.material.opacity < 1;
      this.denoiseMaterial.blending = quad.material.blending;
      quad.material = this.denoiseMaterial;
      activeRenderer.autoClear = false;
      quad.render(activeRenderer);
      activeRenderer.autoClear = previousAutoClear;
      quad.material = previousMaterial;
    };
  }

  rebuild(sceneSpec: AtomicSceneSpec, options: ViewerOptions, theme: ViewerTheme): boolean {
    this.disposeScene();
    if (
      sceneSpec.atomInstances.length > MAX_TRACE_ATOMS ||
      sceneSpec.bondInstances.length > MAX_TRACE_BONDS
    ) {
      return false;
    }

    const profile = renderQualityProfile(options.renderMode, options.renderQuality);
    // The path tracer's material atlas remains 2K; the procedural studio environment is smooth
    // enough at 1K and avoiding a 64 MB float texture keeps theme switching responsive.
    const environmentResolution = Math.min(profile.textureSize, 1024);
    const scene = new Scene();
    scene.background = new Color(theme.background).lerp(new Color(0x132448), 0.24);
    scene.backgroundIntensity = 0.9;
    scene.environmentIntensity = 0.82 * appearanceScale(options.ambientLight);

    let environment = this.environment;
    if (!environment || environment.image.width !== environmentResolution) {
      environment?.dispose();
      environment = new GradientEquirectTexture(environmentResolution);
      environment.topColor.set(0xa8d9ff).multiplyScalar(1.35);
      environment.bottomColor.set(0x0b1830);
      environment.exponent = 1.7;
      environment.update();
      this.environment = environment;
    }
    scene.environment = environment;

    const bounds = new Box3();
    const sites = new Map(sceneSpec.sites.map((site) => [site.siteIndex, site]));
    const atomMaterials = new Map<string, MeshPhysicalMaterial>();
    const bondMaterials = new Map<string, MeshPhysicalMaterial>();
    const segmentGeometries = new Map<string, BufferGeometry>();
    const atomSegments =
      sceneSpec.atomInstances.length > 800
        ? ([24, 16] as const)
        : ([Math.min(profile.atomSegments[0], 64), Math.min(profile.atomSegments[1], 42)] as const);

    const atomMaterial = (
      component: SpeciesComponent | null,
      tint: Color,
    ): MeshPhysicalMaterial => {
      const profile = elementMaterialProfile(component);
      const key = `${profile.code}:${tint.getHexString()}`;
      const cached = atomMaterials.get(key);
      if (cached) return cached;
      const material = new MeshPhysicalMaterial({
        color: tint,
        metalness: scaledMetalness(profile.metalness, options.metalness),
        roughness: scaledRoughness(profile.roughness, options.roughness),
        clearcoat: profile.clearcoat,
        clearcoatRoughness: profile.clearcoatRoughness,
        ior: theme.atom.ior,
        reflectivity: theme.atom.reflectivity,
        specularIntensity: theme.atom.specularIntensity,
        sheen: profile.sheen,
        sheenColor: 0xd9f3ff,
        sheenRoughness: 0.2,
        transmission: profile.transmission,
        thickness: profile.thickness,
        anisotropy: profile.anisotropy,
        iridescence: profile.iridescence,
        iridescenceIOR: theme.atom.iridescenceIOR,
        attenuationColor: tint.clone().lerp(new Color(theme.atom.attenuationColor), 0.48),
        attenuationDistance: theme.atom.attenuationDistance,
        side: FrontSide,
      });
      atomMaterials.set(key, material);
      this.materials.add(material);
      return material;
    };

    for (const atom of sceneSpec.atomInstances) {
      const site = sites.get(atom.siteIndex);
      if (!site || !isAtomVisible(atom, site, options)) continue;
      const total = site.species.reduce((sum, component) => sum + component.occupancy, 0);
      let cursor = 0;
      const components: Array<{ component: SpeciesComponent | null; occupancy: number }> = [
        ...site.species.map((component) => ({ component, occupancy: component.occupancy })),
      ];
      if (total < 0.999999) components.push({ component: null, occupancy: 1 - total });
      for (const { component, occupancy } of components) {
        const key = `${occupancy.toFixed(6)}:${cursor.toFixed(6)}`;
        let geometry = segmentGeometries.get(key);
        if (!geometry) {
          geometry = sphereSegmentGeometry(
            atomSegments[0],
            atomSegments[1],
            cursor * Math.PI * 2,
            occupancy * Math.PI * 2,
          );
          segmentGeometries.set(key, geometry);
          this.geometries.add(geometry);
        }
        const radius = componentRadius(component, options);
        const tint = componentColor(component, options);
        const mesh = new Mesh(geometry, atomMaterial(component, tint));
        mesh.position.set(...atom.position);
        mesh.scale.setScalar(radius);
        mesh.updateMatrix();
        mesh.matrixAutoUpdate = false;
        scene.add(mesh);
        bounds.expandByPoint(vector(atom.position).addScalar(radius));
        bounds.expandByPoint(vector(atom.position).addScalar(-radius));
        cursor += occupancy;
      }
    }

    const radialSegments = sceneSpec.bondInstances.length > 800 ? 12 : 24;
    const fromCylinder = new CylinderGeometry(0.86, 1.16, 1, radialSegments);
    const toCylinder = new CylinderGeometry(1.16, 0.86, 1, radialSegments);
    this.geometries.add(fromCylinder);
    this.geometries.add(toCylinder);
    const siteTint = (siteIndex: number): Color =>
      componentColor(sites.get(siteIndex)?.species[0] ?? null, options);
    const bondMaterial = (tint: Color): MeshPhysicalMaterial => {
      const key = tint.getHexString();
      const cached = bondMaterials.get(key);
      if (cached) return cached;
      const material = new MeshPhysicalMaterial({
        color: tint,
        metalness: scaledMetalness(theme.bond.metalness, options.metalness),
        roughness: scaledRoughness(theme.bond.roughness, options.roughness),
        clearcoat: theme.bond.clearcoat,
        clearcoatRoughness: theme.bond.clearcoatRoughness,
      });
      bondMaterials.set(key, material);
      this.materials.add(material);
      return material;
    };
    const addBondHalf = (
      geometry: CylinderGeometry,
      start: Vector3,
      end: Vector3,
      material: MeshPhysicalMaterial,
    ): void => {
      const mesh = new Mesh(geometry, material);
      mesh.matrix.copy(cylinderMatrix(start.toArray(), end.toArray(), options.bondRadius));
      mesh.matrixAutoUpdate = false;
      scene.add(mesh);
      bounds.expandByPoint(start);
      bounds.expandByPoint(end);
    };
    for (const bond of sceneSpec.bondInstances) {
      const hydrogen =
        isHydrogenSite(sites.get(bond.fromSiteIndex)) ||
        isHydrogenSite(sites.get(bond.toSiteIndex));
      const visible =
        options.showBonds &&
        (options.showHydrogens || !hydrogen) &&
        (bond.visibility === 'base' || options.showBondedOutside || !options.hideIncompleteBonds);
      if (!visible) continue;
      const lanes = options.showBondOrders
        ? Math.max(1, Math.min(3, Math.round(bond.order ?? 1)))
        : 1;
      for (const offset of bondOffsets(bond.start, bond.end, lanes, options.bondRadius)) {
        const start = vector(bond.start).add(offset);
        const end = vector(bond.end).add(offset);
        const midpoint = start.clone().lerp(end, 0.5);
        addBondHalf(fromCylinder, start, midpoint, bondMaterial(siteTint(bond.fromSiteIndex)));
        addBondHalf(toCylinder, midpoint, end, bondMaterial(siteTint(bond.toSiteIndex)));
      }
    }

    if (bounds.isEmpty()) bounds.set(new Vector3(-1, -1, -1), new Vector3(1, 1, 1));
    const center = bounds.getCenter(new Vector3());
    const radius = Math.max(bounds.getSize(new Vector3()).length() * 0.5, 1);

    const palette = cinematicPalette(sceneSpec, options.colorMode);
    const keyLight = new RectAreaLight(
      palette.key,
      5.4 * appearanceScale(options.directionalLight),
      radius * 2.5,
      radius * 2.15,
    );
    const rimLight = new RectAreaLight(
      palette.rim,
      3.7 * appearanceScale(options.directionalLight),
      radius * 1.7,
      radius * 2.3,
    );
    this.lightCenter.copy(center);
    this.lightRadius = radius;
    this.keyLight = keyLight;
    this.rimLight = rimLight;
    this.updateAdaptiveLights(false);
    scene.add(keyLight, rimLight);

    this.baseTargetSamples = profile.pathTracingSamples;
    this.targetSamples = this.baseTargetSamples;
    this.tracer.bounces = profile.pathTracingBounces;
    this.tracer.transmissiveBounces = Math.max(3, Math.floor(profile.pathTracingBounces / 2));
    this.tracer.textureSize.set(profile.textureSize, profile.textureSize);
    this.baseRenderScale = options.renderQuality === 'ultra' ? 0.9 : 0.8;
    this.tracer.renderScale = this.baseRenderScale;
    this.tracer.setScene(scene, this.camera);
    this.ready = true;
    return true;
  }

  get active(): boolean {
    return this.ready && !this.suspended;
  }

  get converged(): boolean {
    return !this.ready || this.tracer.samples >= this.targetSamples;
  }

  renderSample(): void {
    if (this.ready) this.tracer.renderSample();
  }

  updateCamera(): void {
    if (!this.ready) return;
    this.tracer.updateCamera();
    this.updateAdaptiveLights(true);
  }

  reset(): void {
    if (this.ready) this.tracer.reset();
  }

  setHeroMode(active: boolean): void {
    this.targetSamples = active ? Math.max(this.baseTargetSamples, 128) : this.baseTargetSamples;
    this.tracer.renderScale = active ? 1 : this.baseRenderScale;
    this.denoiseMaterial.sigma = active ? 0.9 : 1.25;
    this.denoiseMaterial.threshold = active ? 0.34 : 0.5;
    this.denoiseMaterial.uniforms.gleamoeHero.value = active ? 1 : 0;
    this.denoiseMaterial.uniforms.gleamoeVignette.value = active ? 0.09 : 0.13;
    this.denoiseMaterial.uniforms.gleamoeGrain.value = active ? 0.002 : 0.004;
    if (this.ready) this.tracer.reset();
  }

  setSuspended(suspended: boolean): void {
    if (this.suspended === suspended) return;
    this.suspended = suspended;
    if (!suspended && this.ready) this.tracer.reset();
  }

  setExportTiling(active: boolean): void {
    this.tracer.tiles.set(active ? 4 : 1, active ? 3 : 1);
    if (this.ready) this.tracer.reset();
  }

  async converge(onProgress?: (progress: PathTraceProgress) => void): Promise<void> {
    if (!this.ready) return;
    let rendered = 0;
    const submissionsPerFrame = regionalSubmissionBatchSize(
      this.tracer.tiles.x,
      this.tracer.tiles.y,
    );
    const report = (): void => {
      onProgress?.(
        pathTraceProgress(
          this.tracer.samples,
          this.targetSamples,
          this.tracer.tiles.x,
          this.tracer.tiles.y,
          submissionsPerFrame,
        ),
      );
    };
    report();
    while (!this.converged) {
      this.tracer.renderSample();
      rendered += 1;
      if (rendered % submissionsPerFrame === 0 || this.converged) {
        report();
      }
      if (!this.converged && rendered % submissionsPerFrame === 0) {
        await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
      }
    }
  }

  dispose(): void {
    this.disposeScene(true);
    this.denoiseMaterial.dispose();
    this.tracer.dispose();
  }

  private disposeScene(disposeEnvironment = false): void {
    this.ready = false;
    this.suspended = false;
    this.targetSamples = 0;
    this.baseTargetSamples = 0;
    if (disposeEnvironment) {
      this.environment?.dispose();
      this.environment = undefined;
    }
    for (const geometry of this.geometries) geometry.dispose();
    for (const material of this.materials) material.dispose();
    this.geometries.clear();
    this.materials.clear();
    this.keyLight = undefined;
    this.rimLight = undefined;
  }

  private updateAdaptiveLights(updateTracer: boolean): void {
    if (!this.keyLight || !this.rimLight) return;
    const view = this.camera.position.clone().sub(this.lightCenter).normalize();
    const right = new Vector3().crossVectors(view, this.camera.up).normalize();
    if (right.lengthSq() < 1e-6) right.set(1, 0, 0);
    const up = new Vector3().crossVectors(right, view).normalize();
    const radius = this.lightRadius;
    this.keyLight.position
      .copy(this.lightCenter)
      .addScaledVector(view, radius * 2.65)
      .addScaledVector(right, radius * 2.45)
      .addScaledVector(up, radius * 1.85);
    this.rimLight.position
      .copy(this.lightCenter)
      .addScaledVector(view, -radius * 0.8)
      .addScaledVector(right, -radius * 2.65)
      .addScaledVector(up, radius * 1.1);
    this.keyLight.lookAt(this.lightCenter);
    this.rimLight.lookAt(this.lightCenter);
    if (updateTracer) this.tracer.updateLights();
  }

  private installCinematicGrade(): void {
    this.denoiseMaterial.fragmentShader = this.denoiseMaterial.fragmentShader
      .replace(
        'uniform float opacity;',
        `uniform float opacity;
        uniform float gleamoeVignette;
        uniform float gleamoeGrain;
        uniform float gleamoeHero;
        ${gleamoeGalaxyShader}`,
      )
      .replace(
        '#include <tonemapping_fragment>',
        `vec2 gleamoeTexel = 1.0 / vec2(textureSize(map, 0));
        vec3 gleamoeSource = texture2D(map, vUv).rgb;
        vec3 gleamoeBackgroundReference = (
          texture2D(map, vec2(0.012, 0.012)).rgb
          + texture2D(map, vec2(0.988, 0.012)).rgb
          + texture2D(map, vec2(0.012, 0.988)).rgb
          + texture2D(map, vec2(0.988, 0.988)).rgb
        ) * 0.25;
        float gleamoeBackgroundMask = 1.0 - smoothstep(
          0.025,
          0.24,
          length(gleamoeSource - gleamoeBackgroundReference)
        );
        vec3 gleamoeGalaxyColor = gleamoeGalaxy(vUv, mix(0.84, 1.0, gleamoeHero));
        gl_FragColor.rgb = mix(
          gl_FragColor.rgb,
          gleamoeGalaxyColor,
          gleamoeBackgroundMask * mix(0.84, 0.98, gleamoeHero)
        );

        vec3 gleamoeNearest = (
          texture2D(map, vUv + vec2(gleamoeTexel.x, 0.0)).rgb
          + texture2D(map, vUv - vec2(gleamoeTexel.x, 0.0)).rgb
          + texture2D(map, vUv + vec2(0.0, gleamoeTexel.y)).rgb
          + texture2D(map, vUv - vec2(0.0, gleamoeTexel.y)).rgb
        ) * 0.25;
        vec3 gleamoeCrisp = gleamoeSource + (gleamoeSource - gleamoeNearest)
          * mix(0.12, 0.28, gleamoeHero);
        gl_FragColor.rgb = mix(
          gl_FragColor.rgb,
          max(gleamoeCrisp, 0.0),
          mix(0.18, 0.5, gleamoeHero) * (1.0 - gleamoeBackgroundMask)
        );

        vec3 gleamoeLocal = gl_FragColor.rgb * 0.52;
        gleamoeLocal += texture2D(map, vUv + vec2(gleamoeTexel.x * 3.0, 0.0)).rgb * 0.12;
        gleamoeLocal += texture2D(map, vUv - vec2(gleamoeTexel.x * 3.0, 0.0)).rgb * 0.12;
        gleamoeLocal += texture2D(map, vUv + vec2(0.0, gleamoeTexel.y * 3.0)).rgb * 0.12;
        gleamoeLocal += texture2D(map, vUv - vec2(0.0, gleamoeTexel.y * 3.0)).rgb * 0.12;
        float gleamoeLocalLuma = dot(gleamoeLocal, vec3(0.2126, 0.7152, 0.0722));
        float gleamoeExposure = clamp(0.56 / (gleamoeLocalLuma + 0.18), 0.78, 1.16);
        gl_FragColor.rgb *= mix(1.0, gleamoeExposure, mix(0.2, 0.25, gleamoeHero));
        float gleamoePreLuma = dot(gl_FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        float gleamoeHighlight = smoothstep(0.72, 1.55, gleamoePreLuma);
        vec3 gleamoeRolled = gl_FragColor.rgb / (1.0 + max(gl_FragColor.rgb - 0.7, 0.0));
        gl_FragColor.rgb = mix(gl_FragColor.rgb, gleamoeRolled, gleamoeHighlight * mix(0.42, 0.5, gleamoeHero));
        float gleamoeLuma = dot(gl_FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 gleamoeCool = gl_FragColor.rgb * vec3(0.965, 1.0, 1.045);
        vec3 gleamoeWarm = gl_FragColor.rgb * vec3(1.035, 1.012, 0.975);
        gl_FragColor.rgb = mix(gleamoeCool, gleamoeWarm, smoothstep(0.24, 0.86, gleamoeLuma));
        gl_FragColor.rgb = (gl_FragColor.rgb - 0.5) * 1.035 + 0.5;
        vec2 gleamoeCenteredUv = vUv - 0.5;
        float gleamoeEdge = smoothstep(0.18, 0.72, dot(gleamoeCenteredUv, gleamoeCenteredUv) * 1.8);
        gl_FragColor.rgb *= 1.0 - gleamoeEdge * gleamoeVignette;
        float gleamoeNoise = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        gl_FragColor.rgb += gleamoeNoise * gleamoeGrain * (1.0 - smoothstep(0.2, 1.0, gleamoeLuma));
        #include <tonemapping_fragment>`,
      );
    this.denoiseMaterial.uniforms.gleamoeVignette = { value: 0.13 };
    this.denoiseMaterial.uniforms.gleamoeGrain = { value: 0.004 };
    this.denoiseMaterial.uniforms.gleamoeHero = { value: 0 };
    this.denoiseMaterial.needsUpdate = true;
  }
}
