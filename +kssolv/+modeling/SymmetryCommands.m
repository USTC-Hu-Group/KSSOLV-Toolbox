classdef SymmetryCommands
    %SYMMETRYCOMMANDS Symmetry analysis and standard-cell generation.

    methods (Static)
        function ids = commandIds()
            ids = [
                "find_symmetry"
                "primitive_cell"
                "conventional_cell"
                "wigner_seitz_cell"
                ];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.SymmetryCommands.commandIds() == ...
                string(commandId));
        end

        function result = execute(model, commandId, parameters)
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            symprec = double(kssolv.modeling.ParameterUtils.get( ...
                parameters, "symprec", 0.01));
            angleTolerance = double(kssolv.modeling.ParameterUtils.get( ...
                parameters, "angleTolerance", 5));
            analyzer = SpacegroupAnalyzer( ...
                model, symprec, angleTolerance);
            commandId = string(commandId);
            switch commandId
                case "find_symmetry"
                    dataset = analyzer.get_symmetry_dataset();
                    messageText = sprintf( ...
                        "%s (%s), international number %d", ...
                        string(dataset.international), ...
                        string(dataset.hall), dataset.number);
                    result = struct( ...
                        "model", model, "changed", false, ...
                        "message", string(messageText), "data", dataset);
                case "primitive_cell"
                    model = analyzer.get_primitive_standard_structure();
                    result = changedResult(model, "Primitive cell created.");
                case "conventional_cell"
                    model = analyzer.get_conventional_standard_structure();
                    result = changedResult( ...
                        model, "Conventional cell created.");
                case "wigner_seitz_cell"
                    facets = model.lattice.get_wigner_seitz_cell();
                    result = struct( ...
                        "model", model, "changed", false, ...
                        "message", sprintf( ...
                            "Wigner-Seitz cell contains %d facets.", ...
                            numel(facets)), ...
                        "data", {facets});
                otherwise
                    error("KSSOLV:Modeling:SymmetryCommand", ...
                        "Unsupported Symmetry Tools command '%s'.", commandId);
            end

            function value = changedResult(updatedModel, message)
                value = struct( ...
                    "model", updatedModel, "changed", true, ...
                    "message", string(message));
            end
        end
    end
end
