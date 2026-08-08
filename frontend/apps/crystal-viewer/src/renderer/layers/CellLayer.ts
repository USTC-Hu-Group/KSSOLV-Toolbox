import { BufferGeometry, Color, LineBasicMaterial, LineSegments } from 'three';

import type { CrystalSceneSpec } from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';
import { repeatedCellEdges } from '../cellEdges';

export class CellLayer {
  readonly lines: LineSegments;

  constructor(scene: CrystalSceneSpec, theme: ViewerTheme) {
    const segments = repeatedCellEdges(scene.structure.lattice, scene.structure.repeat).flat();
    const geometry = new BufferGeometry().setFromPoints(segments);
    const material = new LineBasicMaterial({
      color: new Color(theme.cell),
      transparent: true,
      opacity: 0.86,
    });
    this.lines = new LineSegments(geometry, material);
    this.lines.name = 'crystal-unit-cell';
  }

  setVisible(visible: boolean): void {
    this.lines.visible = visible;
  }

  updateTheme(theme: ViewerTheme): void {
    (this.lines.material as LineBasicMaterial).color.set(theme.cell);
  }

  dispose(): void {
    this.lines.geometry.dispose();
    (this.lines.material as LineBasicMaterial).dispose();
  }
}
