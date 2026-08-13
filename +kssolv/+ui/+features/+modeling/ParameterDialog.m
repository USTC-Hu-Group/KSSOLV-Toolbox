classdef ParameterDialog
    %PARAMETERDIALOG Compatibility facade for the Modeling command dialog.

    methods (Static)
        function [parameters, cancelled] = prompt( ...
                commandInfo, display, preset, varargin)
            if nargin < 3
                preset = struct();
            end
            dialog = kssolv.ui.features.modeling.CommandDialog( ...
                commandInfo, display, preset);
            cleanup = onCleanup(@()deleteIfValid(dialog));
            [parameters, cancelled] = dialog.show(varargin{:});
            clear cleanup

            function deleteIfValid(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
            end
        end

        function value = parseValue(text, kind, label)
            text = strtrim(string(text));
            switch string(kind)
                case "text"
                    if text == ""
                        error("KSSOLV:Modeling:EmptyParameter", ...
                            "'%s' cannot be empty.", label);
                    end
                    value = text;
                case "optionalText"
                    value = text;
                case "logical"
                    normalized = lower(text);
                    if any(normalized == ["true", "1", "yes", "on"])
                        value = true;
                    elseif any(normalized == ["false", "0", "no", "off"])
                        value = false;
                    else
                        error("KSSOLV:Modeling:LogicalParameter", ...
                            "'%s' must be true or false.", label);
                    end
                case "numeric"
                    value = ...
                        kssolv.ui.features.modeling.ParameterDialog.parseNumeric( ...
                        text, label);
                case "optionalNumeric"
                    if text == ""
                        value = zeros(1,0);
                    else
                        value = kssolv.ui.features.modeling.ParameterDialog. ...
                            parseNumeric(text,label);
                    end
                otherwise
                    error("KSSOLV:Modeling:ParameterKind", ...
                        "Unsupported parameter type '%s'.", kind);
            end
        end

        function value = parseNumeric(text, label)
            text = erase(text, ["[", "]", "(", ")"]);
            rowText = split(text, [";", newline]);
            rowText = rowText(strlength(strtrim(rowText)) > 0);
            if isempty(rowText)
                error("KSSOLV:Modeling:NumericParameter", ...
                    "'%s' must contain numeric values.", label);
            end
            rows = cell(numel(rowText), 1);
            width = 0;
            for index = 1:numel(rowText)
                normalized = replace(rowText(index), ",", " ");
                values = sscanf(char(normalized), "%f").';
                if isempty(values)
                    error("KSSOLV:Modeling:NumericParameter", ...
                        "'%s' contains invalid numeric text.", label);
                end
                if index == 1
                    width = numel(values);
                elseif numel(values) ~= width
                    error("KSSOLV:Modeling:NumericShape", ...
                        "Every row in '%s' must have the same length.", label);
                end
                rows{index} = values;
            end
            value = vertcat(rows{:});
        end
    end
end
