/** Resolution-independent cinematic galaxy used by both raster and path-traced output. */
export const gleamoeGalaxyShader = /* glsl */ `
  float gleamoeHash21(vec2 value) {
    value = fract(value * vec2(123.34, 456.21));
    value += dot(value, value + 45.32);
    return fract(value.x * value.y);
  }

  float gleamoeNoise(vec2 value) {
    vec2 cell = floor(value);
    vec2 local = fract(value);
    local = local * local * (3.0 - 2.0 * local);
    float a = gleamoeHash21(cell);
    float b = gleamoeHash21(cell + vec2(1.0, 0.0));
    float c = gleamoeHash21(cell + vec2(0.0, 1.0));
    float d = gleamoeHash21(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
  }

  float gleamoeFbm(vec2 value) {
    float result = 0.0;
    float amplitude = 0.54;
    mat2 octave = mat2(1.72, 1.16, -1.16, 1.72);
    for (int iteration = 0; iteration < 5; iteration++) {
      result += amplitude * gleamoeNoise(value);
      value = octave * value + vec2(4.7, 8.3);
      amplitude *= 0.48;
    }
    return result;
  }

  vec3 gleamoeGalaxy(vec2 uv, float strength) {
    vec2 centered = (uv - 0.5) * vec2(1.48, 1.0);
    float angle = -0.42;
    mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    vec2 galaxyUv = rotation * centered;
    float flow = galaxyUv.y + 0.09 * sin(galaxyUv.x * 5.2)
      + 0.025 * sin(galaxyUv.x * 15.0);
    float wideBand = exp(-abs(flow) * 6.2);
    float brightCore = exp(-abs(flow) * 18.0);
    float cloud = gleamoeFbm(galaxyUv * 4.1 + vec2(2.4, 7.1));
    float dust = gleamoeFbm(galaxyUv * 10.7 - vec2(5.2, 1.8));
    float nebula = wideBand * smoothstep(0.34, 0.88, cloud + brightCore * 0.24);
    nebula *= mix(0.58, 1.0, smoothstep(0.2, 0.78, dust));

    float horizon = smoothstep(0.0, 1.0, uv.y);
    float centerGlow = exp(-dot(centered * vec2(0.78, 1.18), centered) * 2.8);
    vec3 color = mix(vec3(0.012, 0.022, 0.052), vec3(0.025, 0.052, 0.105), horizon);
    color += centerGlow * vec3(0.012, 0.025, 0.054);
    color += nebula * mix(vec3(0.075, 0.105, 0.21), vec3(0.16, 0.075, 0.22), cloud);
    color += brightCore * wideBand * vec3(0.055, 0.095, 0.16) * (0.4 + cloud * 0.6);

    vec2 fineGrid = uv * vec2(430.0, 250.0);
    vec2 fineCell = fract(fineGrid) - 0.5;
    vec2 fineId = floor(fineGrid);
    float fineSeed = gleamoeHash21(fineId);
    float fineRadius = mix(0.035, 0.115, pow(fineSeed, 9.0));
    float fineStar = smoothstep(fineRadius, 0.0, length(fineCell));
    fineStar *= smoothstep(0.982, 0.999, fineSeed);
    vec3 fineTint = mix(vec3(0.62, 0.78, 1.0), vec3(1.0, 0.82, 0.72), gleamoeHash21(fineId + 17.0));

    vec2 heroGrid = uv * vec2(128.0, 74.0);
    vec2 heroCell = fract(heroGrid) - 0.5;
    vec2 heroId = floor(heroGrid);
    float heroSeed = gleamoeHash21(heroId + 91.7);
    float heroStar = smoothstep(0.14, 0.0, length(heroCell));
    heroStar *= smoothstep(0.993, 0.9997, heroSeed);
    float flare = exp(-abs(heroCell.x) * 38.0) * exp(-abs(heroCell.y) * 5.0)
      + exp(-abs(heroCell.y) * 38.0) * exp(-abs(heroCell.x) * 5.0);
    heroStar += flare * smoothstep(0.997, 0.9998, heroSeed) * 0.22;

    color += fineTint * fineStar * 0.9;
    color += vec3(0.72, 0.86, 1.0) * heroStar * 1.25;
    return color * strength;
  }
`;
