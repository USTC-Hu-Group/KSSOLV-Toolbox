classdef MoleculeDiagnostics
    %MOLECULEDIAGNOSTICS Deterministic valence and geometry checks.
    %
    % Diagnostics are intentionally rule based.  They do not claim to be
    % an electronic-structure calculation or an energy minimization.

    methods (Static)
        function report = inspect(molecule, options)
            arguments
                molecule kssolv.analysis.matgenlab.core.IMolecule
                options.collisionDistance (1,1) double {mustBePositive} = 0.55
                options.bondLengthTolerance (1,1) double {mustBePositive} = 0.35
            end
            bonds = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                topology(molecule);
            bondSums = zeros(molecule.num_sites, 1);
            for row = 1:size(bonds, 1)
                bondSums(bonds(row, 1)) = bondSums(bonds(row, 1)) + ...
                    bonds(row, 3);
                bondSums(bonds(row, 2)) = bondSums(bonds(row, 2)) + ...
                    bonds(row, 3);
            end

            atomIssues = repmat(struct( ...
                "siteIndex", 0, "symbol", "", "formalCharge", 0, ...
                "bondOrderSum", 0, "targetValence", 0, ...
                "severity", "", "code", "", "message", ""), 0, 1);
            for siteIndex = 1:molecule.num_sites
                symbol = string(molecule(siteIndex).specie.symbol);
                charge = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                    siteScalar(molecule(siteIndex), "formal_charge", 0);
                aromatic = logical(kssolv.modeling.chemistry. ...
                    MoleculeDiagnostics.siteScalar( ...
                    molecule(siteIndex), "is_aromatic", false));
                target = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                    targetValence(symbol, charge, aromatic, ...
                    bondSums(siteIndex));
                excess = bondSums(siteIndex) - target;
                if excess > 1e-8
                    atomIssues(end + 1) = issue(siteIndex, symbol, charge, ...
                        bondSums(siteIndex), target, "error", ...
                        "ILLEGAL_VALENCE", sprintf( ...
                        "%s%d has bond-order sum %.3g above target %.3g.", ...
                        symbol, siteIndex, bondSums(siteIndex), target)); %#ok<AGROW>
                elseif target - bondSums(siteIndex) > 1e-8 && symbol ~= "H"
                    atomIssues(end + 1) = issue(siteIndex, symbol, charge, ...
                        bondSums(siteIndex), target, "info", ...
                        "OPEN_VALENCE", sprintf( ...
                        "%s%d has %.3g open valence.", symbol, siteIndex, ...
                        target - bondSums(siteIndex))); %#ok<AGROW>
                end
            end

            collisions = zeros(0, 3);
            coordinates = molecule.cart_coords;
            for first = 1:molecule.num_sites
                for second = first + 1:molecule.num_sites
                    distance = norm(coordinates(first, :) - coordinates(second, :));
                    if distance < options.collisionDistance
                        collisions(end + 1, :) = ...
                            [first, second, distance]; %#ok<AGROW>
                    end
                end
            end

            abnormalBonds = zeros(0, 5);
            for row = 1:size(bonds, 1)
                first = bonds(row, 1); second = bonds(row, 2);
                actual = norm(coordinates(first, :) - coordinates(second, :));
                ideal = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                    idealBondLength(molecule(first).specie.symbol, ...
                    molecule(second).specie.symbol, bonds(row, 3));
                relativeError = abs(actual - ideal) / max(ideal, eps);
                if relativeError > options.bondLengthTolerance
                    abnormalBonds(end + 1, :) = ...
                        [first, second, actual, ideal, relativeError]; %#ok<AGROW>
                end
            end

            report = struct( ...
                "atomIssues", atomIssues, ...
                "collisions", collisions, ...
                "abnormalBonds", abnormalBonds, ...
                "bondOrderSums", bondSums, ...
                "hasErrors", any(string({atomIssues.severity}) == "error") || ...
                    ~isempty(collisions), ...
                "method", "rule-based-valence-and-geometry", ...
                "isEnergyMinimization", false);

            function value = issue(index, element, formalCharge, sumValue, ...
                    targetValue, severity, code, message)
                value = struct("siteIndex", index, "symbol", element, ...
                    "formalCharge", formalCharge, ...
                    "bondOrderSum", sumValue, ...
                    "targetValence", targetValue, ...
                    "severity", severity, "code", code, ...
                    "message", string(message));
            end
        end

        function bonds = topology(molecule)
            properties = molecule.properties;
            if isfield(properties, "topology") && ...
                    isstruct(properties.topology) && ...
                    isfield(properties.topology, "bonds")
                bonds = double(properties.topology.bonds);
            else
                pairs = molecule.get_covalent_bond_pairs(0.2);
                bonds = [pairs, ones(size(pairs, 1), 1)];
            end
            if isempty(bonds), bonds = zeros(0, 3); end
            if size(bonds, 2) ~= 3
                error("KSSOLV:Modeling:MoleculeTopology", ...
                    "Molecular topology bonds must be an N-by-3 table.");
            end
        end

        function value = siteScalar(site, name, fallback)
            properties = site.site_properties;
            if isfield(properties, name) && ...
                    ~isempty(properties.(name))
                value = properties.(name);
            else
                value = fallback;
            end
        end

        function target = targetValence(symbol, formalCharge, aromatic, bondSum)
            symbol = string(symbol);
            switch symbol
                case "H", target = 1;
                case {"F", "Cl", "Br", "I"}, target = 1;
                case {"O", "S", "Se"}, target = 2;
                case {"N", "P"}
                    if symbol == "P" && bondSum > 3
                        target = max(5, bondSum);
                    else
                        target = 3 + max(formalCharge, 0);
                    end
                case {"C", "Si"}, target = 4;
                case {"B", "Al"}, target = 3;
                otherwise, target = bondSum;
            end
            if aromatic
                if symbol == "C", target = 4;
                elseif symbol == "N", target = 3;
                else, target = max(target, bondSum);
                end
            end
            if symbol == "O" && formalCharge > 0, target = 3; end
            if symbol == "O" && formalCharge < 0
                if bondSum > 1 + 1e-8
                    target = 2;
                else
                    target = 1;
                end
            end
            if symbol == "N" && formalCharge < 0, target = 2; end
        end

        function value = idealBondLength(first, second, order)
            parameter = kssolv.modeling.chemistry. ...
                MoleculeDiagnostics.idealBondParameter(first, second, order);
            value = parameter.value;
        end

        function parameter = idealBondParameter(first, second, order)
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond(first, second, order);
        end
    end
end
