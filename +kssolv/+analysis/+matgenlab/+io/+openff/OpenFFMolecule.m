classdef OpenFFMolecule < handle
    %OPENFFMOLECULE MATLAB-native interchange value for OpenFF molecules.
    %
    % Atom indices are one based. Charges are expressed in elementary-charge
    % units and conformer coordinates in angstrom, so no runtime unit package
    % is required.

    properties
        atoms struct = struct("atomic_number", {}, "formal_charge", {}, ...
            "is_aromatic", {}, "stereochemistry", {}, ...
            "partial_charge", {})
        bonds struct = struct("atom1_index", {}, "atom2_index", {}, ...
            "bond_order", {}, "is_aromatic", {}, "stereochemistry", {})
        conformers cell = cell(1, 0)
        partial_charges double = zeros(1, 0)
        smiles (1,1) string = ""
    end

    properties (Dependent, SetAccess = private)
        n_atoms
        n_bonds
        n_conformers
        total_charge
    end

    methods
        function obj = OpenFFMolecule(atoms, bonds, conformers, smiles)
            if nargin >= 1 && ~isempty(atoms), obj.atoms = atoms; end
            if nargin >= 2 && ~isempty(bonds), obj.bonds = bonds; end
            if nargin >= 3 && ~isempty(conformers)
                obj.conformers = reshape(conformers, 1, []);
            end
            if nargin >= 4, obj.smiles = string(smiles); end
            if ~isempty(obj.atoms)
                charges = [obj.atoms.partial_charge];
                if numel(charges) == numel(obj.atoms) && all(~isnan(charges))
                    obj.partial_charges = double(charges);
                end
            end
        end

        function value = get.n_atoms(obj), value = numel(obj.atoms); end
        function value = get.n_bonds(obj), value = numel(obj.bonds); end
        function value = get.n_conformers(obj)
            value = numel(obj.conformers);
        end
        function value = get.total_charge(obj)
            if isempty(obj.atoms), value = 0;
            else, value = sum([obj.atoms.formal_charge]);
            end
        end

        function index = add_atom(obj, atomicNumber, formalCharge, ...
                isAromatic, stereochemistry)
            if nargin < 4 || isempty(isAromatic), isAromatic = false; end
            if nargin < 5, stereochemistry = ""; end
            atom = atomRecord(atomicNumber, formalCharge, isAromatic, ...
                stereochemistry, NaN);
            obj.atoms(end + 1) = atom;
            obj.partial_charges = zeros(1, 0);
            index = obj.n_atoms;
        end

        function add_bond(obj, first, second, bondOrder, isAromatic, ...
                stereochemistry)
            if nargin < 4 || isempty(bondOrder), bondOrder = 1; end
            if nargin < 5 || isempty(isAromatic), isAromatic = false; end
            if nargin < 6, stereochemistry = ""; end
            validateIndex(obj, first);
            validateIndex(obj, second);
            obj.bonds(end + 1) = struct( ...
                "atom1_index", double(first), ...
                "atom2_index", double(second), ...
                "bond_order", double(bondOrder), ...
                "is_aromatic", logical(isAromatic), ...
                "stereochemistry", string(stereochemistry));
        end

        function add_conformer(obj, coordinates)
            coordinates = double(coordinates);
            if ~isequal(size(coordinates), [obj.n_atoms, 3])
                error("KSSOLV:Matgenlab:OpenFF:ConformerShape", ...
                    "A conformer must contain one xyz row per atom.");
            end
            obj.conformers{end + 1} = coordinates;
        end

        function generate_conformers(obj, nConformers)
            if nargin < 2, nConformers = 1; end
            validateattributes(nConformers, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            for conformerIndex = 1:double(nConformers)
                coordinates = zeros(obj.n_atoms, 3);
                if obj.n_atoms > 1
                    angles = (0:obj.n_atoms - 1).' * 2 * pi / ...
                        max(obj.n_atoms, 3);
                    coordinates(:, 1:2) = 1.4 * [cos(angles), sin(angles)];
                    coordinates(:, 3) = 0.1 * mod(0:obj.n_atoms - 1, 3).';
                end
                obj.add_conformer(coordinates);
            end
        end

        function assign_partial_charges(obj, method)
            if nargin < 2 || strlength(string(method)) == 0
                method = "am1bcc";
            end
            method = string(method);
            if ~isscalar(method)
                error("KSSOLV:Matgenlab:OpenFF:ChargeMethod", ...
                    "charge_method must be a scalar name.");
            end
            % A deterministic electronegativity-equalization fallback keeps
            % the native value chemically meaningful. Exact toolkit methods
            % can be supplied through the public injected-backend boundary.
            electronegativity = arrayfun(@pauling, ...
                [obj.atoms.atomic_number]);
            adjacency = zeros(obj.n_atoms);
            for bond = obj.bonds
                adjacency(bond.atom1_index, bond.atom2_index) = ...
                    bond.bond_order;
                adjacency(bond.atom2_index, bond.atom1_index) = ...
                    bond.bond_order;
            end
            charges = zeros(1, obj.n_atoms);
            for first = 1:obj.n_atoms
                for second = first + 1:obj.n_atoms
                    if adjacency(first, second) > 0
                        delta = 0.08 * (electronegativity(second) - ...
                            electronegativity(first));
                        charges(first) = charges(first) + delta;
                        charges(second) = charges(second) - delta;
                    end
                end
            end
            target = obj.total_charge;
            charges = charges + (target - sum(charges)) / ...
                max(obj.n_atoms, 1);
            obj.set_partial_charges(charges);
        end

        function set_partial_charges(obj, charges)
            charges = reshape(double(charges), 1, []);
            if numel(charges) ~= obj.n_atoms
                error("KSSOLV:Matgenlab:OpenFF:ChargeLength", ...
                    "Partial charges require one value per atom.");
            end
            obj.partial_charges = charges;
            for index = 1:obj.n_atoms
                obj.atoms(index).partial_charge = charges(index);
            end
        end

        function value = to_smiles(obj)
            value = obj.smiles;
        end

        function value = copy(obj)
            value = kssolv.analysis.matgenlab.io.openff.OpenFFMolecule( ...
                obj.atoms, obj.bonds, obj.conformers, obj.smiles);
            if ~isempty(obj.partial_charges)
                value.set_partial_charges(obj.partial_charges);
            end
        end

        function tf = eq(obj, other)
            tf = isa(other, ...
                "kssolv.analysis.matgenlab.io.openff.OpenFFMolecule") && ...
                kssolv.analysis.matgenlab.io.openff.OpenFFMolecule. ...
                is_isomorphic_with(obj, other, true);
            if tf && ~isempty(obj.partial_charges) && ...
                    ~isempty(other.partial_charges)
                tf = max(abs(sort(obj.partial_charges) - ...
                    sort(other.partial_charges))) < 1e-10;
            end
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end
    end

    methods (Static)
        function obj = from_smiles(smiles, allowUndefinedStereo)
            if nargin < 2, allowUndefinedStereo = true; end
            if ~isscalar(allowUndefinedStereo)
                error("KSSOLV:Matgenlab:OpenFF:StereoOption", ...
                    "allow_undefined_stereo must be scalar.");
            end
            obj = parseSmiles(string(smiles));
        end

        function tf = is_isomorphic_with(first, second, bondOrderMatching)
            if nargin < 3, bondOrderMatching = true; end
            [tf, ~] = kssolv.analysis.matgenlab.io.openff. ...
                get_atom_map(first, second, ...
                struct("bond_order_matching", bondOrderMatching));
        end
    end
end

function obj = parseSmiles(smiles)
text = char(smiles);
obj = kssolv.analysis.matgenlab.io.openff.OpenFFMolecule();
obj.smiles = smiles;
branch = zeros(1, 0);
ringAtoms = zeros(1, 10);
ringOrders = nan(1, 10);
current = 0;
pendingOrder = 1;
pendingAromatic = false;
explicitHydrogens = zeros(1, 0);
index = 1;
while index <= strlength(smiles)
    token = text(index);
    if token == '('
        branch(end + 1) = current; %#ok<AGROW>
        index = index + 1;
        continue
    elseif token == ')'
        if isempty(branch)
            invalidSmiles(smiles);
        end
        current = branch(end);
        branch(end) = [];
        index = index + 1;
        continue
    elseif any(token == '-=#:')
        orders = [1, 2, 3, 1.5];
        pendingOrder = orders(find('-=#:' == token, 1));
        pendingAromatic = token == ':';
        index = index + 1;
        continue
    elseif isstrprop(token, "digit")
        digit = str2double(token) + 1;
        if ringAtoms(digit) == 0
            ringAtoms(digit) = current;
            ringOrders(digit) = pendingOrder;
        else
            order = pendingOrder;
            if pendingOrder == 1 && ~isnan(ringOrders(digit))
                order = ringOrders(digit);
            end
            obj.add_bond(ringAtoms(digit), current, order, ...
                pendingAromatic);
            ringAtoms(digit) = 0;
            ringOrders(digit) = NaN;
        end
        pendingOrder = 1;
        pendingAromatic = false;
        index = index + 1;
        continue
    elseif token == '.'
        current = 0;
        index = index + 1;
        continue
    end

    [symbol, formalCharge, aromatic, stereo, hydrogenCount, consumed] = ...
        readAtom(text, index);
    element = kssolv.analysis.matgenlab.core.Element(symbol);
    previous = current;
    current = obj.add_atom(element.Z, formalCharge, aromatic, stereo);
    explicitHydrogens(current) = hydrogenCount;
    if previous > 0
        aromaticBond = pendingAromatic || ...
            (obj.atoms(previous).is_aromatic && aromatic);
        order = pendingOrder;
        if aromaticBond && order == 1, order = 1.5; end
        obj.add_bond(previous, current, order, aromaticBond);
    end
    pendingOrder = 1;
    pendingAromatic = false;
    index = index + consumed;
end
if any(ringAtoms ~= 0), invalidSmiles(smiles); end

heavyCount = obj.n_atoms;
bondSums = zeros(1, heavyCount);
for bond = obj.bonds
    bondSums(bond.atom1_index) = bondSums(bond.atom1_index) + ...
        bond.bond_order;
    bondSums(bond.atom2_index) = bondSums(bond.atom2_index) + ...
        bond.bond_order;
end
for atomIndex = 1:heavyCount
    atom = obj.atoms(atomIndex);
    target = valenceTarget(atom.atomic_number, atom.formal_charge, ...
        atom.is_aromatic, bondSums(atomIndex));
    count = explicitHydrogens(atomIndex);
    if count == 0
        count = max(round(target - bondSums(atomIndex)), 0);
    end
    hydrogen = kssolv.analysis.matgenlab.core.Element("H");
    while count > 0
        added = obj.add_atom(hydrogen.Z, 0, false, "");
        obj.add_bond(atomIndex, added, 1, false);
        count = count - 1;
    end
end
end

function [symbol, charge, aromatic, stereo, hydrogens, consumed] = ...
        readAtom(text, start)
charge = 0;
stereo = "";
hydrogens = 0;
if text(start) == '['
    stop = find(text(start + 1:end) == ']', 1) + start;
    if isempty(stop), invalidSmiles(string(text)); end
    body = string(text(start + 1:stop - 1));
    match = regexp(body, "^([A-Z][a-z]?|[a-z])", "tokens", "once");
    if isempty(match), invalidSmiles(string(text)); end
    raw = string(match{1});
    aromatic = all(isstrprop(char(raw), "lower"));
    symbol = normalizeSymbol(raw);
    stereoMatch = regexp(body, "(@@?)", "tokens", "once");
    if ~isempty(stereoMatch), stereo = string(stereoMatch{1}); end
    hydrogenMatch = regexp(body, "H(\d*)", "tokens", "once");
    if ~isempty(hydrogenMatch)
        if strlength(string(hydrogenMatch{1})) == 0
            hydrogens = 1;
        else
            hydrogens = str2double(hydrogenMatch{1});
        end
    end
    chargeMatch = regexp(body, "([+-])(\d*)", "tokens", "once");
    if ~isempty(chargeMatch)
        magnitude = str2double(chargeMatch{2});
        if isnan(magnitude), magnitude = 1; end
        if string(chargeMatch{1}) == "-", magnitude = -magnitude; end
        charge = magnitude;
    end
    consumed = stop - start + 1;
else
    raw = string(text(start));
    consumed = 1;
    if start < numel(text) && isstrprop(text(start + 1), "lower") && ...
            isstrprop(text(start), "upper")
        candidate = string(text(start:start + 1));
        try
            kssolv.analysis.matgenlab.core.Element(candidate);
            raw = candidate;
            consumed = 2;
        catch
        end
    end
    aromatic = all(isstrprop(char(raw), "lower"));
    symbol = normalizeSymbol(raw);
end
end

function symbol = normalizeSymbol(raw)
raw = char(raw);
symbol = string([upper(raw(1)), lower(raw(2:end))]);
end

function target = valenceTarget(atomicNumber, formalCharge, aromatic, bondSum)
symbol = kssolv.analysis.matgenlab.core.Element.fromZ(atomicNumber).symbol;
switch symbol
    case "H", target = 1;
    case {"F", "Cl", "Br", "I"}, target = 1;
    case {"O", "S", "Se"}, target = 2;
    case {"N", "P"}
        if symbol == "P" && bondSum > 3, target = max(5, bondSum);
        else, target = 3 + max(formalCharge, 0);
        end
    case {"C", "Si"}, target = 4;
    case {"B", "Al"}, target = 3;
    otherwise, target = bondSum;
end
if aromatic, target = 3; end
if symbol == "P" && formalCharge < 0 && bondSum >= 6, target = bondSum; end
end

function value = pauling(atomicNumber)
symbol = kssolv.analysis.matgenlab.core.Element.fromZ(atomicNumber).symbol;
switch symbol
    case "H", value = 2.20;
    case "B", value = 2.04;
    case "C", value = 2.55;
    case "N", value = 3.04;
    case "O", value = 3.44;
    case "F", value = 3.98;
    case "P", value = 2.19;
    case "S", value = 2.58;
    case "Cl", value = 3.16;
    otherwise, value = 2.2;
end
end

function atom = atomRecord(atomicNumber, formalCharge, aromatic, stereo, partial)
atom = struct("atomic_number", double(atomicNumber), ...
    "formal_charge", double(formalCharge), ...
    "is_aromatic", logical(aromatic), ...
    "stereochemistry", string(stereo), ...
    "partial_charge", double(partial));
end

function validateIndex(obj, index)
if index < 1 || index > obj.n_atoms || index ~= fix(index)
    error("KSSOLV:Matgenlab:OpenFF:AtomIndex", ...
        "Atom index is outside the molecule.");
end
end

function invalidSmiles(smiles)
error("KSSOLV:Matgenlab:OpenFF:SMILES", ...
    "Unable to parse SMILES '%s'.", smiles);
end
