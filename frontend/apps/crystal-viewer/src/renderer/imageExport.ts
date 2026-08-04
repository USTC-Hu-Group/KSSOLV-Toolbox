import { Color, OrthographicCamera, Vector3 } from 'three';
import { ConvexGeometry } from 'three/examples/jsm/geometries/ConvexGeometry.js';
import * as UTIF from 'utif';

import type {
  AtomicSceneSpec,
  RgbTuple,
  SiteSpec,
  Vector3Tuple,
  ViewerOptions,
} from '../scene/types';
import type { ViewerTheme } from '../themes/themes';

export type ImageExportFormat = 'png' | 'jpeg' | 'tiff' | 'svg' | 'pdf-vector' | 'pdf-raster';

export const flipRgbaRows = (rgba: Uint8Array, width: number, height: number): Uint8Array => {
  const rowLength = width * 4;
  if (width <= 0 || height <= 0 || rgba.length !== rowLength * height) {
    throw new Error('RGBA dimensions do not match the pixel buffer.');
  }
  const flipped = new Uint8Array(rgba.length);
  for (let row = 0; row < height; row += 1) {
    const sourceOffset = (height - row - 1) * rowLength;
    flipped.set(rgba.subarray(sourceOffset, sourceOffset + rowLength), row * rowLength);
  }
  return flipped;
};

export const rgbaToTiffBlob = (rgba: Uint8Array, width: number, height: number): Blob => {
  if (width <= 0 || height <= 0 || rgba.length !== width * height * 4) {
    throw new Error('RGBA dimensions do not match the TIFF image size.');
  }
  return new Blob([UTIF.encodeImage(rgba, width, height)], { type: 'image/tiff' });
};

export interface VectorExportInput {
  scene: AtomicSceneSpec;
  options: ViewerOptions;
  theme: ViewerTheme;
  camera: OrthographicCamera;
  width: number;
  height: number;
  axisDirections: [Vector3, Vector3, Vector3];
  selected?: { kind: 'atom' | 'bond'; id: string; radius?: number };
}

interface ProjectedPoint {
  x: number;
  y: number;
  depth: number;
}

interface SvgItem {
  depth: number;
  priority: number;
  markup: string;
}

const XMLNS = 'http://www.w3.org/2000/svg';
const KEY_LIGHT_DIRECTION = new Vector3(7, 10, 12).normalize();
const FILL_LIGHT_DIRECTION = new Vector3(-8, -4, 6).normalize();
const number = (value: number): string => (Math.round(value * 100) / 100).toString();
const point = (value: ProjectedPoint): string => `${number(value.x)},${number(value.y)}`;
const vector = (value: Vector3Tuple): Vector3 => new Vector3(...value);
const clampChannel = (value: number): number => Math.min(255, Math.max(0, Math.round(value)));

const rgbHex = (value: RgbTuple): string =>
  `#${value.map((entry) => clampChannel(entry).toString(16).padStart(2, '0')).join('')}`;

const hexRgb = (value: string): RgbTuple => {
  const normalized = value.replace('#', '');
  return [0, 2, 4].map((offset) =>
    Number.parseInt(normalized.slice(offset, offset + 2), 16),
  ) as RgbTuple;
};

const mixRgb = (from: RgbTuple, to: RgbTuple, amount: number): RgbTuple => {
  const weight = Math.min(1, Math.max(0, amount));
  return from.map((entry, index) => entry + (to[index] - entry) * weight) as RgbTuple;
};

const mixHex = (from: string, to: RgbTuple, amount: number): string =>
  rgbHex(mixRgb(hexRgb(from), to, amount));

const shadeHex = (value: string, intensity: number): string =>
  intensity >= 1
    ? mixHex(value, [255, 255, 255], Math.min(0.55, intensity - 1))
    : rgbHex(hexRgb(value).map((channel) => channel * Math.max(0, intensity)) as RgbTuple);

const saturate = (value: RgbTuple, enabled: boolean): string => {
  const color = new Color(rgbHex(value));
  if (enabled) {
    const hsl = { h: 0, s: 0, l: 0 };
    color.getHSL(hsl);
    if (hsl.s > 0.04) color.setHSL(hsl.h, Math.min(1, hsl.s * 1.35 + 0.04), hsl.l);
  }
  return `#${color.getHexString()}`;
};

