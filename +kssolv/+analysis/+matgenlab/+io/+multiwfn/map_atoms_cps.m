function [mapping, missingAtoms] = map_atoms_cps( ...
        molecule, atomCpDict, maxDistance)
%MAP_ATOMS_CPS Map all molecule sites to nuclear critical points.
if nargin < 3, maxDistance = 0.5; end
mapping = containers.Map( ...
    "KeyType", "double", "ValueType", "any");
missingAtoms = zeros(1, molecule.num_sites);
missingCount = 0;
for index = 1:molecule.num_sites
    [name, descriptor] = ...
        kssolv.analysis.matgenlab.io.multiwfn. ...
        match_atom_cp(molecule, index, atomCpDict, maxDistance);
    if ~isempty(name)
        descriptor.name = name;
        mapping(index) = descriptor;
    else
        mapping(index) = struct();
        missingCount = missingCount + 1;
        missingAtoms(missingCount) = index;
    end
end
missingAtoms = missingAtoms(1:missingCount);
end
