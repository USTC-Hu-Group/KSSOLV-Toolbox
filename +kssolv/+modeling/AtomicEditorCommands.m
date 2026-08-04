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
            switch commandId
                case "add_atom"
                    species = string(ParameterUtils.get( ...
                        parameters, "species", "H"));
                    coords = ParameterUtils.vector( ...
                        parameters, "coordinates", 3, [0, 0, 0]);
                    cartesian = ParameterUtils.logical( ...
                        parameters, "cartesian", false);
                    model = model.append(species, coords, ...
                        coords_are_cartesian = cartesian, ...
                        validate_proximity = false);
                case "center_atoms"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, 1:model.num_sites);
                    center = ParameterUtils.vector( ...
                        parameters, "center", 3, [0.5, 0.5, 0.5]);
                    translation = center - mean(model.frac_coords(indices, :), 1);
                    model = model.translate_sites( ...
                        indices, translation, frac_coords = true);
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
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    movable = repmat({[true, true, true]}, 1, model.num_sites);
                    movable(indices) = repmat( ...
                        {[false, false, false]}, 1, numel(indices));
                    model = model.add_site_property( ...
                        "selective_dynamics", movable);
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
                    if numel(indices) ~= 1
                        error("KSSOLV:Modeling:MoveSingleSite", ...
                            "Move Atoms accepts exactly one site at a time.");
                    end
                    model = model.replace(indices, [], coordinates, ...
                        coords_are_cartesian = cartesian);
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
                    model = model.rotate_sites( ...
                        indices, angle, axis, anchor, true);
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
                    model = model.translate_sites( ...
                        indices, vector, frac_coords = fractional);
                otherwise
                    error("KSSOLV:Modeling:AtomicCommand", ...
                        "Unsupported Atomic Editor command '%s'.", commandId);
            end
            result = struct( ...
                "model", model, "changed", true, ...
                "message", "Structure updated.");
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
                model = model.replace(index, [], mirrored, ...
                    coords_are_cartesian = true);
            end
        end
    end
end