const siteColor = (
  component: SiteSpec['species'][number] | undefined,
  input: VectorExportInput,
  fallback = '#a0a0a0',
): string =>
  component
    ? saturate(
        input.options.colorMode === 'vesta' ? component.colorVesta : component.colorJmol,
        input.theme.id === 'materials',
      )
    : fallback;

const atomRadius = (
  component: SiteSpec['species'][number] | null,
  options: ViewerOptions,
): number => {
  if (options.radiusMode === 'uniform' || !component) return 0.5 * options.atomScale;
  return Math.max(component.atomicRadius, 0.35) * options.atomScale;
};

const isHydrogen = (site?: SiteSpec): boolean =>
  site?.species.every((component) => component.symbol === 'H') ?? false;

const atomVisible = (
  atom: AtomicSceneSpec['atomInstances'][number],
  site: SiteSpec | undefined,
  options: ViewerOptions,
): boolean =>
  options.showAtoms &&
  (options.showHydrogens || !isHydrogen(site)) &&
  (atom.visibility === 'base' ||
    atom.visibility === 'repeat' ||
    (atom.visibility === 'boundary' && options.showBoundaryAtoms) ||
    (atom.visibility === 'bonded' && options.showBondedOutside));

const project = (
  value: Vector3 | Vector3Tuple,
  camera: OrthographicCamera,
  width: number,
  height: number,
): ProjectedPoint => {
  const projected = (value instanceof Vector3 ? value.clone() : vector(value)).project(camera);
  return {
    x: ((projected.x + 1) * width) / 2,
    y: ((1 - projected.y) * height) / 2,
    depth: projected.z,
  };
};

const radiusPixels = (radius: number, camera: OrthographicCamera, height: number): number =>
  (radius * height * camera.zoom) / Math.max(camera.top - camera.bottom, 1e-9);

const arcPath = (cx: number, cy: number, radius: number, start: number, length: number): string => {
  if (length >= Math.PI * 2 - 1e-6) {
    return `<circle cx="${number(cx)}" cy="${number(cy)}" r="${number(radius)}"`;
  }
  const end = start + Math.max(length, 0.001);
  const fromX = cx + radius * Math.cos(start);
  const fromY = cy + radius * Math.sin(start);
  const toX = cx + radius * Math.cos(end);
  const toY = cy + radius * Math.sin(end);
  const largeArc = length > Math.PI ? 1 : 0;
  return `<path d="M ${number(cx)} ${number(cy)} L ${number(fromX)} ${number(fromY)} A ${number(radius)} ${number(radius)} 0 ${largeArc} 1 ${number(toX)} ${number(toY)} Z"`;
};

const segmentPath = (
  from: ProjectedPoint,
  to: ProjectedPoint,
  radius: number,
  roundStart = true,
  roundEnd = true,
): string => {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  if (length < 1e-6) {
    return `M ${number(from.x - radius)} ${number(from.y - radius)} L ${number(from.x + radius)} ${number(from.y - radius)} L ${number(from.x + radius)} ${number(from.y + radius)} L ${number(from.x - radius)} ${number(from.y + radius)} Z`;
  }
  const nx = (-dy / length) * radius;
  const ny = (dx / length) * radius;
  const endCap = roundEnd
    ? `A ${number(radius)} ${number(radius)} 0 0 0 ${number(to.x - nx)} ${number(to.y - ny)}`
    : `L ${number(to.x - nx)} ${number(to.y - ny)}`;
  const startCap = roundStart
    ? `A ${number(radius)} ${number(radius)} 0 0 0 ${number(from.x + nx)} ${number(from.y + ny)}`
    : `L ${number(from.x + nx)} ${number(from.y + ny)}`;
  return `M ${number(from.x + nx)} ${number(from.y + ny)} L ${number(to.x + nx)} ${number(to.y + ny)} ${endCap} L ${number(from.x - nx)} ${number(from.y - ny)} ${startCap} Z`;
};

const lightDirection2d = (camera: OrthographicCamera): { x: number; y: number } => {
  const view = KEY_LIGHT_DIRECTION.clone().applyQuaternion(camera.quaternion.clone().invert());
  const length = Math.hypot(view.x, view.y);
  return length < 0.12 ? { x: -0.62, y: -0.78 } : { x: view.x / length, y: -view.y / length };
};

