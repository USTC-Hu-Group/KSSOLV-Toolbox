import {
  BufferGeometry,
  DoubleSide,
  Float32BufferAttribute,
  Group,
  Mesh,
  MeshBasicMaterial,
  type Material,
} from 'three';
import { Line2 } from 'three/examples/jsm/lines/Line2.js';
import { LineGeometry } from 'three/examples/jsm/lines/LineGeometry.js';
import { LineMaterial } from 'three/examples/jsm/lines/LineMaterial.js';
import { LineSegments2 } from 'three/examples/jsm/lines/LineSegments2.js';
import { LineSegmentsGeometry } from 'three/examples/jsm/lines/LineSegmentsGeometry.js';

import type { ViewerTheme } from '../../themes/themes';
import { angleArcPoints, type MeasurementAnnotation } from '../measurementAnnotations';

export const measurementLineWidths = {
  segment: 3,
  angleArc: 4,
  planeOutline: 2.5,
} as const;

type LineMaterialWithWidth = LineMaterial & { linewidth: number };

const createThickLineMaterial = (color: string, linewidth: number, opacity = 1): LineMaterial => {
  const material = new LineMaterial({
    color,
    transparent: opacity < 1,
    opacity,
    depthTest: false,
    depthWrite: false,
  });
  // The runtime supports screen-space linewidth, although the Three.js
  // declaration currently omits the accessor from LineMaterial.
  (material as LineMaterialWithWidth).linewidth = linewidth;
  return material;
};

export class MeasurementLayer {
  readonly group = new Group();
  private annotations: MeasurementAnnotation[] = [];

  constructor(private theme: ViewerTheme) {
    this.group.name = 'measurement-annotations';
  }

  setAnnotations(annotations: MeasurementAnnotation[]): void {
    this.annotations = annotations;
    this.rebuild();
  }

  updateTheme(theme: ViewerTheme): void {
    this.theme = theme;
    this.rebuild();
  }

  dispose(): void {
    this.clear();
  }

  private rebuild(): void {
    this.clear();
    for (const annotation of this.annotations) {
      const item = new Group();
      item.name = annotation.id;
      const lines = this.createSegments(annotation);
      if (lines) item.add(lines);
      if (annotation.kind === 'angle') {
        const arc = this.createArc(annotation);
        if (arc) item.add(arc);
      }
      for (const plane of this.createPlanes(annotation)) item.add(plane);
      this.group.add(item);
    }
  }

  private createSegments(annotation: MeasurementAnnotation): LineSegments2 | undefined {
    if (annotation.segments.length === 0) return undefined;
    const geometry = new LineSegmentsGeometry().setPositions(
      annotation.segments.flatMap((segment) => [...segment]),
    );
    const material = createThickLineMaterial(
      this.theme.accent,
      measurementLineWidths.segment,
      0.94,
    );
    const lines = new LineSegments2(geometry, material);
    lines.renderOrder = 40;
    return lines;
  }

  private createArc(annotation: MeasurementAnnotation): Line2 | undefined {
    const points = angleArcPoints(annotation);
    if (points.length < 2) return undefined;
    const geometry = new LineGeometry().setPositions(points.flat());
    const line = new Line2(
      geometry,
      createThickLineMaterial(this.theme.selection, measurementLineWidths.angleArc),
    );
    line.renderOrder = 41;
    return line;
  }

  private createPlanes(annotation: MeasurementAnnotation): Group[] {
    const points = annotation.planePoints;
    if (points.length < 3) return [];
    const planes: Group[] = [];
    const planeCount =
      (annotation.kind === 'plane_plane' || annotation.kind === 'dihedral') && points.length >= 6
        ? 2
        : 1;
    for (let index = 0; index < planeCount; index += 1) {
      const triangle = points.slice(index * 3, index * 3 + 3);
      const candidate = annotation.candidatePlaneIndices?.includes(index) ?? false;
      const geometry = new BufferGeometry();
      geometry.setAttribute('position', new Float32BufferAttribute(triangle.flat(), 3));
      geometry.setIndex([0, 1, 2]);
      geometry.computeVertexNormals();
      const material = new MeshBasicMaterial({
        color: index === 0 ? this.theme.accent : this.theme.selection,
        transparent: true,
        opacity: candidate ? 0.13 : annotation.kind === 'dihedral' ? 0.34 : 0.22,
        depthWrite: false,
        depthTest: false,
        side: DoubleSide,
      });
      const plane = new Mesh(geometry, material);
      plane.renderOrder = 39;
      const outlineGeometry = new LineGeometry().setPositions([
        ...triangle[0],
        ...triangle[1],
        ...triangle[2],
        ...triangle[0],
      ]);
      const outline = new Line2(
        outlineGeometry,
        createThickLineMaterial(
          index === 0 ? this.theme.accent : this.theme.selection,
          measurementLineWidths.planeOutline,
          candidate ? 0.62 : 0.96,
        ),
      );
      outline.renderOrder = 40;
      const group = new Group();
      group.add(plane, outline);
      planes.push(group);
    }
    return planes;
  }

  private clear(): void {
    const geometries = new Set<BufferGeometry>();
    const materials = new Set<Material>();
    this.group.traverse((object) => {
      if (object instanceof Mesh) {
        geometries.add(object.geometry);
        const entries = Array.isArray(object.material) ? object.material : [object.material];
        entries.forEach((material) => materials.add(material));
      }
    });
    this.group.clear();
    geometries.forEach((geometry) => geometry.dispose());
    materials.forEach((material) => material.dispose());
  }
}
