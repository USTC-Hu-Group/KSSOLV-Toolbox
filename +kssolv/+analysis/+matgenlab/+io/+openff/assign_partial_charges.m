function openffMol = assign_partial_charges( ...
        openffMol, atomMap, chargeMethod, partialCharges, backend)
%ASSIGN_PARTIAL_CHARGES Assign explicit or method-derived atom charges.
if nargin < 2 || isempty(atomMap), atomMap = 1:openffMol.n_atoms; end
if nargin < 3 || strlength(string(chargeMethod)) == 0
    chargeMethod = "am1bcc";
end
if nargin < 4, partialCharges = []; end
if nargin < 5, backend = []; end
Native = "kssolv.analysis.matgenlab.io.openff.OpenFFMolecule";
if ~isa(openffMol, Native)
    openffMol = kssolv.analysis.matgenlab.io.openff.internal. ...
        call_backend(backend, "assign_partial_charges", openffMol, ...
        atomMap, chargeMethod, partialCharges);
    return
end
indices = mapValues(atomMap, openffMol.n_atoms);
if ~isempty(partialCharges)
    partialCharges = reshape(double(partialCharges), 1, []);
    if any(indices > numel(partialCharges))
        error("KSSOLV:Matgenlab:OpenFF:ChargeLength", ...
            "Partial charge mapping exceeds the supplied charge vector.");
    end
    openffMol.set_partial_charges(partialCharges(indices));
elseif openffMol.n_atoms == 1
    openffMol.set_partial_charges(openffMol.total_charge);
elseif ~isempty(backend) && ...
        kssolv.analysis.matgenlab.io.openff.internal. ...
        backend_has(backend, "assign_partial_charges")
    openffMol = kssolv.analysis.matgenlab.io.openff.internal. ...
        call_backend(backend, "assign_partial_charges", openffMol, ...
        atomMap, chargeMethod, partialCharges);
else
    openffMol.assign_partial_charges(chargeMethod);
end
end

function values = mapValues(atomMap, count)
if isa(atomMap, "containers.Map")
    keys = sort(cell2mat(atomMap.keys));
    values = cell2mat(atomMap.values(num2cell(keys)));
else
    values = reshape(double(atomMap), 1, []);
end
if numel(values) ~= count || any(values < 1) || ...
        any(values ~= fix(values))
    error("KSSOLV:Matgenlab:OpenFF:AtomMap", ...
        "atom_map must map every OpenFF atom to a MATLAB atom index.");
end
end
