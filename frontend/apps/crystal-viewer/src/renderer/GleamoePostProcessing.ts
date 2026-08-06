import {
  ShaderMaterial,
  Vector2,
  Vector3,
  type Box3,
  type OrthographicCamera,
  type Scene,
  type WebGLRenderer,
} from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { BokehPass } from 'three/examples/jsm/postprocessing/BokehPass.js';
import { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';

import { gleamoeGalaxyShader } from './GleamoeBackdrop';

const cinematicGradeMaterial = (): ShaderMaterial =>
  new ShaderMaterial({
    name: 'GleamoeCinematicGrade',
    depthTest: false,
    depthWrite: false,
    uniforms: {
      tDiffuse: { value: null },
      grainSeed: { value: 0 },
      grainStrength: { value: 0.008 },
      vignetteStrength: { value: 0.17 },
      texelSize: { value: new Vector2(1, 1) },
      localExposureStrength: { value: 0.2 },
      highlightProtection: { value: 0.42 },
      heroMode: { value: 0 },
    },
    vertexShader: /* glsl */ `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: /* glsl */ `
      uniform sampler2D tDiffuse;
      uniform float grainSeed;
      uniform float grainStrength;
      uniform float vignetteStrength;
      uniform vec2 texelSize;
      uniform float localExposureStrength;
      uniform float highlightProtection;
      uniform float heroMode;
      varying vec2 vUv;

      ${gleamoeGalaxyShader}

      float hash12(vec2 value) {
        vec3 p3 = fract(vec3(value.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33 + grainSeed);
        return fract((p3.x + p3.y) * p3.z);
      }

      void main() {
        vec4 sampleColor = texture2D(tDiffuse, vUv);
        vec3 backgroundReference = (
          texture2D(tDiffuse, vec2(0.012, 0.012)).rgb
          + texture2D(tDiffuse, vec2(0.988, 0.012)).rgb
          + texture2D(tDiffuse, vec2(0.012, 0.988)).rgb
          + texture2D(tDiffuse, vec2(0.988, 0.988)).rgb
        ) * 0.25;
        float backgroundMask = 1.0 - smoothstep(
          0.025,
          0.24,
          length(sampleColor.rgb - backgroundReference)
        );
        vec3 galaxy = gleamoeGalaxy(vUv, mix(0.82, 1.0, heroMode));
        sampleColor.rgb = mix(
          sampleColor.rgb,
          galaxy,
          backgroundMask * mix(0.82, 0.97, heroMode)
        );

        vec3 nearestNeighbors = (
          texture2D(tDiffuse, vUv + vec2(texelSize.x, 0.0)).rgb
          + texture2D(tDiffuse, vUv - vec2(texelSize.x, 0.0)).rgb
          + texture2D(tDiffuse, vUv + vec2(0.0, texelSize.y)).rgb
          + texture2D(tDiffuse, vUv - vec2(0.0, texelSize.y)).rgb
        ) * 0.25;
        vec3 sharpened = sampleColor.rgb + (sampleColor.rgb - nearestNeighbors)
          * mix(0.16, 0.38, heroMode) * (1.0 - backgroundMask);
        sampleColor.rgb = max(sharpened, 0.0);
        float luma = dot(sampleColor.rgb, vec3(0.2126, 0.7152, 0.0722));

        vec2 neighborhood = texelSize * 3.0;
        vec3 localColor = sampleColor.rgb * 0.36;
        localColor += texture2D(tDiffuse, vUv + vec2(neighborhood.x, 0.0)).rgb * 0.12;
        localColor += texture2D(tDiffuse, vUv - vec2(neighborhood.x, 0.0)).rgb * 0.12;
        localColor += texture2D(tDiffuse, vUv + vec2(0.0, neighborhood.y)).rgb * 0.12;
        localColor += texture2D(tDiffuse, vUv - vec2(0.0, neighborhood.y)).rgb * 0.12;
        localColor += texture2D(tDiffuse, vUv + neighborhood).rgb * 0.08;
        localColor += texture2D(tDiffuse, vUv - neighborhood).rgb * 0.08;
        float localLuma = dot(localColor, vec3(0.2126, 0.7152, 0.0722));
        float localExposure = clamp(0.56 / (localLuma + 0.18), 0.78, 1.16);
        sampleColor.rgb *= mix(1.0, localExposure, localExposureStrength);

        float highlightWeight = smoothstep(0.72, 1.55, luma);
        vec3 rolledHighlights = sampleColor.rgb / (1.0 + max(sampleColor.rgb - 0.7, 0.0));
        sampleColor.rgb = mix(
          sampleColor.rgb,
          rolledHighlights,
          highlightWeight * highlightProtection
        );
        luma = dot(sampleColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 coolShadows = sampleColor.rgb * vec3(0.965, 1.0, 1.045);
        vec3 warmHighlights = sampleColor.rgb * vec3(1.035, 1.012, 0.975);
        vec3 graded = mix(coolShadows, warmHighlights, smoothstep(0.24, 0.86, luma));
        graded = (graded - 0.5) * 1.035 + 0.5;

        vec2 centered = vUv - 0.5;
        float vignette = smoothstep(0.18, 0.72, dot(centered, centered) * 1.8);
        graded *= 1.0 - vignette * vignetteStrength;

        float grain = hash12(gl_FragCoord.xy) - 0.5;
        graded += grain * grainStrength * (1.0 - smoothstep(0.2, 1.0, luma));
        gl_FragColor = vec4(max(graded, 0.0), sampleColor.a);
      }
    `,
  });

/** AAA-style raster preview used while the path tracer is accumulating samples. */
export class GleamoePostProcessing {
  private readonly composer: EffectComposer;
  private readonly gtaoPass: GTAOPass;
  private readonly bloomPass: UnrealBloomPass;
  private readonly bokehPass: BokehPass;
  private readonly gradeMaterial = cinematicGradeMaterial();
  private readonly gradePass: ShaderPass;
  private frame = 0;
  private focusDistance = 10;
  private targetFocusDistance = 10;
  private heroMode = false;
  private focusEmphasized = false;

  constructor(renderer: WebGLRenderer, scene: Scene, camera: OrthographicCamera) {
    const size = renderer.getSize(new Vector2());
    this.composer = new EffectComposer(renderer);
    this.composer.setPixelRatio(Math.min(renderer.getPixelRatio(), 1.25));
    this.composer.setSize(size.x, size.y);
    this.composer.addPass(new RenderPass(scene, camera));

    this.gtaoPass = new GTAOPass(scene, camera, size.x, size.y);
    this.gtaoPass.blendIntensity = 0.62;
    this.gtaoPass.updateGtaoMaterial({
      radius: 0.16,
      distanceExponent: 1.5,
      thickness: 0.8,
      distanceFallOff: 0.55,
      scale: 1,
      samples: 16,
      screenSpaceRadius: true,
    });
    this.gtaoPass.updatePdMaterial({
      lumaPhi: 8,
      depthPhi: 2,
      normalPhi: 3,
      radius: 6,
      radiusExponent: 1.8,
      rings: 2,
      samples: 16,
    });
    this.composer.addPass(this.gtaoPass);

    this.bokehPass = new BokehPass(scene, camera, {
      focus: 10,
      aperture: 0.00012,
      maxblur: 0.0022,
    });
    this.bokehPass.materialBokeh.defines.PERSPECTIVE_CAMERA = 0;
    this.bokehPass.materialBokeh.needsUpdate = true;
    this.composer.addPass(this.bokehPass);

    // A high luminance threshold makes this a selective highlight mask rather than a scene glow.
    this.bloomPass = new UnrealBloomPass(size, 0.1, 0.3, 1.08);
    this.composer.addPass(this.bloomPass);
    this.gradePass = new ShaderPass(this.gradeMaterial);
    this.composer.addPass(this.gradePass);
    this.composer.addPass(new OutputPass());
  }

  render(): void {
    this.frame = (this.frame + 1) % 1024;
    this.gradeMaterial.uniforms.grainSeed.value = this.frame * 0.754877666;
    this.focusDistance += (this.targetFocusDistance - this.focusDistance) * 0.14;
    this.bokehPass.materialBokeh.uniforms.focus.value = this.focusDistance;
    this.composer.render();
  }

  setSize(width: number, height: number, rendererPixelRatio: number): void {
    this.composer.setPixelRatio(Math.min(rendererPixelRatio, 1.25));
    this.composer.setSize(width, height);
    this.gradeMaterial.uniforms.texelSize.value.set(
      1 / Math.max(width * Math.min(rendererPixelRatio, 1.25), 1),
      1 / Math.max(height * Math.min(rendererPixelRatio, 1.25), 1),
    );
  }

  setSceneBounds(bounds: Box3): void {
    if (bounds.isEmpty()) return;
    this.gtaoPass.setSceneClipBox(bounds);
    this.setFocusPoint(bounds.getCenter(new Vector3()), true);
  }

  setFocusPoint(point: Vector3, immediate = false): void {
    const cameraSpace = point.clone().applyMatrix4(this.bokehPass.camera.matrixWorldInverse);
    this.targetFocusDistance = Math.max(-cameraSpace.z, 0.01);
    if (immediate) this.focusDistance = this.targetFocusDistance;
  }

  setHeroMode(active: boolean): void {
    this.heroMode = active;
    this.updateBloom();
    this.updateDepthOfField();
    this.gradeMaterial.uniforms.grainStrength.value = active ? 0.006 : 0.008;
    this.gradeMaterial.uniforms.vignetteStrength.value = active ? 0.2 : 0.17;
    this.gradeMaterial.uniforms.localExposureStrength.value = active ? 0.25 : 0.2;
    this.gradeMaterial.uniforms.highlightProtection.value = active ? 0.5 : 0.42;
    this.gradeMaterial.uniforms.heroMode.value = active ? 1 : 0;
  }

  setFocusEmphasis(active: boolean): void {
    this.focusEmphasized = active;
    this.updateDepthOfField();
    this.updateBloom();
  }

  dispose(): void {
    this.gtaoPass.dispose();
    this.bokehPass.dispose();
    this.bloomPass.dispose();
    this.gradePass.dispose();
    this.composer.dispose();
  }

  private updateDepthOfField(): void {
    const aperture = this.heroMode ? 0.00004 : this.focusEmphasized ? 0.00016 : 0.00008;
    const maxBlur = this.heroMode ? 0.00055 : this.focusEmphasized ? 0.0022 : 0.0014;
    this.bokehPass.materialBokeh.uniforms.aperture.value = aperture;
    this.bokehPass.materialBokeh.uniforms.maxblur.value = maxBlur;
  }

  private updateBloom(): void {
    this.bloomPass.strength = this.heroMode ? 0.095 : this.focusEmphasized ? 0.018 : 0.065;
    this.bloomPass.radius = this.heroMode ? 0.2 : this.focusEmphasized ? 0.16 : 0.18;
    this.bloomPass.threshold = this.heroMode ? 1.02 : this.focusEmphasized ? 1.28 : 1.14;
  }
}
