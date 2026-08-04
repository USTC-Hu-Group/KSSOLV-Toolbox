import { OrthographicCamera, Vector3 } from 'three';
import * as UTIF from 'utif';
import { describe, expect, it } from 'vitest';

import { createDebugScene } from '../scene/debugScene';
import { defaultViewerOptions } from '../scene/types';
import { themes } from '../themes/themes';
import {
  buildVectorSvg,
  flipRgbaRows,
  pngToPdfBlob,
  rgbaToTiffBlob,
  svgBlob,
  svgToPdfBlob,
} from './imageExport';

const camera = (): OrthographicCamera => {
  const value = new OrthographicCamera(-8, 8, 6, -6, 0.01, 100);
  value.position.set(12, 11, 14);
  value.up.set(0, 0, 1);
  value.lookAt(new Vector3(2.82, 2.82, 2.82));
  value.updateMatrixWorld(true);
  value.updateProjectionMatrix();
  return value;
};

const exportSvg = (overrides: Partial<ReturnType<typeof defaultViewerOptions>> = {}): string => {
  const options = { ...defaultViewerOptions(), ...overrides };
  return buildVectorSvg({
    scene: createDebugScene(),
    options,
    theme: themes[options.theme],
    camera: camera(),
    width: 800,
    height: 600,
    axisDirections: [new Vector3(1, 0, 0), new Vector3(0, 1, 0), new Vector3(0, 0, 1)],
  });
};

