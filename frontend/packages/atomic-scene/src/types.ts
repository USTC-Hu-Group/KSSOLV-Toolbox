/** Shared atomic scene contract used by crystal and volume viewers. */
export type Vector3Tuple = [number, number, number];
export type Matrix3Tuple = [Vector3Tuple, Vector3Tuple, Vector3Tuple];
export type RgbTuple = [number, number, number];
export type ImageOffset = [number, number, number];

export type BondAlgorithm =
  | "CrystalNN"
  | "CutOffDictNN"
  | "JmolNN"
  | "MinimumDistanceNN"
  | "MinimumOKeeffeNN"
  | "EconNN"
  | "BrunnerNNReciprocal";
export type MoleculeBondAlgorithm = "Auto" | "Source" | "OpenBabelNN" | "None";
export type AtomicBondAlgorithm = BondAlgorithm | MoleculeBondAlgorithm;
export type AtomVisibility = "base" | "boundary" | "bonded" | "repeat";

export interface SpeciesComponent {
  symbol: string;
  occupancy: number;
  atomicNumber: number;
  colorVesta: RgbTuple;
  colorJmol: RgbTuple;
  atomicRadius: number;
}

export interface SiteSpec {
  id: string;
  siteIndex: number;
  label: string;
  species: SpeciesComponent[];
  fractional?: Vector3Tuple;
  cartesian: Vector3Tuple;
  magmom?: Vector3Tuple;
}

export interface AtomInstanceSpec {
  id: string;
  siteId: string;
  siteIndex: number;
  imageOffset: ImageOffset;
  position: Vector3Tuple;
  visibility: AtomVisibility;
}

export interface BondRelationSpec {
  id: string;
  fromSiteIndex: number;
  toSiteIndex: number;
  relativeImage: ImageOffset;
  distance: number;
  weight: number | null;
  order?: number;
  origin?: "source" | "OpenBabelNN";
}

export interface BondInstanceSpec {
  id: string;
  relationId: string;
  fromSiteIndex: number;
  toSiteIndex: number;
  fromImage: ImageOffset;
  toImage: ImageOffset;
  start: Vector3Tuple;
  end: Vector3Tuple;
  distance: number;
  visibility: "base" | "bonded";
  order?: number;
  origin?: "source" | "OpenBabelNN";
}

export interface PolyhedronSpec {
  id: string;
  centerSiteIndex: number;
  center: Vector3Tuple;
  vertices: Vector3Tuple[];
  color: RgbTuple;
  visibility: "base" | "bonded";
}

export interface SceneWarning {
  code: string;
  message: string;
  severity: "info" | "warning" | "error";
}

export interface AtomicSceneBase {
  schemaVersion: "2.0";
  kind: "crystal" | "molecule";
  requestId: string;
  sites: SiteSpec[];
  atomInstances: AtomInstanceSpec[];
  bondRelations: BondRelationSpec[];
  bondInstances: BondInstanceSpec[];
  polyhedra: PolyhedronSpec[];
  analysis: {
    algorithm: AtomicBondAlgorithm;
    parameters: Record<string, unknown>;
    source: "matgenlab";
    sourceVersion: string;
    elapsedMilliseconds: number;
  };
  warnings: SceneWarning[];
}

export interface CrystalSceneSpec extends AtomicSceneBase {
  kind: "crystal";
  structure: {
    formula: string;
    lattice: Matrix3Tuple;
    periodic: [boolean, boolean, boolean];
    repeat: [number, number, number];
    siteCount: number;
    isOrdered: boolean;
  };
}

export interface MoleculeSceneSpec extends AtomicSceneBase {
  kind: "molecule";
  molecule: {
    formula: string;
    atomCount: number;
    isOrdered: boolean;
    charge: number;
    spinMultiplicity: number;
    inputFormat: string;
    frameIndex: number;
    frameCount: number;
  };
}

export type AtomicSceneSpec = CrystalSceneSpec | MoleculeSceneSpec;

export type ThemeId = "materials" | "gleamoe-premiror";
export type RadiusMode = "uniform" | "atomic";
export type ColorMode = "vesta" | "jmol";
export type RenderMode = "fast" | "quality";
export type RenderQualityLevel = "balanced" | "high" | "ultra";

export interface ViewerOptions {
  theme: ThemeId;
  colorMode: ColorMode;
  radiusMode: RadiusMode;
  renderMode: RenderMode;
  renderQuality: RenderQualityLevel;
  showAtoms: boolean;
  showBonds: boolean;
  showHydrogens: boolean;
  showBondOrders: boolean;
  showUnitCell: boolean;
  showPolyhedra: boolean;
  showAxes: boolean;
  showBoundaryAtoms: boolean;
  showBondedOutside: boolean;
  hideIncompleteBonds: boolean;
  showMagmoms: boolean;
  showStatistics: boolean;
  continuousMeasurement: boolean;
  atomScale: number;
  bondRadius: number;
  polyhedronOpacity: number;
  background: string | null;
}

export const defaultViewerOptions = (): ViewerOptions => ({
  theme: "materials",
  colorMode: "vesta",
  radiusMode: "atomic",
  renderMode: "fast",
  renderQuality: "high",
  showAtoms: true,
  showBonds: true,
  showHydrogens: true,
  showBondOrders: true,
  showUnitCell: true,
  showPolyhedra: true,
  showAxes: true,
  showBoundaryAtoms: true,
  showBondedOutside: true,
  hideIncompleteBonds: true,
  showMagmoms: true,
  showStatistics: false,
  continuousMeasurement: false,
  atomScale: 0.44,
  bondRadius: 0.1,
  polyhedronOpacity: 0.28,
  background: null,
});

export interface SelectionInfo {
  kind: "atom" | "bond";
  id: string;
  site?: SiteSpec;
  atom?: AtomInstanceSpec;
  bond?: BondInstanceSpec;
  clientX: number;
  clientY: number;
}

export interface AtomHoverInfo {
  atom: AtomInstanceSpec;
  site: SiteSpec;
  clientX: number;
  clientY: number;
}

export interface CameraSnapshot {
  position: Vector3Tuple;
  target: Vector3Tuple;
  up: Vector3Tuple;
  zoom: number;
}

export interface RendererStatistics {
  atoms: number;
  bonds: number;
  polyhedra: number;
  drawCalls: number;
  triangles: number;
  p95FrameMilliseconds: number;
}
