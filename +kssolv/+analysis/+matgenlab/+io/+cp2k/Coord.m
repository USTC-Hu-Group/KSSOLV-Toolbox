classdef Coord < kssolv.analysis.matgenlab.io.cp2k.Section
 methods
  function obj=Coord(structure,varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("COORD");aliases=struct();
   for i=1:2:numel(varargin),if lower(string(varargin{i}))=="aliases",aliases=varargin{i+1};end,end
   aliasBySite=strings(1,structure.num_sites);names=fieldnames(aliases);
   for i=1:numel(names),aliasBySite(aliases.(names{i}))=string(names{i});end
   for i=1:structure.num_sites
    site=structure.sites{i};name=string(site.specie.symbol);if strlength(aliasBySite(i))>0,name=aliasBySite(i);end
    obj.add(kssolv.analysis.matgenlab.io.cp2k.Keyword(name,site.coords,"repeats",true));
   end
  end
 end
end
