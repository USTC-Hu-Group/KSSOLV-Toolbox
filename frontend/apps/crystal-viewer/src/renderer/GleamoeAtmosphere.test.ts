import { Color, OrthographicCamera, Vector3 } from 'three';
import { describe, expect, it } from 'vitest';

import { GleamoeAtmosphere } from './GleamoeAtmosphere';

describe('Gleamoe atmosphere', () => {
  it('builds deterministic particles and two camera-aware light shafts', () => {
    const atmosphere = new GleamoeAtmosphere(new Vector3(2, 3, 4), 5, {
      dominant: new Color(0.2, 0.4, 0.6),
      key: new Color(0.9, 0.95, 1),
      fill: new Color(0.4, 0.5, 0.8),
      rim: new Color(0.3, 0.7, 1),
    });
    const camera = new OrthographicCamera(-1, 1, 1, -1);
    camera.position.set(10, 9, 12);
    atmosphere.updateCamera(camera);
    expect(atmosphere.group.children).toHaveLength(1);
    expect(atmosphere.animated).toBe(false);
    atmosphere.setHeroMode(true);
    expect(atmosphere.animated).toBe(true);
    atmosphere.dispose();
    expect(atmosphere.group.children).toHaveLength(0);
  });
});
