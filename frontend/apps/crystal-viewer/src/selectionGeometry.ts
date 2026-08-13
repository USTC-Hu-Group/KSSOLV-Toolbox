export interface ScreenPoint {
  x: number;
  y: number;
}

export interface ProjectedAtom extends ScreenPoint {
  id: string;
}

export const rectanglePolygon = (start: ScreenPoint, end: ScreenPoint): ScreenPoint[] => [
  { x: Math.min(start.x, end.x), y: Math.min(start.y, end.y) },
  { x: Math.max(start.x, end.x), y: Math.min(start.y, end.y) },
  { x: Math.max(start.x, end.x), y: Math.max(start.y, end.y) },
  { x: Math.min(start.x, end.x), y: Math.max(start.y, end.y) },
];

export const pointInPolygon = (point: ScreenPoint, polygon: readonly ScreenPoint[]): boolean => {
  if (polygon.length < 3) return false;
  let inside = false;
  for (let index = 0, previous = polygon.length - 1; index < polygon.length; previous = index++) {
    const a = polygon[index];
    const b = polygon[previous];
    const crosses =
      a.y > point.y !== b.y > point.y &&
      point.x < ((b.x - a.x) * (point.y - a.y)) / (b.y - a.y || Number.EPSILON) + a.x;
    if (crosses) inside = !inside;
  }
  return inside;
};

export const atomIdsInPolygon = (
  atoms: readonly ProjectedAtom[],
  polygon: readonly ScreenPoint[],
): string[] => atoms.filter((atom) => pointInPolygon(atom, polygon)).map((atom) => atom.id);