const radialGradient = (
  id: string,
  center: ProjectedPoint,
  radius: number,
  base: string,
  input: VectorExportInput,
): string => {
  const light = lightDirection2d(input.camera);
  const focus = input.theme.id === 'materials' ? 0.34 : 0.29;
  const highlight = mixHex(base, [255, 255, 255], input.theme.id === 'materials' ? 0.82 : 0.67);
  const softHighlight = mixHex(base, [255, 255, 255], input.theme.id === 'materials' ? 0.32 : 0.22);
  const shadow = mixHex(base, [0, 0, 0], input.theme.id === 'materials' ? 0.26 : 0.31);
  const rim = mixHex(base, [0, 0, 0], input.theme.id === 'materials' ? 0.48 : 0.54);
  return `<radialGradient id="${id}" gradientUnits="userSpaceOnUse" cx="${number(center.x)}" cy="${number(center.y)}" r="${number(radius)}" fx="${number(center.x + light.x * radius * focus)}" fy="${number(center.y + light.y * radius * focus)}"><stop offset="0" stop-color="${highlight}"/><stop offset="0.24" stop-color="${softHighlight}"/><stop offset="0.56" stop-color="${base}"/><stop offset="0.83" stop-color="${shadow}"/><stop offset="1" stop-color="${rim}"/></radialGradient>`;
};

const linearCapsuleGradient = (
  id: string,
  from: ProjectedPoint,
  to: ProjectedPoint,
  radius: number,
  base: string,
): string => {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.max(Math.hypot(dx, dy), 1e-6);
  const nx = (-dy / length) * radius;
  const ny = (dx / length) * radius;
  const cx = (from.x + to.x) * 0.5;
  const cy = (from.y + to.y) * 0.5;
  return `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${number(cx + nx)}" y1="${number(cy + ny)}" x2="${number(cx - nx)}" y2="${number(cy - ny)}"><stop offset="0" stop-color="${mixHex(base, [0, 0, 0], 0.5)}"/><stop offset="0.2" stop-color="${mixHex(base, [255, 255, 255], 0.08)}"/><stop offset="0.44" stop-color="${mixHex(base, [255, 255, 255], 0.36)}"/><stop offset="0.7" stop-color="${base}"/><stop offset="1" stop-color="${mixHex(base, [0, 0, 0], 0.42)}"/></linearGradient>`;
};

const bondOffsets = (
  start: Vector3Tuple,
  end: Vector3Tuple,
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
  return (lanes === 2 ? [-0.5, 0.5] : [-1, 0, 1]).map((entry) =>
    perpendicular.clone().multiplyScalar(entry * spacing),
  );
};

const addBonds = (
  input: VectorExportInput,
  sites: Map<number, SiteSpec>,
  items: SvgItem[],
  definitions: string[],
): void => {
  if (!input.options.showBonds) return;
  const diameter = Math.max(
    radiusPixels(input.options.bondRadius * 2, input.camera, input.height),
    1,
  );
  for (const bond of input.scene.bondInstances) {
    const hydrogen =
      isHydrogen(sites.get(bond.fromSiteIndex)) || isHydrogen(sites.get(bond.toSiteIndex));
    if (hydrogen && !input.options.showHydrogens) continue;
    const lanes = input.options.showBondOrders
      ? Math.max(1, Math.min(3, Math.round(bond.order ?? 1)))
      : 1;
    for (const offset of bondOffsets(bond.start, bond.end, lanes, input.options.bondRadius)) {
      const start = vector(bond.start).add(offset);
      const end = vector(bond.end).add(offset);
      const midpoint = start.clone().lerp(end, 0.5);
      const halves = [
        {
          start,
          end: midpoint,
          site: sites.get(bond.fromSiteIndex),
          half: 'from' as const,
        },
        { start: midpoint, end, site: sites.get(bond.toSiteIndex), half: 'to' as const },
      ];
      for (const half of halves) {
        const visible =
          bond.visibility === 'base' ||
          input.options.showBondedOutside ||
          (!input.options.hideIncompleteBonds && half.half === 'from');
        if (!visible) continue;
        const from = project(half.start, input.camera, input.width, input.height);
        const to = project(half.end, input.camera, input.width, input.height);
        const base = siteColor(half.site?.species[0], input);
        const gradientId = `bond-gradient-${definitions.length}`;
        definitions.push(linearCapsuleGradient(gradientId, from, to, diameter * 0.5, base));
        const selected = input.selected?.kind === 'bond' && input.selected.id === bond.id;
        const outline = selected
          ? ` stroke="${input.theme.selection}" stroke-width="${number(Math.max(1.5, diameter * 0.12))}"`
          : '';
        items.push({
          // Preserve the average-depth painter's order, but never let a half-bond
          // paint over the atom it is attached to. The atom's higher priority
          // then hides the part of the tube that lies inside the projected sphere.
          depth: Math.max(
            (from.depth + to.depth) / 2,
            half.half === 'from' ? from.depth : to.depth,
          ),
          priority: 2,
          markup: `<path data-layer="bond" d="${segmentPath(from, to, diameter * 0.5, half.half === 'from', half.half === 'to')}" fill="url(#${gradientId})"${outline}/>`,
        });
      }
    }
  }
};