describe('vector image export', () => {
  it('encodes lossless TIFF RGBA pixels with the correct orientation', async () => {
    const bottomUp = new Uint8Array([
      0, 0, 255, 255, 255, 255, 255, 255, 255, 0, 0, 255, 0, 255, 0, 255,
    ]);
    const topDown = flipRgbaRows(bottomUp, 2, 2);
    expect([...topDown]).toEqual([
      255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255,
    ]);

    const blob = rgbaToTiffBlob(topDown, 2, 2);
    const buffer = await blob.arrayBuffer();
    const [ifd] = UTIF.decode(buffer);
    UTIF.decodeImage(buffer, ifd);

    expect(blob.type).toBe('image/tiff');
    expect(new Uint8Array(buffer).slice(0, 4)).toEqual(new Uint8Array([77, 77, 0, 42]));
    expect(ifd.width).toBe(2);
    expect(ifd.height).toBe(2);
    expect([...UTIF.toRGBA8(ifd)]).toEqual([...topDown]);
  });

  it('rejects inconsistent TIFF pixel dimensions', () => {
    expect(() => flipRgbaRows(new Uint8Array(3), 1, 1)).toThrow(/dimensions/);
    expect(() => rgbaToTiffBlob(new Uint8Array(3), 1, 1)).toThrow(/dimensions/);
  });

  it('builds a standalone vector scene without embedded raster images', async () => {
    const svg = exportSvg();
    const document = new DOMParser().parseFromString(svg, 'image/svg+xml');

    expect(document.documentElement.tagName).toBe('svg');
    expect(document.querySelector('parsererror')).toBeNull();
    expect(document.querySelectorAll('circle').length).toBeGreaterThan(1);
    expect(document.querySelectorAll('line').length).toBeGreaterThan(10);
    expect(document.querySelectorAll('polygon').length).toBeGreaterThan(0);
    expect(document.querySelectorAll('radialGradient').length).toBeGreaterThan(1);
    expect(document.querySelectorAll('linearGradient').length).toBeGreaterThan(1);
    expect(document.querySelectorAll('[data-layer="bond"]')).not.toHaveLength(0);
    expect(document.querySelector('image')).toBeNull();
    expect(document.querySelector('filter')).toBeNull();
    expect(document.querySelector('marker')).toBeNull();

    const blob = svgBlob(svg);
    expect(blob.type).toBe('image/svg+xml;charset=utf-8');
    expect(await blob.text()).toContain('<?xml version="1.0"');
  });

  it('honors layer visibility in exported vector images', () => {
    const svg = exportSvg({
      showAtoms: false,
      showBonds: false,
      showUnitCell: false,
      showPolyhedra: false,
      showAxes: false,
      showMagmoms: false,
    });
    const document = new DOMParser().parseFromString(svg, 'image/svg+xml');

    expect(document.querySelectorAll('svg > :not(defs):not(rect)')).toHaveLength(0);
    expect(document.querySelectorAll('rect')).toHaveLength(1);
  });

  it('exports every unit-cell edge as locally depth-sorted segments', () => {
    const svg = exportSvg({
      showAtoms: false,
      showBonds: false,
      showUnitCell: true,
      showPolyhedra: false,
      showAxes: false,
      showMagmoms: false,
    });
    const document = new DOMParser().parseFromString(svg, 'image/svg+xml');
    const segments = [...document.querySelectorAll('svg > line[data-layer="cell"]')];
    const edges = new Set(segments.map((segment) => segment.getAttribute('data-edge')));

    expect(edges.size).toBe(12);
    expect(segments.length).toBeGreaterThan(12);
  });

  it('uses subdued unit-cell lines and borderless polyhedron faces', () => {
    const document = new DOMParser().parseFromString(exportSvg(), 'image/svg+xml');
    const cellSegments = document.querySelectorAll('[data-layer="cell"]');
    const polyhedronFaces = document.querySelectorAll('[data-layer="polyhedron"]');

    expect(cellSegments.length).toBeGreaterThan(0);
    for (const segment of cellSegments) {
      expect(segment.getAttribute('stroke-opacity')).toBe('0.58');
      expect(segment.getAttribute('stroke-width')).toBe('0.85');
    }
    expect(polyhedronFaces.length).toBeGreaterThan(0);
    for (const face of polyhedronFaces) {
      expect(face.getAttribute('stroke')).toBe('none');
      expect(face.hasAttribute('stroke-width')).toBe(false);
    }
  });

  it('paints unit-cell segments behind atoms at shared projected endpoints', () => {
    const document = new DOMParser().parseFromString(
      exportSvg({ showBonds: false, showPolyhedra: false, showAxes: false }),
      'image/svg+xml',
    );
    const layers = [...document.documentElement.children];
    const cellSegments = [...document.querySelectorAll('line[data-layer="cell"]')];
    let sharedEndpoints = 0;

    for (const atom of document.querySelectorAll('[data-layer="atom"]')) {
      const circle = atom.querySelector('circle');
      if (!circle) continue;
      const cx = Number(circle.getAttribute('cx'));
      const cy = Number(circle.getAttribute('cy'));
      for (const segment of cellSegments) {
        const touchesAtom =
          (Math.abs(Number(segment.getAttribute('x1')) - cx) < 0.02 &&
            Math.abs(Number(segment.getAttribute('y1')) - cy) < 0.02) ||
          (Math.abs(Number(segment.getAttribute('x2')) - cx) < 0.02 &&
            Math.abs(Number(segment.getAttribute('y2')) - cy) < 0.02);
        if (!touchesAtom) continue;
        sharedEndpoints += 1;
        expect(layers.indexOf(segment)).toBeLessThan(layers.indexOf(atom));
      }
    }

    expect(sharedEndpoints).toBeGreaterThan(0);
  });

  it('uses unique PDF-safe gradients and pure-path orientation arrows', () => {
    const document = new DOMParser().parseFromString(exportSvg(), 'image/svg+xml');
    const gradients = [...document.querySelectorAll('radialGradient, linearGradient')];
    const ids = gradients.map((gradient) => gradient.id);

    expect(new Set(ids).size).toBe(ids.length);
    for (const painted of document.querySelectorAll('[fill^="url(#"]')) {
      const id = painted.getAttribute('fill')?.slice(5, -1);
      expect(id && document.getElementById(id)).not.toBeNull();
    }
    const axes = document.querySelector('[data-layer="orientation-axes"]');
    expect(axes?.querySelectorAll('path').length).toBeGreaterThan(0);
    expect(axes?.querySelectorAll('polygon').length).toBeGreaterThan(0);
    expect(axes?.querySelector('circle')).toBeNull();
    for (const shaft of axes?.querySelectorAll('path') ?? []) {
      expect(shaft.getAttribute('d')).not.toMatch(/\bA\b/);
    }
  });

  it('joins two-color bonds with flat midpoint caps', () => {
    const document = new DOMParser().parseFromString(exportSvg(), 'image/svg+xml');
    const bonds = document.querySelectorAll('[data-layer="bond"]');

    expect(bonds.length).toBeGreaterThan(0);
    for (const bond of bonds) {
      const arcs = bond.getAttribute('d')?.match(/\bA\b/g) ?? [];
      expect(arcs).toHaveLength(1);
    }
  });

  it('paints each half-bond behind the atom at its connected endpoint', () => {
    const scene = createDebugScene();
    const center: [number, number, number] = [2.82, 2.82, 2.82];
    const towardCamera: [number, number, number] = [5, 5, 5];
    scene.atomInstances = [{ ...scene.atomInstances[0], position: center, visibility: 'base' }];
    scene.bondInstances = [
      {
        ...scene.bondInstances[0],
        start: center,
        end: towardCamera,
        visibility: 'bonded',
      },
    ];
    const options = {
      ...defaultViewerOptions(),
      showUnitCell: false,
      showPolyhedra: false,
      showAxes: false,
      showBondedOutside: false,
      hideIncompleteBonds: false,
    };
    const svg = buildVectorSvg({
      scene,
      options,
      theme: themes[options.theme],
      camera: camera(),
      width: 800,
      height: 600,
      axisDirections: [new Vector3(1, 0, 0), new Vector3(0, 1, 0), new Vector3(0, 0, 1)],
    });
    const document = new DOMParser().parseFromString(svg, 'image/svg+xml');
    const layers = [...document.documentElement.children]
      .map((element) => element.getAttribute('data-layer'))
      .filter(Boolean);

    expect(layers).toEqual(['bond', 'atom']);
  });

  it('shades polyhedron faces from their surface normals', () => {
    const document = new DOMParser().parseFromString(exportSvg(), 'image/svg+xml');
    const fills = new Set(
      [...document.querySelectorAll('[data-layer="polyhedron"]')].map((face) =>
        face.getAttribute('fill'),
      ),
    );

    expect(fills.size).toBeGreaterThan(1);
  });

  it('converts the gradient scene to a vector PDF document', async () => {
    const pdf = await svgToPdfBlob(exportSvg(), 800, 600);
    const bytes = await pdf.arrayBuffer();
    const header = new TextDecoder().decode(bytes.slice(0, 5));
    const content = new TextDecoder('latin1').decode(bytes);

    expect(pdf.type).toBe('application/pdf');
    expect(header).toBe('%PDF-');
    expect(pdf.size).toBeGreaterThan(1_000);
    expect(content).not.toContain('/Subtype /Image');
  });

  it('embeds a lossless PNG in a raster PDF document', async () => {
    const encoded =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    const bytes = Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0));
    const pdf = await pngToPdfBlob(new Blob([bytes], { type: 'image/png' }), 800, 600);
    const pdfBytes = await pdf.arrayBuffer();
    const header = new TextDecoder().decode(pdfBytes.slice(0, 5));
    const content = new TextDecoder('latin1').decode(pdfBytes);

    expect(pdf.type).toBe('application/pdf');
    expect(header).toBe('%PDF-');
    expect(pdf.size).toBeGreaterThan(500);
    expect(content).toContain('/Subtype /Image');
  });
});
