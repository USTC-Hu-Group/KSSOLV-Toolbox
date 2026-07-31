classdef DefectCommands
    %DEFECTCOMMANDS Point-defect and special-quasirandom model builders.

    methods (Static)
        function ids = commandIds()
            ids = ["create_point_defects"; "generate_sqs_model"];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.DefectCommands.commandIds() == ...
                string(commandId));
        end

        function result = execute(model, commandId, parameters)
            commandId = string(commandId);
            switch commandId
                case "create_point_defects"
                    model = kssolv.modeling.DefectCommands. ...
                        createPointDefect(model, parameters);
                    message = "Point defect created.";
                case "generate_sqs_model"
                    scaling = kssolv.modeling.ParameterUtils.get( ...
                        parameters, "scaling", 1);
                    searchTime = double( ...
                        kssolv.modeling.ParameterUtils.get( ...
                        parameters, "searchTime", 60));
                    transformation = ...
                        kssolv.analysis.matgenlab.transformations. ...
                        SQSTransformation(scaling, [], searchTime);
                    model = transformation.apply_transformation(model);
                    metadata = model.properties.sqs;
                    message = sprintf( ...
                        "SQS model generated (%s, objective %.5g).", ...
                        metadata.search_mode, ...
                        metadata.objective_function);
                otherwise
                    error("KSSOLV:Modeling:DefectCommand", ...
                        "Unsupported Defects & Alloys command '%s'.", ...
                        commandId);
            end
            result = struct( ...
                "model", model, "changed", true, ...
                "message", string(message));
        end
    end

    methods (Static, Access = private)
        function model = createPointDefect(model, parameters)
            import kssolv.modeling.ParameterUtils
            defectType = lower(string(ParameterUtils.get( ...
                parameters, "defectType", "vacancy")));
            switch defectType
                case "vacancy"
                    index = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    if numel(index) ~= 1 || model.num_sites == 1
                        error("KSSOLV:Modeling:VacancyIndex", ...
                            "A vacancy requires one site and a non-singleton structure.");
                    end
                    model = model.remove_sites(index);
                case "substitution"
                    index = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    species = string(ParameterUtils.get( ...
                        parameters, "species", "H"));
                    if numel(index) ~= 1
                        error("KSSOLV:Modeling:SubstitutionIndex", ...
                            "A substitution requires exactly one site.");
                    end
                    model = model.replace(index, species);
                case "interstitial"
                    species = string(ParameterUtils.get( ...
                        parameters, "species", "H"));
                    coordinates = ParameterUtils.vector( ...
                        parameters, "coordinates", 3, [.5, .5, .5]);
                    cartesian = ParameterUtils.logical( ...
                        parameters, "cartesian", false);
                    model = model.append(species, coordinates, ...
                        coords_are_cartesian = cartesian, ...
                        validate_proximity = true);
                case "antisite"
                    indices = ParameterUtils.indices( ...
                        parameters, model.num_sites, []);
                    if numel(indices) ~= 2
                        error("KSSOLV:Modeling:AntisiteIndices", ...
                            "An antisite requires exactly two sites.");
                    end
                    firstSpecies = model(indices(1)).species;
                    secondSpecies = model(indices(2)).species;
                    model = model.replace(indices(1), secondSpecies);
                    model = model.replace(indices(2), firstSpecies);
                otherwise
                    error("KSSOLV:Modeling:DefectType", ...
                        "Defect type must be vacancy, substitution, " + ...
                        "interstitial or antisite.");
            end
        end
    end
end