const addAtoms = (
  input: VectorExportInput,
  sites: Map<number, SiteSpec>,
  items: SvgItem[],
  definitions: string[],
): void => {
  for (const atom of input.scene.atomInstances) {
    const site = sites.get(atom.siteIndex);
    if (!site || !atomVisible(atom, site, input.options)) continue;
    const center = project(atom.position, input.camera, input.width, input.height);
    const total = site.species.reduce((sum, component) => sum + component.occupancy, 0);
    const records: Array<{ component: SiteSpec['species'][number] | null; occupancy: number }> = [
      ...site.species.map((component) => ({ component, occupancy: component.occupancy })),
    ];
    if (total < 0.999999) records.push({ component: null, occupancy: 1 - total });
    let cursor = 0;
    const pieces: string[] = [];
    let largestRadius = 0;
    for (const record of records) {
      const radius = radiusPixels(
        atomRadius(record.component, input.options),
        input.camera,
        input.height,
      );
      largestRadius = Math.max(largestRadius, radius);
      const base = record.component ? siteColor(record.component, input) : '#d1d1d1';
      const gradientId = `atom-gradient-${definitions.length}`;
      definitions.push(radialGradient(gradientId, center, radius, base, input));
      pieces.push(
        `${arcPath(center.x, center.y, radius, cursor * Math.PI * 2, record.occupancy * Math.PI * 2)} fill="url(#${gradientId})" stroke="${mixHex(base, [0, 0, 0], 0.46)}" stroke-width="${number(Math.max(0.55, radius * 0.018))}"/>`,
      );
      cursor += record.occupancy;
    }
    if (input.selected?.kind === 'atom' && input.selected.id === atom.id) {
      pieces.push(
        `<circle cx="${number(center.x)}" cy="${number(center.y)}" r="${number(largestRadius * 1.14)}" fill="none" stroke="${input.theme.selection}" stroke-width="${number(Math.max(2, largestRadius * 0.09))}"/>`,
      );
    }
    items.push({
      depth: center.depth,
      priority: 3,
      markup: `<g data-layer="atom">${pieces.join('')}</g>`,
    });
  }
};

const addCell = (input: VectorExportInput, items: SvgItem[]): void => {
  if (input.scene.kind !== 'crystal' || !input.options.showUnitCell) return;
  const { structure } = input.scene;
  const [a, b, c] = structure.lattice.map((entry, index) =>
    vector(entry).multiplyScalar(structure.repeat[index]),
  );
  const corners = [
    new Vector3(),
    a,
    b,
    c,
    a.clone().add(b),
    a.clone().add(c),
    b.clone().add(c),
    a.clone().add(b).add(c),
  ];
  const edges = [
    [0, 1],
    [0, 2],
    [0, 3],
    [1, 4],
    [1, 5],
    [2, 4],
    [2, 6],
    [3, 5],
    [3, 6],
    [4, 7],
    [5, 7],
    [6, 7],
  ];
  for (const [edgeIndex, [fromIndex, toIndex]] of edges.entries()) {
    const from = project(corners[fromIndex], input.camera, input.width, input.height);
    const to = project(corners[toIndex], input.camera, input.width, input.height);
    const projectedLength = Math.hypot(to.x - from.x, to.y - from.y);
    const segmentCount = Math.min(64, Math.max(1, Math.ceil(projectedLength / 10)));
    for (let segmentIndex = 0; segmentIndex < segmentCount; segmentIndex += 1) {
      const start = segmentIndex / segmentCount;
      const end = (segmentIndex + 1) / segmentCount;
      const segmentFrom = {
        x: from.x + (to.x - from.x) * start,
        y: from.y + (to.y - from.y) * start,
        depth: from.depth + (to.depth - from.depth) * start,
      };
      const segmentTo = {
        x: from.x + (to.x - from.x) * end,
        y: from.y + (to.y - from.y) * end,
        depth: from.depth + (to.depth - from.depth) * end,
      };
      items.push({
        // Use the farther endpoint as a conservative local depth. With short
        // segments this closely follows the 3D edge while ensuring a cell line
        // never paints over an atom located at either segment endpoint.
        depth: Math.max(segmentFrom.depth, segmentTo.depth),
        priority: 0,
        markup: `<line data-layer="cell" data-edge="${edgeIndex}" data-segment="${segmentIndex}" x1="${number(segmentFrom.x)}" y1="${number(segmentFrom.y)}" x2="${number(segmentTo.x)}" y2="${number(segmentTo.y)}" stroke="${input.theme.cell}" stroke-opacity="0.58" stroke-width="0.85"/>`,
      });
    }
  }
};

