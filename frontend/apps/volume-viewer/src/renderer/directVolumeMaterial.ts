import {
  BackSide,
  Data3DTexture,
  DataTexture,
  ShaderMaterial,
  Vector2,
  Vector3,
} from 'three';

import type { VolumeGridSpec } from '@kssolv/volume-scene';

import type { VolumeOptions } from '../state/volumeStore';

const qualityStep = (quality: VolumeOptions['volumeQuality']): number => {
  if (quality === 'fast') return 1.35;
  if (quality === 'high') return 0.42;
  return 0.72;
};

export const createDirectVolumeMaterial = (
  texture: Data3DTexture,
  colormap: DataTexture,
  grid: VolumeGridSpec,
  options: VolumeOptions,
): ShaderMaterial => {
  const span = Math.max(options.rangeMaximum - options.rangeMinimum, Number.EPSILON);
  const zeroFraction = Math.min(
    1,
    Math.max(0, -options.rangeMinimum / span),
  );
  const material = new ShaderMaterial({
    uniforms: {
      u_data: { value: texture },
      u_colormap: { value: colormap },
      u_size: { value: new Vector3(...grid.dimensions) },
      u_range: {
        value: new Vector2(options.rangeMinimum, options.rangeMaximum),
      },
      u_zero: { value: zeroFraction },
      u_opacity: { value: options.opacity },
      u_gradient_opacity: { value: options.gradientOpacity },
      u_step_size: { value: qualityStep(options.volumeQuality) },
      u_clip_min: { value: new Vector3(...options.clipMinimum) },
      u_clip_max: { value: new Vector3(...options.clipMaximum) },
    },
    vertexShader: `
      varying vec3 v_position;
      varying vec3 v_camera_in_object;
      varying vec3 v_view_direction_in_object;

      void main() {
        v_position = position;
        v_camera_in_object =
          (inverse(modelMatrix) * vec4(cameraPosition, 1.0)).xyz;
        v_view_direction_in_object =
          (inverse(modelViewMatrix) * vec4(0.0, 0.0, -1.0, 0.0)).xyz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      precision highp float;
      precision mediump sampler3D;

      uniform sampler3D u_data;
      uniform sampler2D u_colormap;
      uniform vec3 u_size;
      uniform vec2 u_range;
      uniform float u_zero;
      uniform float u_opacity;
      uniform float u_gradient_opacity;
      uniform float u_step_size;
      uniform vec3 u_clip_min;
      uniform vec3 u_clip_max;

      varying vec3 v_position;
      varying vec3 v_camera_in_object;
      varying vec3 v_view_direction_in_object;

      const int MIN_STEPS = 64;
      const int MAX_STEPS = 1536;

      float sample_volume(vec3 texture_coordinate) {
        return texture(u_data, texture_coordinate).r;
      }

      void main() {
        vec3 ray_direction = isOrthographic
          ? normalize(-v_view_direction_in_object)
          : normalize(v_camera_in_object - v_position);
        vec3 safe_direction = ray_direction;
        if (abs(safe_direction.x) < 1e-6) safe_direction.x = 1e-6;
        if (abs(safe_direction.y) < 1e-6) safe_direction.y = 1e-6;
        if (abs(safe_direction.z) < 1e-6) safe_direction.z = 1e-6;

        vec3 box_min = u_clip_min * u_size - vec3(0.5);
        vec3 box_max = u_clip_max * u_size - vec3(0.5);
        vec3 first = (box_min - v_position) / safe_direction;
        vec3 second = (box_max - v_position) / safe_direction;
        vec3 lower = min(first, second);
        vec3 upper = max(first, second);
        float entry = max(0.0, max(lower.x, max(lower.y, lower.z)));
        float exit = min(upper.x, min(upper.y, upper.z));
        if (exit <= entry) discard;

        float distance = exit - entry;
        int step_count = int(ceil(distance / u_step_size));
        if (step_count < MIN_STEPS) step_count = MIN_STEPS;
        if (step_count > MAX_STEPS) step_count = MAX_STEPS;
        vec3 step_vector = ray_direction * (distance / float(step_count));
        vec3 location =
          v_position + ray_direction * entry + 0.5 * step_vector;
        vec3 texel = vec3(1.0) / u_size;
        float range_span = max(u_range.y - u_range.x, 1e-12);
        vec4 accumulated = vec4(0.0);

        for (int iteration = 0; iteration < MAX_STEPS; iteration += 1) {
          if (iteration >= step_count) break;
          vec3 texture_coordinate = (location + vec3(0.5)) / u_size;
          float value = sample_volume(texture_coordinate);
          if (value == value) {
            float normalized = clamp(
              (value - u_range.x) / range_span,
              0.0,
              1.0
            );
            vec4 sample_color = texture2D(
              u_colormap,
              vec2((normalized * 255.0 + 0.5) / 256.0, 0.5)
            );
            float gx = sample_volume(texture_coordinate + vec3(texel.x, 0.0, 0.0))
              - sample_volume(texture_coordinate - vec3(texel.x, 0.0, 0.0));
            float gy = sample_volume(texture_coordinate + vec3(0.0, texel.y, 0.0))
              - sample_volume(texture_coordinate - vec3(0.0, texel.y, 0.0));
            float gz = sample_volume(texture_coordinate + vec3(0.0, 0.0, texel.z))
              - sample_volume(texture_coordinate - vec3(0.0, 0.0, texel.z));
            float gradient = clamp(length(vec3(gx, gy, gz)) / range_span, 0.0, 1.0);
            float scalar_density = clamp(abs(normalized - u_zero) * 3.5, 0.0, 1.0);
            float gradient_factor = mix(1.0, max(0.12, gradient), u_gradient_opacity);
            float alpha = 1.0 - exp(
              -scalar_density * gradient_factor * u_opacity *
              max(1e-5, length(step_vector))
            );
            sample_color.a = clamp(alpha, 0.0, 1.0);

            // Rays traverse the back faces toward the camera. This is
            // back-to-front compositing, so each new sample is placed over
            // the accumulated color.
            accumulated.rgb =
              sample_color.rgb * sample_color.a +
              accumulated.rgb * (1.0 - sample_color.a);
            accumulated.a =
              sample_color.a + accumulated.a * (1.0 - sample_color.a);
            if (accumulated.a > 0.985) break;
          }
          location += step_vector;
        }

        if (accumulated.a < 0.01) discard;
        gl_FragColor = accumulated;
      }
    `,
    side: BackSide,
    transparent: true,
    depthWrite: false,
  });
  material.name = 'kssolv-direct-volume';
  return material;
};

export const updateDirectVolumeMaterial = (
  material: ShaderMaterial,
  options: VolumeOptions,
): void => {
  if (material.name !== 'kssolv-direct-volume') return;
  const span = Math.max(
    options.rangeMaximum - options.rangeMinimum,
    Number.EPSILON,
  );
  material.uniforms.u_range.value.set(
    options.rangeMinimum,
    options.rangeMaximum,
  );
  material.uniforms.u_zero.value = Math.min(
    1,
    Math.max(0, -options.rangeMinimum / span),
  );
  material.uniforms.u_opacity.value = options.opacity;
  material.uniforms.u_gradient_opacity.value = options.gradientOpacity;
  material.uniforms.u_step_size.value = qualityStep(options.volumeQuality);
  material.uniforms.u_clip_min.value.set(...options.clipMinimum);
  material.uniforms.u_clip_max.value.set(...options.clipMaximum);
};
