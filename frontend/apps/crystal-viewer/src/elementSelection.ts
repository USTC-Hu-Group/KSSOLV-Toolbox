import type { AtomicSceneSpec, SiteSpec } from './scene/types';

export const primaryElementSymbol = (site: SiteSpec): string =>
  site.species.reduce((primary, component) =>
    component.occupancy > primary.occupancy ? component : primary,
  ).symbol;

export const siteSpeciesLabel = (site: SiteSpec): string =>
  [...new Set(site.species.map((component) => component.symbol))].join('/');

export const atomIdsForElement = (scene: AtomicSceneSpec, symbol: string): string[] => {
  const matchingSites = new Set(
    scene.sites
      .filter((site) => primaryElementSymbol(site) === symbol)
      .map((site) => site.siteIndex),
  );
  return scene.atomInstances
    .filter((atom) => matchingSites.has(atom.siteIndex))
    .map((atom) => atom.id);
};