const addPolyhedra = (input: VectorExportInput, items: SvgItem[]): void => {
  if (!input.options.showPolyhedra) return;
  const opacity = Math.min(
    input.options.polyhedronOpacity * (input.theme.id === 'materials' ? 1.3 : 1),
    1,
  );
  for (const polyhedron of input.scene.polyhedra) {
    if (polyhedron.visibility !== 'base' && !input.options.showBondedOutside) continue;
    if (polyhedron.vertices.length < 4) continue;
    const geometry = new ConvexGeometry(polyhedron.vertices.map(vector));
    const positions = geometry.getAttribute('position');
    const base = rgbHex(polyhedron.color);
    for (let index = 0; index < positions.count; index += 3) {
      const world = [0, 1, 2].map((offset) =>
        new Vector3().fromBufferAttribute(positions, index + offset),
      );
      const projected = world.map((vertex) =>
        project(vertex, input.camera, input.width, input.height),
      );
      const normal = new Vector3()
        .crossVectors(world[1].clone().sub(world[0]), world[2].clone().sub(world[0]))
        .normalize();
      const intensity =
        0.62 +
        Math.max(0, normal.dot(KEY_LIGHT_DIRECTION)) * 0.46 +
        Math.max(0, normal.dot(FILL_LIGHT_DIRECTION)) * 0.12;
      items.push({
        depth: projected.reduce((sum, entry) => sum + entry.depth, 0) / 3,
        priority: 1,
        markup: `<polygon data-layer="polyhedron" points="${projected.map(point).join(' ')}" fill="${shadeHex(base, intensity)}" fill-opacity="${number(opacity)}" stroke="none"/>`,
      });
    }
    geometry.dispose();
  }
};

const arrowGlyph = (
  from: ProjectedPoint,
  to: ProjectedPoint,
  color: string,
  shaftWidth: number,
): string => {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  if (length < 1e-6) return '';
  const ux = dx / length;
  const uy = dy / length;
  const headLength = Math.min(length * 0.42, Math.max(shaftWidth * 3.1, 7));
  const headHalfWidth = Math.max(shaftWidth * 1.45, 4);
  const base: ProjectedPoint = {
    x: to.x - ux * headLength,
    y: to.y - uy * headLength,
    depth: to.depth,
  };
  const nx = -uy * headHalfWidth;
  const ny = ux * headHalfWidth;
  return `<path d="${segmentPath(from, base, shaftWidth * 0.5, false, false)}" fill="${color}"/><polygon points="${number(to.x)},${number(to.y)} ${number(base.x + nx)},${number(base.y + ny)} ${number(base.x - nx)},${number(base.y - ny)}" fill="${color}"/>`;
};

const addMagmoms = (
  input: VectorExportInput,
  sites: Map<number, SiteSpec>,
  items: SvgItem[],
): void => {
  if (!input.options.showMagmoms) return;
  for (const atom of input.scene.atomInstances) {
    const magmom = sites.get(atom.siteIndex)?.magmom;
    if (atom.visibility !== 'base' || !magmom) continue;
    const norm = Math.hypot(...magmom);
    if (norm < 1e-12) continue;
    const length = Math.min(Math.max(norm * 0.3, 0.7), 2.4);
    const end = vector(atom.position).add(vector(magmom).multiplyScalar(length / norm));
    const from = project(atom.position, input.camera, input.width, input.height);
    const to = project(end, input.camera, input.width, input.height);
    const width = Math.max(2, radiusPixels(0.11, input.camera, input.height));
    items.push({
      depth: (from.depth + to.depth) / 2 - 0.0001,
      priority: 4,
      markup: `<g data-layer="magmom">${arrowGlyph(from, to, '#3563be', width)}</g>`,
    });
  }
};

