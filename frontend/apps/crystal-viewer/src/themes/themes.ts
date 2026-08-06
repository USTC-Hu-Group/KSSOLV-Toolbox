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
    anisotropy: number;
    iridescence: number;
    iridescenceIOR: number;
    attenuationColor: string;
    attenuationDistance: number;
  };
  bond: {
    metalness: number;
    roughness: number;
    clearcoat: number;
    clearcoatRoughness: number;
  };
}

export const themes: Record<ThemeId, ViewerTheme> = {
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
      anisotropy: 0,
      iridescence: 0,
      iridescenceIOR: 1.3,
      attenuationColor: '#ffffff',
      attenuationDistance: Infinity,
    },
    bond: {
      metalness: 0,
      roughness: 0.28,
      clearcoat: 0.45,
      clearcoatRoughness: 0.2,
    },
  },
  'gleamoe-premiror': {
    id: 'gleamoe-premiror',
    label: 'Gleamoe Noir',
    background: '#07101d',
    foreground: '#f1f7ff',
    muted: '#9eb0c5',
    panel: 'rgba(8, 18, 32, 0.82)',
    panelBorder: 'rgba(150, 207, 255, 0.2)',
    accent: '#66d9ff',
    selection: '#ffd166',
    cell: '#85bde7',
    atom: {
      model: 'physical',
      shininess: 190,
      metalness: 0.16,
      roughness: 0.11,
      clearcoat: 1,
      clearcoatRoughness: 0.045,
      ior: 1.62,
      reflectivity: 1,
      specularIntensity: 1.15,
      sheen: 0.12,
      transmission: 0.035,
      thickness: 0.45,
      opacity: 1,
      anisotropy: 0.18,
      iridescence: 0.08,
      iridescenceIOR: 1.42,
      attenuationColor: '#d8efff',
      attenuationDistance: 3.5,
    },
    bond: {
      metalness: 0.12,
      roughness: 0.2,
      clearcoat: 0.85,
      clearcoatRoughness: 0.08,
    },
  },
};
