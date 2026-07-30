import { BufferGeometry, Color, LineBasicMaterial, LineSegments, Vector3 } from 'three';

import type { CrystalSceneSpec } from '../../scene/types';
import type { ViewerTheme } from '../../themes/themes';

const add = (a: Vector3, b: Vector3): Vector3 => a.clone().add(b);

export class CellLayer {
  readonly lines: LineSegments;

  constructor(scene: CrystalSceneSpec, theme: ViewerTheme) {
    const [aValue, bValue, cValue] = scene.structure.lattice;
    const origin = new Vector3();
    const a = new Vector3(...aValue).multiplyScalar(scene.structure.repeat[0]);
    const b = new Vector3(...bValue).multiplyScalar(scene.structure.repeat[1]);
    const c = new Vector3(...cValue).multiplyScalar(scene.structure.repeat[2]);
    const ab = add(a, b);
    const ac = add(a, c);
    const bc = add(b, c);
    const abc = add(ab, c);
    const segments = [
      origin,
      a,
      origin,
      b,
      origin,
      c,
      a,
      ab,
      a,
      ac,
      b,
      ab,
      b,
      bc,
      c,
      ac,
      c,
      bc,
      ab,
      abc,
      ac,
      abc,
      bc,
      abc,
    ];
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
