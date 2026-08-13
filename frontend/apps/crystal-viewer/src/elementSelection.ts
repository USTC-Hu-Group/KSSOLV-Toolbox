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

export const connectedSiteIndices = (scene: AtomicSceneSpec, startSiteIndex: number): number[] => {
  if (!scene.sites.some((site) => site.siteIndex === startSiteIndex)) return [];
  const adjacency = new Map<number, Set<number>>();
  for (const site of scene.sites) adjacency.set(site.siteIndex, new Set());
  for (const bond of scene.bondRelations) {
    adjacency.get(bond.fromSiteIndex)?.add(bond.toSiteIndex);
    adjacency.get(bond.toSiteIndex)?.add(bond.fromSiteIndex);
  }
  const visited = new Set([startSiteIndex]);
  const queue = [startSiteIndex];
  while (queue.length > 0) {
    const current = queue.shift()!;
    for (const neighbor of adjacency.get(current) ?? []) {
      if (visited.has(neighbor)) continue;
      visited.add(neighbor);
      queue.push(neighbor);
    }
  }
  return [...visited].sort((first, second) => first - second);
};
