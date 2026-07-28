classdef MoleculeStructureComparator
    %MOLECULESTRUCTURECOMPARATOR Compare index-aligned bond tables.

    properties (Constant)
        ionic_element_list = ["Na","Mg","Al","Sc","V","Cr","Mn","Fe", ...
            "Co","Ni","Cu","Zn","Ga","Rb","Sr"]
        halogen_list = ["F","Cl","Br","I"]
    end

    properties (SetAccess = protected)
        bond_length_cap (1,1) double = 0.3
        covalent_radius (1,1) struct = struct()
        priority_bonds (:,2) double = zeros(0, 2)
        priority_cap (1,1) double = 0.8
        ignore_ionic_bond (1,1) logical = true
        ignore_halogen_self_bond (1,1) logical = true
        bond_13_cap (1,1) double = 0.05
    end

    methods
        function obj = MoleculeStructureComparator(bondLengthCap, ...
                covalentRadius, priorityBonds, priorityCap, ...
                ignoreIonicBond, bond13Cap)
            if nargin < 1 || isempty(bondLengthCap), bondLengthCap = 0.3; end
            if nargin < 2 || isempty(covalentRadius)
                covalentRadius = ...
                    kssolv.analysis.matgenlab.core.CovalentRadius.radius();
            end
            if nargin < 3 || isempty(priorityBonds)
                priorityBonds = zeros(0, 2);
            end
            if nargin < 4 || isempty(priorityCap), priorityCap = 0.8; end
            if nargin < 5 || isempty(ignoreIonicBond), ignoreIonicBond = true; end
            if nargin < 6 || isempty(bond13Cap), bond13Cap = 0.05; end
            obj.bond_length_cap = double(bondLengthCap);
            obj.covalent_radius = covalentRadius;
            obj.priority_bonds = sort(double(priorityBonds), 2);
            obj.priority_cap = double(priorityCap);
            obj.ignore_ionic_bond = logical(ignoreIonicBond);
            obj.bond_13_cap = double(bond13Cap);
        end

        function equal = are_equal(obj, molecule1, molecule2)
            bonds1 = obj.getBonds(molecule1);
            bonds2 = obj.getBonds(molecule2);
            equal = isequal(sortrows(bonds1), sortrows(bonds2));
        end

        function result = as_dict(obj)
            result = struct( ...
                "version", "1.0", ...
                "x_module", "pymatgen.core.molecule_structure_comparator", ...
                "x_class", "MoleculeStructureComparator", ...
                "bond_length_cap", obj.bond_length_cap, ...
                "covalent_radius", obj.covalent_radius, ...
                "priority_bonds", obj.priority_bonds, ...
                "priority_cap", obj.priority_cap);
        end
    end

    methods (Static)
        function bonds = get_13_bonds(priorityBonds)
            priorityBonds = sort(double(priorityBonds), 2);
            implied = zeros(0, 2);
            for first = 1:size(priorityBonds, 1)
                for second = first + 1:size(priorityBonds, 1)
                    atoms = unique([priorityBonds(first, :), ...
                        priorityBonds(second, :)]);
                    if numel(atoms) ~= 3, continue; end
                    pairs = nchoosek(atoms, 2);
                    for index = 1:size(pairs, 1)
                        pair = sort(pairs(index, :));
                        if ~ismember(pair, priorityBonds, "rows")
                            implied(end + 1, :) = pair; %#ok<AGROW>
                        end
                    end
                end
            end
            bonds = unique(implied, "rows", "sorted");
        end

        function obj = from_dict(dct)
            obj = kssolv.analysis.matgenlab.core.MoleculeStructureComparator( ...
                dct.bond_length_cap, dct.covalent_radius, ...
                dct.priority_bonds, dct.priority_cap);
        end
    end

    methods (Access = protected)
        function bonds = getBonds(obj, molecule)
            covalent = zeros(1, 0);
            for index = 1:molecule.num_sites
                symbol = molecule.get_site(index).specie.symbol;
                if ~isfield(obj.covalent_radius, char(symbol))
                    error("KSSOLV:Matgenlab:MoleculeComparator:MissingRadius", ...
                        "The covalent radius for element %s is not available.", ...
                        symbol);
                end
                if ~obj.ignore_ionic_bond || ...
                        ~ismember(symbol, obj.ionic_element_list)
                    covalent(end + 1) = index; %#ok<AGROW>
                end
            end

            bonds = zeros(0, 2);
            bond13 = obj.get_13_bonds(obj.priority_bonds);
            for localI = 1:numel(covalent)
                for localJ = localI + 1:numel(covalent)
                    i = covalent(localI);
                    j = covalent(localJ);
                    % Expose Python-compatible zero-based bond indices.
                    pair = [i - 1, j - 1];
                    site1 = molecule.get_site(i);
                    site2 = molecule.get_site(j);
                    cap = obj.covalent_radius.(char(site1.specie.symbol)) + ...
                        obj.covalent_radius.(char(site2.specie.symbol));
                    if ismember(pair, obj.priority_bonds, "rows")
                        cap = cap * (1 + obj.priority_cap);
                    elseif ismember(pair, bond13, "rows")
                        cap = cap * (1 + obj.bond_13_cap);
                    else
                        cap = cap * (1 + obj.bond_length_cap);
                    end
                    if obj.ignore_halogen_self_bond && ...
                            ~ismember(pair, obj.priority_bonds, "rows") && ...
                            ismember(site1.specie.symbol, obj.halogen_list) && ...
                            ismember(site2.specie.symbol, obj.halogen_list)
                        cap = cap * 0.1;
                    end
                    if norm(site1.coords - site2.coords) <= cap
                        bonds(end + 1, :) = pair; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
