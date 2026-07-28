classdef MolecularOrbitals
    %MOLECULARORBITALS Estimate band-edge character from atomic orbitals.

    properties (SetAccess = private)
        composition
        elements string
        elec_neg (1,1) double
        aos (1,1) struct
        band_edges (1,1) struct
    end

    methods
        function obj = MolecularOrbitals(formula)
            compositionObject = ...
                kssolv.analysis.matgenlab.core.Composition(formula);
            obj.composition = compositionObject.as_dict();
            obj.elements = string(obj.composition.keys);
            for index = 1:numel(obj.elements)
                amount = obj.composition(char(obj.elements(index)));
                if amount ~= fix(amount)
                    error("KSSOLV:Matgenlab:MolecularOrbitals:Subscripts", ...
                        "Composition subscripts must be integers.");
                end
            end
            obj.elec_neg = obj.max_electronegativity();
            obj.aos = struct();
            for index = 1:numel(obj.elements)
                symbol = obj.elements(index);
                orbitals = kssolv.analysis.matgenlab.core.Element( ...
                    symbol).atomic_orbitals;
                names = orbitals.keys;
                values = cell(1, numel(names));
                for orbitalIndex = 1:numel(names)
                    values{orbitalIndex} = {symbol, ...
                        string(names{orbitalIndex}), ...
                        orbitals(names{orbitalIndex})};
                end
                obj.aos.(char(symbol)) = values;
            end
            obj.band_edges = obj.obtain_band_edges();
        end

        function maximum = max_electronegativity(obj)
            maximum = 0;
            for first = 1:numel(obj.elements)
                firstX = kssolv.analysis.matgenlab.core.Element( ...
                    obj.elements(first)).X;
                for second = first + 1:numel(obj.elements)
                    secondX = kssolv.analysis.matgenlab.core.Element( ...
                        obj.elements(second)).X;
                    maximum = max(maximum, abs(firstX - secondX));
                end
            end
        end

        function orbitals = aos_as_list(obj)
            orbitals = cell(0, 3);
            for index = 1:numel(obj.elements)
                symbol = obj.elements(index);
                entries = obj.aos.(char(symbol));
                repeats = obj.composition(char(symbol));
                for repeat = 1:repeats
                    for orbitalIndex = 1:numel(entries)
                        orbitals(end + 1, :) = entries{orbitalIndex}; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(orbitals)
                [~, order] = sort(cell2mat(orbitals(:, 3)));
                orbitals = orbitals(order, :);
            end
        end

        function edges = obtain_band_edges(obj)
            orbitals = obj.aos_as_list();
            compositionObject = ...
                kssolv.analysis.matgenlab.core.Composition(obj.composition);
            electrons = compositionObject.total_electrons;
            filledCount = 0;
            for index = 1:size(orbitals, 1)
                if electrons <= 0, break; end
                orbital = string(orbitals{index, 2});
                if contains(orbital, "s"), electrons = electrons - 2;
                elseif contains(orbital, "p"), electrons = electrons - 6;
                elseif contains(orbital, "d"), electrons = electrons - 10;
                elseif contains(orbital, "f"), electrons = electrons - 14;
                end
                filledCount = index;
            end
            homo = orbitals(filledCount, :);
            if electrons ~= 0
                lumo = homo;
            elseif filledCount < size(orbitals, 1)
                lumo = orbitals(filledCount + 1, :);
            else
                lumo = [];
            end
            edges = struct("HOMO", {homo}, "LUMO", {lumo}, ...
                "metal", isequal(homo, lumo));
        end
    end
end
