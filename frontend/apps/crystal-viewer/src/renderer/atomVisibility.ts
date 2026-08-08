import type { AtomInstanceSpec, AtomicSceneSpec, SiteSpec, ViewerOptions } from '../scene/types';

export const isHydrogenSite = (site?: SiteSpec): boolean =>
  site?.species.every((component) => component.symbol === 'H') ?? false;

export const isAtomVisible = (
  atom: AtomInstanceSpec,
  site: SiteSpec,
  options: ViewerOptions,
): boolean =>
  options.showAtoms &&
  (options.showHydrogens || !isHydrogenSite(site)) &&
  (atom.visibility === 'base' ||
    atom.visibility === 'repeat' ||
    (atom.visibility === 'boundary' && options.showBoundaryAtoms) ||
    (atom.visibility === 'bonded' && options.showBondedOutside));

export const visibleAtomCount = (scene: AtomicSceneSpec, options: ViewerOptions): number => {
  const sites = new Map(scene.sites.map((site) => [site.siteIndex, site]));
  return scene.atomInstances.reduce((count, atom) => {
    const site = sites.get(atom.siteIndex);
    return count + (site && isAtomVisible(atom, site, options) ? 1 : 0);
  }, 0);
};

export const atomCountLabel = (scene: AtomicSceneSpec, options: ViewerOptions): string => {
  const total = scene.atomInstances.length;
  const visible = visibleAtomCount(scene, options);
  return visible < total ? `${visible}/${total}` : `${total}`;
};
