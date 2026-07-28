function [isomorphic, atomMap] = get_atom_map( ...
        inferredMol, openffMol, optionsOrBackend)
%GET_ATOM_MAP Compute an OpenFF-to-inferred-molecule atom mapping.
%
% The returned vector uses MATLAB indices: atomMap(i) is the inferred
% molecule atom corresponding to atom i of openffMol.
if nargin < 3, optionsOrBackend = []; end
Native = "kssolv.analysis.matgenlab.io.openff.OpenFFMolecule";
if ~isa(inferredMol, Native) || ~isa(openffMol, Native)
    [isomorphic, atomMap] = ...
        kssolv.analysis.matgenlab.io.openff.internal.call_backend( ...
        optionsOrBackend, "get_atom_map", inferredMol, openffMol);
    return
end

options = struct("atom_stereochemistry_matching", true, ...
    "bond_stereochemistry_matching", true, ...
    "bond_order_matching", true);
if isstruct(optionsOrBackend)
    names = intersect(fieldnames(optionsOrBackend), fieldnames(options));
    for index = 1:numel(names)
        options.(names{index}) = logical(optionsOrBackend.(names{index}));
    end
end
[isomorphic, atomMap] = matchMolecules(openffMol, inferredMol, options);
if isomorphic, return, end
options.atom_stereochemistry_matching = false;
options.bond_stereochemistry_matching = false;
[isomorphic, atomMap] = matchMolecules(openffMol, inferredMol, options);
if isomorphic, return, end
options.bond_order_matching = false;
[isomorphic, atomMap] = matchMolecules(openffMol, inferredMol, options);
if ~isomorphic, atomMap = zeros(1, 0); end
end

function [matched, mapping] = matchMolecules(reference, candidate, options)
matched = false;
mapping = zeros(1, 0);
if reference.n_atoms ~= candidate.n_atoms || ...
        reference.n_bonds ~= candidate.n_bonds
    return
end
nAtoms = reference.n_atoms;
referenceAdjacency = adjacency(reference);
candidateAdjacency = adjacency(candidate);
referenceDegree = sum(referenceAdjacency > 0, 2);
candidateDegree = sum(candidateAdjacency > 0, 2);
candidateLists = cell(1, nAtoms);
for referenceIndex = 1:nAtoms
    atom = reference.atoms(referenceIndex);
    valid = find([candidate.atoms.atomic_number] == atom.atomic_number & ...
        candidateDegree.' == referenceDegree(referenceIndex));
    if options.atom_stereochemistry_matching
        stereo = string(atom.stereochemistry);
        valid = valid(arrayfun(@(index) ...
            string(candidate.atoms(index).stereochemistry) == stereo, valid));
    end
    candidateLists{referenceIndex} = valid;
    if isempty(valid), return, end
end
[~, order] = sort(cellfun(@numel, candidateLists));
trial = zeros(1, nAtoms);
used = false(1, nAtoms);
[matched, mapping] = search(1, order, trial, used, candidateLists, ...
    reference, candidate, referenceAdjacency, candidateAdjacency, options);
end

function [found, mapping] = search(position, order, mapping, used, ...
        candidateLists, reference, candidate, referenceAdjacency, ...
        candidateAdjacency, options)
if position > numel(order)
    found = true;
    return
end
referenceIndex = order(position);
for candidateIndex = candidateLists{referenceIndex}
    if used(candidateIndex), continue, end
    compatible = true;
    assigned = find(mapping > 0);
    for prior = assigned
        referenceOrder = referenceAdjacency(referenceIndex, prior);
        candidateOrder = candidateAdjacency(candidateIndex, mapping(prior));
        if (referenceOrder > 0) ~= (candidateOrder > 0)
            compatible = false;
            break
        end
        if referenceOrder > 0
            if options.bond_order_matching && ...
                    abs(referenceOrder - candidateOrder) > 1e-10
                compatible = false;
                break
            end
            if options.bond_stereochemistry_matching
                firstStereo = bondStereo(reference, referenceIndex, prior);
                secondStereo = bondStereo(candidate, candidateIndex, ...
                    mapping(prior));
                if firstStereo ~= secondStereo
                    compatible = false;
                    break
                end
            end
        end
    end
    if ~compatible, continue, end
    mapping(referenceIndex) = candidateIndex;
    used(candidateIndex) = true;
    [found, completed] = search(position + 1, order, mapping, used, ...
        candidateLists, reference, candidate, referenceAdjacency, ...
        candidateAdjacency, options);
    if found
        mapping = completed;
        return
    end
    mapping(referenceIndex) = 0;
    used(candidateIndex) = false;
end
found = false;
end

function value = adjacency(molecule)
value = zeros(molecule.n_atoms);
for bond = molecule.bonds
    value(bond.atom1_index, bond.atom2_index) = bond.bond_order;
    value(bond.atom2_index, bond.atom1_index) = bond.bond_order;
end
end

function value = bondStereo(molecule, first, second)
value = "";
for bond = molecule.bonds
    if (bond.atom1_index == first && bond.atom2_index == second) || ...
            (bond.atom1_index == second && bond.atom2_index == first)
        value = string(bond.stereochemistry);
        return
    end
end
end
