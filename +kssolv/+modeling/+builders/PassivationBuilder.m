classdef PassivationBuilder
    %PASSIVATIONBUILDER Terminate under-coordinated slab surface sites.
    %
    % Coordination uses the mature Jmol covalent-radius criterion. Missing
    % bonds are directed from the negative vector sum of present bonds and
    % constrained to the requested outward slab normal.

    methods (Static)
        function output = build(source, passivant, options)
            arguments
                source
                passivant {mustBeTextScalar} = "H"
                options.bondLength (1,1) double = 1.1
                options.side {mustBeTextScalar} = "both"
                options.surfaceThickness (1,1) double = 1.5
                options.neighborTolerance (1,1) double = 0.45
                options.targetCoordination (1,1) double = 0
                options.minimumDistance (1,1) double = 0.6
                options.maximumAddedAtoms (1,1) double = 10000
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireStructure(source);
            passivant = string(passivant);
            if strlength(passivant) == 0
                error("KSSOLV:Modeling:Passivant", ...
                    "Passivant species cannot be empty.");
            end
            % Validate the element symbol before any geometry is changed.
            kssolv.analysis.matgenlab.core.Element(passivant);
            bondLength = BuilderUtils.positiveScalar( ...
                options.bondLength, "Passivant bond length");
            surfaceThickness = BuilderUtils.positiveScalar( ...
                options.surfaceThickness, "Surface thickness");
            minimumDistance = BuilderUtils.positiveScalar( ...
                options.minimumDistance, "Minimum distance");
            maximumAddedAtoms = BuilderUtils.positiveInteger( ...
                options.maximumAddedAtoms, "Maximum added atom count");
            side = lower(string(options.side));
            if ~any(side == ["top", "bottom", "both"])
                error("KSSOLV:Modeling:PassivationSide", ...
                    "Passivation side must be top, bottom or both.");
            end
            targetCoordination = double(options.targetCoordination);
            if ~isscalar(targetCoordination) || ...
                    ~isfinite(targetCoordination) || ...
                    targetCoordination < 0 || ...
                    targetCoordination ~= fix(targetCoordination)
                error("KSSOLV:Modeling:PassivationCoordination", ...
                    "Target coordination must be a nonnegative integer.");
            end

            normal = cross(source.lattice.matrix(1, :), ...
                source.lattice.matrix(2, :));
            if norm(normal) <= 1e-12
                error("KSSOLV:Modeling:PassivationNormal", ...
                    "The first two lattice vectors do not define a slab.");
            end
            normal = normal / norm(normal);
            projections = source.cart_coords * normal.';
            lowerProjection = min(projections);
            upperProjection = max(projections);
            finder = kssolv.analysis.matgenlab.core.JmolNN( ...
                "tol", options.neighborTolerance);
            neighbors = cell(1, source.num_sites);
            counts = zeros(1, source.num_sites);
            symbols = strings(1, source.num_sites);
            for index = 1:source.num_sites
                if ~source(index).is_ordered
                    error("KSSOLV:Modeling:PassivationOrdered", ...
                        "Surface passivation requires ordered sites.");
                end
                symbols(index) = source(index).specie.symbol;
                neighbors{index} = finder.get_nn_info(source, index);
                counts(index) = numel(neighbors{index});
            end
            targets = counts;
            for symbol = unique(symbols)
                selected = symbols == symbol;
                if targetCoordination > 0
                    targets(selected) = targetCoordination;
                else
                    targets(selected) = max(counts(selected));
                end
            end

            coordinates = zeros(0, 3);
            parents = zeros(1, 0);
            for index = 1:source.num_sites
                isTop = projections(index) >= ...
                    upperProjection - surfaceThickness;
                isBottom = projections(index) <= ...
                    lowerProjection + surfaceThickness;
                useTop = isTop && any(side == ["top", "both"]);
                useBottom = isBottom && any(side == ["bottom", "both"]);
                if ~(useTop || useBottom) || counts(index) >= targets(index)
                    continue
                end
                if useTop && useBottom
                    if projections(index) >= ...
                            (upperProjection + lowerProjection) / 2
                        outward = normal;
                    else
                        outward = -normal;
                    end
                elseif useTop
                    outward = normal;
                else
                    outward = -normal;
                end
                directions = ...
                    kssolv.modeling.builders.PassivationBuilder. ...
                    missingDirections(source(index).coords, ...
                    neighbors{index}, outward, ...
                    targets(index) - counts(index));
                for direction = directions.'
                    candidate = source(index).coords + ...
                        bondLength * direction.';
                    if kssolv.modeling.builders.PassivationBuilder. ...
                            isCollision(source, coordinates, candidate, ...
                            minimumDistance)
                        continue
                    end
                    coordinates(end + 1, :) = candidate; %#ok<AGROW>
                    parents(end + 1) = index; %#ok<AGROW>
                    if size(coordinates, 1) > maximumAddedAtoms
                        error("KSSOLV:Modeling:PassivationAtomLimit", ...
                            "Passivation exceeds the maximum added atom count.");
                    end
                end
            end
            if isempty(coordinates)
                error("KSSOLV:Modeling:NoPassivationSites", ...
                    "No collision-free under-coordinated surface sites " + ...
                    "were found. For a very thin slab or monolayer, set " + ...
                    "Target coordination explicitly instead of using " + ...
                    "automatic inference.");
            end

            newCount = size(coordinates, 1);
            properties = BuilderUtils.combineProperties( ...
                source.site_properties, struct(), source.num_sites, newCount);
            properties.modeling_origin = [
                repmat({"source"}, 1, source.num_sites), ...
                repmat({"passivant"}, 1, newCount)];
            properties.passivation_parent = [
                repmat({[]}, 1, source.num_sites), num2cell(parents)];
            output = kssolv.analysis.matgenlab.core.Structure( ...
                source.lattice, ...
                [source.species_and_occu, repmat({passivant}, 1, newCount)], ...
                [source.cart_coords; coordinates], ...
                coords_are_cartesian = true, ...
                site_properties = properties, ...
                labels = [source.labels, repmat({char(passivant)}, 1, newCount)], ...
                properties = source.structure_properties, ...
                skip_checks = true);
            output.properties.passivation = struct( ...
                "method", "Jmol coordination deficit", ...
                "species", passivant, "side", side, ...
                "bond_length", bondLength, ...
                "surface_thickness", surfaceThickness, ...
                "added_atoms", newCount);
        end
    end

    methods (Static, Access = private)
        function directions = missingDirections(center, neighbors, ...
                outward, deficit)
            present = zeros(numel(neighbors), 3);
            for index = 1:numel(neighbors)
                vector = neighbors{index}.site.coords - center;
                present(index, :) = vector / norm(vector);
            end
            base = -sum(present, 1);
            if norm(base) <= 1e-8
                base = outward;
            else
                base = base / norm(base);
                if dot(base, outward) < 0.15
                    base = base + (0.15 - dot(base, outward)) * outward;
                end
                base = base / norm(base);
            end
            if deficit == 1
                directions = base;
                return
            end
            [first, second] = ...
                kssolv.modeling.builders.BuilderUtils.frame( ...
                base, outward);
            directions = zeros(deficit, 3);
            cone = deg2rad(30);
            for index = 1:deficit
                angle = 2 * pi * (index - 1) / deficit;
                value = cos(cone) * base + sin(cone) * ...
                    (cos(angle) * first + sin(angle) * second);
                if dot(value, outward) <= 0
                    value = value + outward;
                end
                directions(index, :) = value / norm(value);
            end
        end

        function value = isCollision(source, accepted, candidate, limit)
            fractional = source.lattice.get_fractional_coords(candidate);
            distances = source.lattice.get_all_distances( ...
                source.frac_coords, fractional);
            value = any(distances(:) < limit);
            if ~value && ~isempty(accepted)
                acceptedFractional = ...
                    source.lattice.get_fractional_coords(accepted);
                distances = source.lattice.get_all_distances( ...
                    acceptedFractional, fractional);
                value = any(distances(:) < limit);
            end
        end
    end
end
