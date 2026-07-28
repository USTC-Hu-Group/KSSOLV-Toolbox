function values = structure_to_abivars(structure, enforceZnucl, enforceTypat, varargin)
%STRUCTURE_TO_ABIVARS Convert an ordered Structure to ABINIT geometry variables.
if nargin<2, enforceZnucl=[]; end
if nargin<3, enforceTypat=[]; end
if xor(isempty(enforceZnucl),isempty(enforceTypat))
    error("KSSOLV:Matgenlab:Abinit:Order","Both enforce_znucl and enforce_typat are required.");
end
if isempty(enforceZnucl) %#ok<ALIGN>
    types=kssolv.analysis.matgenlab.io.abinit.species_by_znucl(structure);
    znucl=cellfun(@(item) double(item.Z),types); typat=zeros(1,structure.num_sites);
    for index=1:structure.num_sites
        typat(index)=find(cellfun(@(item) double(item.Z)==double(structure.sites{index}.specie.Z),types),1);
    end
else, znucl=enforceZnucl; typat=enforceTypat; end
rprim=structure.lattice.matrix/0.529177210903; rprim(abs(rprim)<1e-8)=0;
xred=structure.frac_coords; xred(abs(xred)<1e-8)=0;
values=struct("natom",structure.num_sites,"ntypat",numel(znucl),"typat",typat, ...
    "znucl",znucl,"xred",xred,"acell",[1 1 1],"rprim",rprim);
end
