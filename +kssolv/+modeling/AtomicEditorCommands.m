classdef AtomicEditorCommands
    %ATOMICEDITORCOMMANDS Atom-level structure transformations.

    methods (Static)
        function ids = commandIds()
            ids = [
                "add_atom"
                "center_atoms"
                "delete_atoms"
                "merge_atoms"
                "fix_atoms"
                "mirror_atoms"
                "move_atoms"
                "perturb_atoms"
                "sort_atoms"
                "rotate_atoms"
                "substitute_atoms"
                "translate_atoms"
                ];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.AtomicEditorCommands.commandIds() == ...
                string(commandId));
        end

        function result = execute(model, commandId, parameters)
            import kssolv.modeling.ParameterUtils
            commandId = string(commandId);
            [parameters, symmetryPlan] = ...
                kssolv.modeling.SymmetryEditPlanner.prepare( ...
                model, parameters);
            switch commandId
                case "add_atom"
                    species = string(ParameterUtils.get( ...
                        parameters, "species", "H"));
                    coords = ParameterUtils.vector( ...
                        parameters, "coordinates", 3, [0, 0, 0]);
                    isMolecule = isa(model, ...
                        "kssolv.analysis.matgenlab.core.IMolecule");
                    cartesian = ParameterUtils.logical( ...
                        parameters, "cartesian", isMolecule);
                    if isMolecule
                        if ~cartesian
                            error("KSSOLV:Modeling:MoleculeCoordinates", ...
                                "Molecule coordinates must be Cartesian.");
                        end
                        model = model.append(species, coords, ...
                            validate_proximity = false);
                    else
                        model = model.append(species, coords, ...
                            coords_are_cartesian = cartesian, ...
                            validate_proximity = false);
                    end
                case "center_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, 1:model.num_sites);
                    if isa(model, ...
                            "kssolv.analysis.matgenlab.core.IMolecule")
                        center = ParameterUtils.vector( ...
                            parameters, "center", 3, [0, 0, 0]);
                        translation = center - ...
                            mean(model.cart_coords(indices, :), 1);
                        model = model.translate_sites(indices, translation);
                    else
                        center = ParameterUtils.vector( ...
                            parameters, "center", 3, [0.5, 0.5, 0.5]);
                        translation = center - ...
                            mean(model.frac_coords(indices, :), 1);
                        model = model.translate_sites( ...
                            indices, translation, frac_coords = true);
                    end
                case "delete_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    model = model.remove_sites(indices);
                case "merge_atoms"
                    tolerance = double(ParameterUtils.get( ...
                        parameters, "tolerance", 0.01));
                    mode = string(ParameterUtils.get( ...
                        parameters, "mode", "delete"));
                    model = model.merge_sites(tolerance, mode);
                case "fix_atoms"
                    layerCount = double(ParameterUtils.get( ...
                        parameters, "bottomLayerCount", 0));
                    if layerCount > 0 && isa(model, ...
                            "kssolv.analysis.matgenlab.core.IStructure") && ...
                            isfield(model.site_properties, "surface_layer")
                        layerValues = model.site_properties.surface_layer;
                        if iscell(layerValues)
                            layerValues = cell2mat(layerValues);
                        end
                        indices = find(double(layerValues) <= layerCount);
                    else
                        indices = ParameterUtils.indices( ...
                            parameters, model.num_sites, []);
                    end
                    movable = repmat({[true, true, true]}, 1, model.num_sites);
                    movable(indices) = repmat( ...
                        {[false, false, false]}, 1, numel(indices));
                    model = model.add_site_property( ...
                        "selective_dynamics", movable);
                    if isa(model, ...
                            "kssolv.analysis.matgenlab.core.IStructure")
                        fixed = false(1, model.num_sites);
                        fixed(indices) = true;
                        model = model.add_site_property( ...
                            "surface_fixed", num2cell(fixed));
                    end
                case "mirror_atoms"
                    model = kssolv.modeling.AtomicEditorCommands. ...
                        mirrorAtoms(model, parameters);
                case "move_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    coordinates = ParameterUtils.vector( ...
                        parameters, "coordinates", 3, [0, 0, 0]);
                    cartesian = ParameterUtils.logical( ...
                        parameters, "cartesian", true);
                    if isempty(symmetryPlan) && numel(indices) ~= 1
                        error("KSSOLV:Modeling:MoveSingleSite", ...
                            "Move Atoms accepts exactly one site at a time.");
                    end
                    if isa(model, ...
                            "kssolv.analysis.matgenlab.core.IMolecule")
                        if ~cartesian
                            error("KSSOLV:Modeling:MoleculeCoordinates", ...
                                "Molecule coordinates must be Cartesian.");
                        end
                        model = model.replace(indices, [], coordinates);
                    else
                        if ~isempty(symmetryPlan) && ...
                                symmetryPlan.mode == "preserve"
                            primary = symmetryPlan.selectedIndices(1);
                            if cartesian
                                delta = coordinates - ...
                                    model.cart_coords(primary, :);
                                model = model.translate_sites(indices, delta);
                            else
                                delta = coordinates - ...
                                    model.frac_coords(primary, :);
                                model = model.translate_sites( ...
                                    indices, delta, frac_coords = true);
                            end
                        else
                            model = model.replace(indices, [], coordinates, ...
                                coords_are_cartesian = cartesian);
                        end
                    end
                case "perturb_atoms"
                    distance = double(ParameterUtils.get( ...
                        parameters, "distance", 0.1));
                    minimum = double(ParameterUtils.get( ...
                        parameters, "minimumDistance", 0));
                    seed = ParameterUtils.get(parameters, "seed", 0);
                    model = model.perturb(distance, minimum, seed);
                case "sort_atoms"
                    reverse = ParameterUtils.logical( ...
                        parameters, "reverse", false);
                    model = model.sort([], reverse);
                case "rotate_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, 1:model.num_sites);
                    angle = deg2rad(double(ParameterUtils.get( ...
                        parameters, "angleDegrees", 0)));
                    axis = ParameterUtils.vector( ...
                        parameters, "axis", 3, [0, 0, 1]);
                    anchor = ParameterUtils.vector( ...
                        parameters, "anchor", 3, [0, 0, 0]);
                    if isa(model, ...
                            "kssolv.analysis.matgenlab.core.IMolecule")
                        model = model.rotate_sites( ...
                            indices, angle, axis, anchor);
                    else
                        model = model.rotate_sites( ...
                            indices, angle, axis, anchor, true);
                    end
                case "substitute_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    species = string(ParameterUtils.get( ...
                        parameters, "species", "H"));
                    for index = indices
                        model = model.replace(index, species);
                    end
                case "translate_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, 1:model.num_sites);
                    vector = ParameterUtils.vector( ...
                        parameters, "vector", 3, [0, 0, 0]);
                    fractional = ParameterUtils.logical( ...
                        parameters, "fractional", false);
                    if isa(model, ...
                            "kssolv.analysis.matgenlab.core.IMolecule")
                        if fractional
                            error("KSSOLV:Modeling:MoleculeCoordinates", ...
                                "Molecule translations must be Cartesian.");
                        end
                        model = model.translate_sites(indices, vector);
                    else
                        model = model.translate_sites( ...
                            indices, vector, frac_coords = fractional);
                    end
                otherwise
                    error("KSSOLV:Modeling:AtomicCommand", ...
                        "Unsupported Atomic Editor command '%s'.", commandId);
            end
            [model, symmetryPlan] = ...
                kssolv.modeling.SymmetryEditPlanner.finalize( ...
                model, symmetryPlan);
            analysis = struct();
            analysis.symmetryImpact = symmetryPlan;
            result = struct( ...
                "model", model, "changed", true, ...
                "message", "Structure updated.", ...
                "analysis", analysis);
        end
    end

    methods (Static, Access = private)
        function model = mirrorAtoms(model, parameters)
            import kssolv.modeling.ParameterUtils
            indices = ParameterUtils.indices( ...
                parameters, model.num_sites, 1:model.num_sites);
            normal = ParameterUtils.vector( ...
                parameters, "normal", 3, [1, 0, 0]);
            point = ParameterUtils.vector( ...
                parameters, "point", 3, [0, 0, 0]);
            if norm(normal) <= eps
                error("KSSOLV:Modeling:MirrorNormal", ...
                    "The mirror-plane normal cannot be zero.");
            end
            normal = normal / norm(normal);
            for index = indices
                site = model.sites{index};
                mirrored = site.coords - ...
                    2 * dot(site.coords - point, normal) * normal;
                if isa(model, ...
                        "kssolv.analysis.matgenlab.core.IMolecule")
                    model = model.replace(index, [], mirrored);
                else
                    model = model.replace(index, [], mirrored, ...
                        coords_are_cartesian = true);
                end
            end
        end
    end
end
