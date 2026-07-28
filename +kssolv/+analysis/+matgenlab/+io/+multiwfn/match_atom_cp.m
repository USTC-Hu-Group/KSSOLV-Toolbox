function [cpName, descriptor] = match_atom_cp( ...
        molecule, index, atomCpDict, maxDistance)
%MATCH_ATOM_CP Match a molecule site to a nuclear critical point.
if nargin < 4, maxDistance = 0.5; end
if index < 1 || index > molecule.num_sites || index ~= fix(index)
    error("KSSOLV:Matgenlab:Multiwfn:AtomIndex", ...
        "Atom index must be a valid 1-based molecule index.");
end
site = molecule(index);
symbol = site.species_string;
cpName = [];
descriptor = struct();
keys = atomCpDict.keys;
for keyIndex = 1:numel(keys)
    name = string(keys{keyIndex});
    candidate = atomCpDict(keys{keyIndex});
    number = str2double(extractBefore(name, "_"));
    if number == index && string(candidate.element) == symbol
        cpName = name;
        descriptor = candidate;
        return
    end
    if string(candidate.element) == symbol && ...
            norm(double(candidate.pos_ang) - site.coords) < maxDistance
        cpName = name;
        descriptor = candidate;
        return
    end
end
end