const orientationAxes = (input: VectorExportInput): string => {
  if (!input.options.showAxes) return '';
  const size = Math.min(118, input.height * 0.24);
  const cx = 18 + size / 2;
  const cy = input.height - 18 - size / 2;
  const length = size * 0.31;
  const inverse = input.camera.quaternion.clone().invert();
  const colors =
    input.theme.id === 'materials'
      ? ['#f01818', '#00b82e', '#143cff']
      : ['#ff5c5c', '#57cf72', '#4d8cff'];
  const labels = ['a', 'b', 'c'];
  const arrows = input.axisDirections.flatMap((direction, index) => {
    const view = direction.clone().normalize().applyQuaternion(inverse);
    const projectedLength = Math.hypot(view.x, view.y);
    if (projectedLength < 1e-6) return [];
    const ux = view.x / projectedLength;
    const uy = -view.y / projectedLength;
    const to = { x: cx + ux * length, y: cy + uy * length, depth: 0 };
    const shaftWidth = Math.max(2.4, size * 0.035);
    return [
      `<g>${arrowGlyph({ x: cx, y: cy, depth: 0 }, to, colors[index], shaftWidth)}<text x="${number(to.x + ux * 9)}" y="${number(to.y + uy * 9)}" fill="${colors[index]}" font-family="serif" font-size="${number(Math.max(10, size * 0.12))}" font-style="italic" text-anchor="middle" dominant-baseline="central">${labels[index]}</text></g>`,
    ];
  });
  return `<g data-layer="orientation-axes" aria-label="orientation axes">${arrows.join('')}</g>`;
};

export const buildVectorSvg = (input: VectorExportInput): string => {
  const width = Math.max(Math.round(input.width), 1);
  const height = Math.max(Math.round(input.height), 1);
  input.camera.updateMatrixWorld(true);
  input.camera.updateProjectionMatrix();
  const normalizedInput = { ...input, width, height };
  const sites = new Map(input.scene.sites.map((site) => [site.siteIndex, site]));
  const items: SvgItem[] = [];
  const definitions: string[] = [];
  addPolyhedra(normalizedInput, items);
  addCell(normalizedInput, items);
  addBonds(normalizedInput, sites, items, definitions);
  addAtoms(normalizedInput, sites, items, definitions);
  addMagmoms(normalizedInput, sites, items);
  items.sort((first, second) => second.depth - first.depth || first.priority - second.priority);

  const background = input.options.background ?? input.theme.background;
  return `<svg xmlns="${XMLNS}" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="Exported atomic structure"><defs>${definitions.join('')}</defs><rect width="${width}" height="${height}" fill="${background}"/>${items.map((entry) => entry.markup).join('')}${orientationAxes(normalizedInput)}</svg>`;
};

export const svgBlob = (svg: string): Blob =>
  new Blob([`<?xml version="1.0" encoding="UTF-8"?>\n${svg}`], {
    type: 'image/svg+xml;charset=utf-8',
  });

const pdfOptions = (width: number, height: number) => ({
  unit: 'pt' as const,
  format: [width, height] as [number, number],
  orientation: width >= height ? ('landscape' as const) : ('portrait' as const),
  compress: true,
});

export const svgToPdfBlob = async (svg: string, width: number, height: number): Promise<Blob> => {
  const [{ jsPDF }] = await Promise.all([import('jspdf'), import('svg2pdf.js')]);
  const element = new DOMParser().parseFromString(svg, 'image/svg+xml')
    .documentElement as unknown as SVGElement;
  const pdf = new jsPDF(pdfOptions(width, height));
  await pdf.svg(element, { x: 0, y: 0, width, height });
  return pdf.output('blob');
};

export const pngToPdfBlob = async (png: Blob, width: number, height: number): Promise<Blob> => {
  const { jsPDF } = await import('jspdf');
  const pdf = new jsPDF(pdfOptions(width, height));
  pdf.addImage(
    new Uint8Array(await png.arrayBuffer()),
    'PNG',
    0,
    0,
    width,
    height,
    undefined,
    'FAST',
  );
  return pdf.output('blob');
};
