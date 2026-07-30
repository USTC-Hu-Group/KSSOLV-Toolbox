import type { ThemeId } from '../scene/types';

export interface ViewerTheme {
  id: ThemeId;
  label: string;
  background: string;
  foreground: string;
  muted: string;
  panel: string;
  panelBorder: string;
  accent: string;
  selection: string;
  cell: string;
  atom: {
    model: 'physical' | 'phong';
    shininess: number;
    metalness: number;
    roughness: number;
    clearcoat: number;
    clearcoatRoughness: number;
    ior: number;
    reflectivity: number;
    specularIntensity: number;
    sheen: number;
    transmission: number;
    thickness: number;
    opacity: number;
  };
  bond: {
    metalness: number;
    roughness: number;
    clearcoat: number;
    clearcoatRoughness: number;
  };
}

export const themes: Record<ThemeId, ViewerTheme> = {
  pretty: {
    id: 'pretty',
    label: 'Pretty Lattice',
    background: '#fafafa',
    foreground: '#202124',
    muted: '#70757a',
    panel: 'rgba(255, 255, 255, 0.88)',
    panelBorder: 'rgba(30, 34, 40, 0.12)',
    accent: '#246bfd',
    selection: '#e6b800',
    cell: '#44474d',
    atom: {
      model: 'phong',
      shininess: 110,
      metalness: 0.08,
      roughness: 0.28,
      clearcoat: 0.75,
      clearcoatRoughness: 0.18,
      ior: 1.5,
      reflectivity: 0.5,
      specularIntensity: 1,
      sheen: 0,
      transmission: 0,
      thickness: 0,
      opacity: 1,
    },
    bond: {
      metalness: 0.04,
      roughness: 0.38,
      clearcoat: 0,
      clearcoatRoughness: 0,
    },
  },
  materials: {
    id: 'materials',
    label: 'Materials Project',
    background: '#ffffff',
    foreground: '#242526',
    muted: '#666d74',
    panel: 'rgba(255, 255, 255, 0.96)',
    panelBorder: '#d8dde3',
    accent: '#1565c0',
    selection: '#4b8dff',
    cell: '#555555',
    atom: {
      model: 'phong',
      shininess: 155,
      metalness: 0,
      roughness: 0.055,
      clearcoat: 1,
      clearcoatRoughness: 0.012,
      ior: 1.52,
      reflectivity: 1,
      specularIntensity: 1,
      sheen: 0,
      transmission: 0.045,
      thickness: 0.32,
      opacity: 1,
    },
    bond: {
      metalness: 0,
      roughness: 0.28,
      clearcoat: 0.45,
      clearcoatRoughness: 0.2,
    },
  },
};
