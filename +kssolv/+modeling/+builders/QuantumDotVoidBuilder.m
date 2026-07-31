classdef QuantumDotVoidBuilder
    %QUANTUMDOTVOIDBUILDER Extract a finite dot or remove a spherical void.

    methods (Static)
        function output = build(parent, radius, mode, options)
            arguments
                parent
                radius (1,1) double
                mode {mustBeTextScalar} = "dot"
                options.vacuum (1,1) double = 8
                options.maximumAtoms (1,1) double = 100000
            end
            import kssolv.modeling.builders.BuilderUtils
            BuilderUtils.requireStructure(parent);
            radius = BuilderUtils.positiveScalar(radius, "Radius");
            vacuum = BuilderUtils.positiveScalar( ...
                options.vacuum, "Vacuum");
            maximumAtoms = BuilderUtils.positiveInteger( ...
                options.maximumAtoms, "Maximum atom count");
            mode = lower(string(mode));
            switch mode
                case "dot"
                    output = ...
                        kssolv.modeling.builders. ...
                        QuantumDotVoidBuilder.dot( ...
                        parent, radius, vacuum, maximumAtoms);
                case "void"
                    output = ...
                        kssolv.modeling.builders. ...
                        QuantumDotVoidBuilder.void( ...
                        parent, radius);
                otherwise
                    error("KSSOLV:Modeling:NanoRegionMode", ...
                        "Mode must be 'dot' or 'void'.");
            end
        end
    end

    methods (Static, Access = private)
        function output = dot(parent, radius, vacuum, maximumAtoms)
            import kssolv.modeling.builders.BuilderUtils
            repeats = max(1, ceil(2 * radius ./ ...
                parent.lattice.lengths) + 2);
            predicted = prod(repeats) * parent.num_sites;
            if predicted > maximumAtoms
                error("KSSOLV:Modeling:QuantumDotAtomLimit", ...
                    "The dot parent supercell would contain %d atoms " + ...
                    "(limit %d).", predicted, maximumAtoms);
            end
            supercell = parent.make_supercell(repeats, true, false);
            positions = supercell.cart_coords;
            % The Cartesian center of a parallelepiped is one half of the
            % sum of its three lattice vectors.  Using mean(...)/2 would
            % place the cutting sphere at one third of the true center.
            center = sum(supercell.lattice.matrix, 1) / 2;
            distances = vecnorm(positions - center, 2, 2);
            indices = find(distances <= radius + 1e-8).';
            if isempty(indices)
                error("KSSOLV:Modeling:QuantumDotEmpty", ...
                    "No sites fall inside the requested dot radius.");
            end
            selected = positions(indices, :);
            selected = selected - min(selected, [], 1) + vacuum;
            spans = max(selected, [], 1) - min(selected, [], 1);
            lattice = diag(spans + 2 * vacuum);
            output = BuilderUtils.fromCartesian( ...
                supercell, lattice, selected, indices, ...
                [false, false, false]);
            output.properties.nano_region = struct( ...
                "mode", "dot", "radius", radius, ...
                "source_center_cartesian", center, ...
                "source_supercell_lattice", ...
                supercell.lattice.matrix);
        end

        function output = void(parent, radius)
            coordinates = parent.frac_coords;
            delta = coordinates - 0.5;
            delta(:, parent.pbc) = ...
                delta(:, parent.pbc) - round(delta(:, parent.pbc));
            distances = vecnorm(delta * parent.lattice.matrix, 2, 2);
            remove = find(distances < radius - 1e-8);
            if isempty(remove)
                error("KSSOLV:Modeling:NanoVoidEmpty", ...
                    "The requested radius does not remove any sites.");
            end
            if numel(remove) == parent.num_sites
                error("KSSOLV:Modeling:NanoVoidAllSites", ...
                    "The requested void would remove every site.");
            end
            output = parent.remove_sites(remove);
            output.properties.nano_region = struct( ...
                "mode", "void", "radius", radius, ...
                "center_fractional", [0.5, 0.5, 0.5]);
        end
    end
end
