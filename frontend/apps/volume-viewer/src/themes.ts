import type { ThemeId } from '@kssolv/atomic-scene';

export interface VolumeViewerTheme {
  id: ThemeId;
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
  };
  bond: {
    metalness: number;
    roughness: number;
    clearcoat: number;
    clearcoatRoughness: number;
  };
}

/**
 * The atomic overlay deliberately uses the same authored values as the
 * crystal viewer so switching between structure and volume documents does not
 * visually restyle the crystal.
 */
export const volumeViewerThemes: Record<ThemeId, VolumeViewerTheme> = {
  materials: {
    id: 'materials',
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
    },
    bond: {
      metalness: 0.12,
      roughness: 0.2,
      clearcoat: 0.85,
      clearcoatRoughness: 0.08,
    },
  },
};

/** Maps the normalized UI midpoint (50%) to the theme-authored value. */
export const appearanceScale = (value: number): number =>
  Math.max(0, Math.min(2, value * 2));

export const scaledMetalness = (authored: number, control: number): number =>
  Math.max(0, Math.min(1, authored * appearanceScale(control)));

export const scaledRoughness = (authored: number, control: number): number =>
  Math.max(0.02, Math.min(1, authored * appearanceScale(control)));
