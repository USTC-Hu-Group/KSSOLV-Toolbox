classdef GeometryParameterProvider
    %GEOMETRYPARAMETERPROVIDER Traceable construction and MM parameters.
    %
    % The provider deliberately separates ideal construction geometry from
    % the KSSOLV generic molecular-mechanics parameter layer. Bond lengths
    % are sourced from the frozen pymatgen table when possible. Every
    % energy parameter has an explicit source and fallback flag; none of
    % these values are presented as COMPASS, UFF, or another branded force
    % field.

    properties (Constant)
        SchemaVersion = 2
        ParameterSet = "kssolv-generic-mm-parameters-v2"
    end

    methods (Static)
        function parameters = constructionBonds(hostSymbols, sketchSymbols, orders)
            %CONSTRUCTIONBONDS Build the traceable Sketcher parameter table.
            arguments
                hostSymbols string
                sketchSymbols string = ...
                    ["H", "B", "C", "N", "O", "F", ...
                    "P", "S", "Cl", "Br", "I"]
                orders double = [1, 1.5, 2, 3]
            end
            hosts = unique(strtrim(reshape(hostSymbols, 1, [])), "stable");
            hosts(hosts == "") = [];
            sketches = unique(strtrim(reshape(sketchSymbols, 1, [])), ...
                "stable");
            sketches(sketches == "") = [];
            orders = unique(reshape(double(orders), 1, []), "stable");
            values = cell(1, numel(hosts) * numel(sketches) * ...
                numel(orders));
            valueIndex = 0;
            seenKeys = strings(1, 0);
            for host = hosts
                for sketch = sketches
                    for order = orders
                        symbols = sort([host, sketch]);
                        key = strjoin(symbols, "|") + "|" + string(order);
                        if any(seenKeys == key), continue, end
                        seenKeys(end + 1) = key; %#ok<AGROW>
                        parameter = kssolv.modeling.forcefield. ...
                            GeometryParameterProvider.bond( ...
                            host, sketch, order);
                        value = struct( ...
                            "firstElement", symbols(1), ...
                            "secondElement", symbols(2), ...
                            "bondOrder", double(order), ...
                            "value", double(parameter.value), ...
                            "unit", string(parameter.unit), ...
                            "parameterSet", string(parameter.parameterSet), ...
                            "source", string(parameter.source), ...
                            "fallback", logical(parameter.fallback));
                        valueIndex = valueIndex + 1;
                        values{valueIndex} = value;
                    end
                end
            end
            if valueIndex == 0
                parameters = struct([]);
            else
                parameters = [values{1:valueIndex}];
            end
        end

        function parameter = atom(symbol, incidentOrders)
            arguments
                symbol
                incidentOrders double = zeros(1, 0)
            end
            element = kssolv.analysis.matgenlab.core.get_el_sp(symbol);
            orders = reshape(double(incidentOrders), 1, []);
            coordination = numel(orders);
            aromatic = any(abs(orders - 1.5) < 1e-12);
            name = string(element.symbol);
            fallback = false;
            if aromatic
                hybridization = "sp2-aromatic";
            elseif coordination <= 1
                hybridization = "terminal";
            elseif coordination == 2 && sum(orders) >= 4 - 1e-12
                hybridization = "sp";
            elseif coordination == 3 || ...
                    (coordination == 2 && name == "N")
                hybridization = "sp2";
            elseif coordination >= 2
                hybridization = "sp3";
            else
                hybridization = "untyped";
                fallback = true;
            end
            parameter = baseParameter("atom", name, ...
                "kssolv-valence-typing-rules-v2", fallback);
            parameter.atomType = name + "." + hybridization;
            parameter.coordination = coordination;
            parameter.incidentBondOrders = orders;
            parameter.message = fallbackMessage(fallback, ...
                "No bonded environment was available for atom typing.");
        end

        function parameter = bond(first, second, order)
            arguments
                first
                second
                order (1,1) double {mustBePositive}
            end
            firstElement = kssolv.analysis.matgenlab.core.get_el_sp(first);
            secondElement = kssolv.analysis.matgenlab.core.get_el_sp(second);
            symbols = sort([string(firstElement.symbol), ...
                string(secondElement.symbol)]);
            key = strjoin(symbols, "|") + "|" + string(order);
            fallback = false;
            message = "";

            aromatic = aromaticParameters();
            if abs(order - 1.5) < 1e-12 && isKey(aromatic, char(key))
                value = aromatic(char(key));
                source = "kssolv-aromatic-bond-parameters-v1";
            else
                try
                    lengths = kssolv.analysis.matgenlab.core. ...
                        obtain_all_bond_lengths(firstElement, secondElement);
                    if ~isKey(lengths, order)
                        error("KSSOLV:Modeling:GeometryParameterOrder", ...
                            "No order %g geometry parameter for %s-%s.", ...
                            order, symbols(1), symbols(2));
                    end
                    value = lengths(order);
                    source = "frozen-pymatgen-bond-lengths";
                catch exception
                    if ~startsWith(exception.identifier, ...
                            ["KSSOLV:Matgenlab:Bonds:", ...
                            "KSSOLV:Modeling:GeometryParameterOrder"])
                        rethrow(exception)
                    end
                    firstRadius = finiteAtomicRadius(firstElement);
                    secondRadius = finiteAtomicRadius(secondElement);
                    value = firstRadius + secondRadius - ...
                        0.12 * max(order - 1, 0);
                    fallback = true;
                    source = "atomic-radius-fallback";
                    message = "No typed bond-length parameter was available.";
                end
            end

            parameter = baseParameter("bond", symbols, source, fallback);
            parameter.bondOrder = order;
            parameter.value = double(value);
            parameter.unit = "angstrom";
            parameter.forceConstant = 360 * max(1, order);
            parameter.forceConstantUnit = "kJ/(mol angstrom^2)";
            parameter.forceConstantSource = ...
                "kssolv-harmonic-bond-constants-v2";
            parameter.message = message;
            parameter.isEnergyModel = false;
        end

        function parameter = angle(first, center, second, incidentOrders)
            arguments
                first
                center
                second
                incidentOrders double
            end
            symbols = [string(first), string(center), string(second)];
            atomParameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.atom(center, incidentOrders);
            coordination = atomParameter.coordination;
            orders = atomParameter.incidentBondOrders;
            centerSymbol = string(center);
            if coordination >= 4
                value = 109.471;
            elseif coordination == 3
                value = 120;
            elseif coordination == 2 && ...
                    any(abs(orders - 1.5) < 1e-12)
                value = 120;
            elseif coordination == 2 && sum(orders) >= 4 - 1e-12
                value = 180;
            elseif coordination == 2 && any(centerSymbol == ["O", "S"])
                value = 104.5;
            elseif coordination == 2 && centerSymbol == "N"
                value = 120;
            else
                value = 109.471;
            end
            fallback = atomParameter.fallback;
            parameter = baseParameter("angle", symbols, ...
                "kssolv-valence-angle-rules-v2", fallback);
            parameter.atomType = atomParameter.atomType;
            parameter.value = value;
            parameter.unit = "degree";
            parameter.forceConstant = 80;
            parameter.forceConstantUnit = "kJ/(mol radian^2)";
            parameter.forceConstantSource = ...
                "kssolv-harmonic-angle-constants-v2";
            parameter.message = fallbackMessage(fallback, ...
                "The angle used the generic tetrahedral fallback.");
        end

        function parameter = torsion(first, second, third, fourth, order)
            arguments
                first
                second
                third
                fourth
                order (1,1) double {mustBePositive}
            end
            symbols = [string(first), string(second), ...
                string(third), string(fourth)];
            fallback = false;
            if abs(order - 1) < 1e-12
                periodicity = 3;
                phase = 0;
                forceConstant = 2.0;
                source = "kssolv-generic-sp3-torsion-v2";
            elseif abs(order - 1.5) < 1e-12 || ...
                    abs(order - 2) < 1e-12
                periodicity = 2;
                phase = 180;
                forceConstant = 12.0;
                source = "kssolv-generic-planar-torsion-v2";
            else
                periodicity = 1;
                phase = 180;
                forceConstant = 1.0;
                source = "kssolv-generic-torsion-fallback-v2";
                fallback = true;
            end
            parameter = baseParameter("torsion", symbols, ...
                source, fallback);
            parameter.centralBondOrder = order;
            parameter.periodicity = periodicity;
            parameter.phase = phase;
            parameter.phaseUnit = "degree";
            parameter.forceConstant = forceConstant;
            parameter.forceConstantUnit = "kJ/mol";
            parameter.message = fallbackMessage(fallback, ...
                "No typed central-bond torsion parameter was available.");
        end

        function parameter = nonbonded(first, second)
            arguments
                first
                second
            end
            bondParameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond(first, second, 1);
            symbols = sort([string(first), string(second)]);
            parameter = baseParameter("nonbonded-repulsion", symbols, ...
                "kssolv-short-range-repulsion-v2", ...
                bondParameter.fallback);
            parameter.cutoff = 0.72 * bondParameter.value;
            parameter.cutoffUnit = "angstrom";
            parameter.forceConstant = 200;
            parameter.forceConstantUnit = "kJ/(mol angstrom^2)";
            parameter.message = fallbackMessage(parameter.fallback, ...
                "The repulsion cutoff used atomic-radius fallback data.");
        end
    end
end

function parameter = baseParameter(kind, atoms, source, fallback)
parameter = struct( ...
    "schemaVersion", ...
    kssolv.modeling.forcefield.GeometryParameterProvider.SchemaVersion, ...
    "kind", string(kind), ...
    "atoms", string(atoms), ...
    "parameterSet", ...
    kssolv.modeling.forcefield.GeometryParameterProvider.ParameterSet, ...
    "source", string(source), ...
    "fallback", logical(fallback));
end

function message = fallbackMessage(fallback, value)
if fallback
    message = string(value);
else
    message = "";
end
end

function value = finiteAtomicRadius(element)
value = double(element.atomic_radius);
if ~isfinite(value), value = 0.8; end
end

function parameters = aromaticParameters()
persistent cache
if isempty(cache)
    cache = containers.Map("KeyType", "char", "ValueType", "double");
    cache("C|C|1.5") = 1.397;
    cache("C|N|1.5") = 1.340;
    cache("N|N|1.5") = 1.350;
    cache("C|O|1.5") = 1.360;
end
parameters = cache;
end
