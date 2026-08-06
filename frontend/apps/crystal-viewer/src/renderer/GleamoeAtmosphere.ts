import {
  AdditiveBlending,
  BufferAttribute,
  BufferGeometry,
  Color,
  Group,
  Points,
  ShaderMaterial,
  Vector3,
  type OrthographicCamera,
} from 'three';

import type { CinematicPalette } from './artDirection';

const seededRandom = (seed: number): (() => number) => {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 0x1_0000_0000;
  };
};

/** Sparse cinematic atmosphere that preserves scientific readability. */
export class GleamoeAtmosphere {
  readonly group = new Group();
  private readonly particleGeometry = new BufferGeometry();
  private readonly particleMaterial: ShaderMaterial;
  private readonly particles: Points;
  private heroMode = false;

  constructor(center: Vector3, radius: number, palette: CinematicPalette) {
    this.group.name = 'gleamoe-atmosphere';
    const random = seededRandom(0x6c65616d);
    const positions = new Float32Array(420 * 3);
    const phases = new Float32Array(420);
    for (let index = 0; index < phases.length; index += 1) {
      const distance = radius * (1.25 + random() * 3.8);
      const azimuth = random() * Math.PI * 2;
      const elevation = Math.asin(random() * 2 - 1);
      positions[index * 3] = center.x + Math.cos(elevation) * Math.cos(azimuth) * distance;
      positions[index * 3 + 1] = center.y + Math.cos(elevation) * Math.sin(azimuth) * distance;
      positions[index * 3 + 2] = center.z + Math.sin(elevation) * distance;
      phases[index] = random();
    }
    this.particleGeometry.setAttribute('position', new BufferAttribute(positions, 3));
    this.particleGeometry.setAttribute('aPhase', new BufferAttribute(phases, 1));
    this.particleMaterial = new ShaderMaterial({
      name: 'GleamoeAtmosphericParticles',
      uniforms: {
        tint: { value: palette.rim.clone().lerp(new Color(0xffffff), 0.42) },
        time: { value: 0 },
        opacity: { value: 0.2 },
        pointSize: { value: 2.15 },
      },
      vertexShader: /* glsl */ `
        attribute float aPhase;
        uniform float time;
        uniform float pointSize;
        varying float vTwinkle;
        void main() {
          vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
          vTwinkle = 0.62 + 0.38 * sin(aPhase * 31.4159 + time * 0.42);
          gl_PointSize = pointSize * (0.78 + aPhase * 0.62);
          gl_Position = projectionMatrix * viewPosition;
        }
      `,
      fragmentShader: /* glsl */ `
        uniform vec3 tint;
        uniform float opacity;
        varying float vTwinkle;
        void main() {
          vec2 centered = gl_PointCoord - 0.5;
          float falloff = smoothstep(0.5, 0.0, length(centered));
          falloff *= falloff;
          if (falloff < 0.01) discard;
          gl_FragColor = vec4(tint, falloff * opacity * vTwinkle);
        }
      `,
      transparent: true,
      depthWrite: false,
      depthTest: true,
      blending: AdditiveBlending,
      toneMapped: true,
    });
    this.particles = new Points(this.particleGeometry, this.particleMaterial);
    this.particles.renderOrder = 3;
    this.group.add(this.particles);
  }

  updateCamera(_camera: OrthographicCamera): void {
    // Kept as a stable hook for future camera-relative atmospheric effects.
  }

  update(timestamp: number): void {
    this.particleMaterial.uniforms.time.value = timestamp * 0.001;
  }

  setHeroMode(active: boolean): void {
    this.heroMode = active;
    this.particleMaterial.uniforms.opacity.value = active ? 0.29 : 0.2;
    this.particleMaterial.uniforms.pointSize.value = active ? 2.5 : 2.15;
  }

  get animated(): boolean {
    return this.heroMode;
  }

  dispose(): void {
    this.particleGeometry.dispose();
    this.particleMaterial.dispose();
    this.group.clear();
  }
}
