classdef ParameterPresentation
    %PARAMETERPRESENTATION UI metadata for Modeling command parameters.

    methods (Static)
        function value = describe(commandId, field)
            commandId = string(commandId);
            name = string(field.name);
            value = struct( ...
                "name", name, ...
                "label", ...
                    kssolv.ui.features.modeling.ParameterPresentation. ...
                    fieldLabel(commandId, name, field.label), ...
                "tooltip", ...
                    kssolv.ui.features.modeling.ParameterPresentation. ...
                    fieldLabel(commandId, name, field.label), ...
                "control", string(field.kind), ...
                "choices", strings(0, 1), ...
                "choiceLabels", strings(0, 1), ...
                "shape", [], ...
                "integer", false, ...
                "minimum", -Inf, ...
                "maximum", Inf, ...
                "conditionField", "", ...
                "conditionValues", strings(0, 1));

            if field.kind == "logical"
                value.control = "logical";
            elseif field.kind == "numeric"
                value.control = "scalar";
            end

            if any(name == [
                    "coordinates", "center", "normal", ...
                    "point", "axis", "anchor", "vector", "order", ...
                    "millerIndex", "translation", "direction"])
                value.control = "vector";
                value.shape = 3;
            elseif name == "chiralIndices"
                value.control = "vector";
                value.shape = 2;
            elseif name == "matrix"
                value.control = "matrix";
                value.shape = [3, 3];
            elseif any(name == [
                    "indices", "strain", "scalingMatrix", "scaling"])
                value.control = "numericText";
            elseif endsWith(name, "StructureName")
                value.control = "structure";
            end

            if any(name == [
                    "indices", "axisIndex", "order", "scalingMatrix", ...
                    "scaling", "maximumAtoms", "searchTime", ...
                    "millerIndex", "targetCoordination", "moleculeCount", ...
                    "seed", "timeout", "maximumIndex", ...
                    "intermediateCount", "maximumSteps", ...
                    "chiralIndices", "length", "width", "direction"])
                value.integer = true;
            end
            if any(name == [
                    "indices", "axisIndex", "scaling", "maximumAtoms", ...
                    "searchTime", "moleculeCount", "timeout", ...
                    "maximumIndex", "intermediateCount", ...
                    "maximumSteps", "length", "width"])
                value.minimum = 1;
            elseif any(name == ["distance", "minimumDistance", ...
                    "minimumLength", "maximumLength", "angleTolerance", ...
                    "slabSize", "vacuumSize", "amount", "bondLength", ...
                    "surfaceThickness", "layerThickness", "clearance", ...
                    "vacuum", "tolerance", "gap", "forceTolerance", ...
                    "radius"])
                value.minimum = 0;
            end
            if name == "axisIndex"
                value.maximum = 3;
            elseif name == "angleTolerance"
                value.maximum = 10 - eps(10);
            end
            if any(name == [
                    "minimumLength", "maximumLength", "angleTolerance", ...
                    "slabSize", "amount", "bondLength", ...
                    "surfaceThickness", "layerThickness", "tolerance", ...
                    "gap", "forceTolerance", "radius"])
                value.minimum = eps;
            end

            [choices, choiceKeys] = ...
                kssolv.ui.features.modeling.ParameterPresentation. ...
                enumChoices(commandId, name);
            if ~isempty(choices)
                if name == "symprec"
                    value.control = "numericEnum";
                elseif any(name == ["cartesian", "fractional"])
                    value.control = "coordinateSystem";
                else
                    value.control = "enum";
                end
                value.choices = choices;
                value.choiceLabels = strings(size(choices));
                for index = 1:numel(choices)
                    value.choiceLabels(index) = ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:" + choiceKeys(index));
                end
            end

            if commandId == "create_point_defects"
                switch name
                    case "indices"
                        value.conditionField = "defectType";
                        value.conditionValues = [
                            "vacancy"; "substitution"; "antisite"];
                    case "species"
                        value.conditionField = "defectType";
                        value.conditionValues = [
                            "substitution"; "interstitial"];
                    case {"coordinates", "cartesian"}
                        value.conditionField = "defectType";
                        value.conditionValues = "interstitial";
                end
            elseif commandId == "quantum_dot_void" && name == "vacuum"
                value.conditionField = "mode";
                value.conditionValues = "dot";
            end
        end

        function label = fieldLabel(commandId, name, fallback)
            keys = [
                "KSSOLV:modeling:Field_" + string(commandId) + ...
                    "_" + string(name)
                "KSSOLV:modeling:Field_" + string(name)
                ];
            for index = 1:numel(keys)
                try
                    label = kssolv.ui.util.Localizer.message(keys(index));
                    return
                catch
                end
            end
            label = string(fallback);
        end
    end

    methods (Static, Access = private)
        function [choices, keys] = enumChoices(commandId, name)
            choices = strings(0, 1);
            keys = strings(0, 1);
            if any(name == ["cartesian", "fractional"])
                choices = ["fractional"; "cartesian"];
                keys = [
                    "ChoiceFractionalCoordinates"; ...
                    "ChoiceCartesianCoordinates"];
            elseif any(commandId == ["find_symmetry", ...
                    "primitive_cell", "conventional_cell"]) && ...
                    name == "symprec"
                choices = ["0.0001"; "0.001"; "0.01"; "0.1"];
                keys = [
                    "ChoiceToleranceVeryFine"; ...
                    "ChoiceToleranceFine"; ...
                    "ChoiceToleranceGood"; ...
                    "ChoiceToleranceCoarse"];
            elseif commandId == "merge_atoms" && name == "mode"
                choices = ["delete"; "sum"; "average"];
                keys = ["ChoiceDelete"; "ChoiceSum"; "ChoiceAverage"];
            elseif commandId == "create_point_defects" && ...
                    name == "defectType"
                choices = [
                    "vacancy"; "substitution"; ...
                    "interstitial"; "antisite"];
                keys = [
                    "Vacancy"; "Substitution"; ...
                    "Interstitial"; "Antisite"];
            elseif commandId == "cut_nanoribbon" && name == "edgeType"
                choices = ["zigzag"; "armchair"];
                keys = ["ChoiceZigzag"; "ChoiceArmchair"];
            elseif commandId == "quantum_dot_void" && name == "mode"
                choices = ["dot"; "void"];
                keys = ["QuantumDot"; "NanoVoid"];
            elseif commandId == "passivate_surface" && name == "side"
                choices = ["top"; "bottom"; "both"];
                keys = ["ChoiceTop"; "ChoiceBottom"; "ChoiceBoth"];
            end
        end
    end
end
