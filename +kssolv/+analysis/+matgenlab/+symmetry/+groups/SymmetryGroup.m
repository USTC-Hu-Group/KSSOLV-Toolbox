classdef SymmetryGroup
    %SYMMETRYGROUP Base class for crystallographic symmetry groups.

    properties (SetAccess = protected)
        symbol (1,1) string = ""
        order (1,1) double = 0
        symmetry_ops cell = cell(1, 0)
    end

    methods
        function value = length(obj), value = numel(obj.symmetry_ops); end

        function tf = contains(obj, operation)
            if ~isa(operation, "kssolv.analysis.matgenlab.core.SymmOp")
                tf = false;
                return
            end
            tf = any(cellfun(@(candidate) ...
                kssolv.analysis.matgenlab.symmetry.groups.SymmetryGroup. ...
                operationsEqual(candidate, operation), obj.symmetry_ops));
        end

        function tf = is_subgroup(obj, supergroup)
            if ~isa(supergroup, ...
                    "kssolv.analysis.matgenlab.symmetry.groups.SymmetryGroup")
                tf = false;
                return
            end
            tf = all(cellfun(@(operation) supergroup.contains(operation), ...
                obj.symmetry_ops));
        end

        function tf = is_supergroup(obj, subgroup)
            tf = subgroup.is_subgroup(obj);
        end

        function value = to_pretty_string(obj), value = obj.symbol; end

        function value = to_latex_string(obj)
            value = regexprep(obj.to_pretty_string(), ...
                "_(\d+)", "$_{$1}$");
            value = regexprep(value, "-(\d)", "$\\overline{$1}$");
        end

        function value = to_unicode_string(obj)
            value = string(obj.to_pretty_string());
            value = replace(value, ...
                ["_0", "_1", "_2", "_3", "_4", ...
                "_5", "_6", "_7", "_8", "_9"], ...
                ["₀", "₁", "₂", "₃", "₄", ...
                "₅", "₆", "₇", "₈", "₉"]);
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                indices = reference(1).subs{1};
                if isscalar(indices)
                    value = obj.symmetry_ops{indices};
                else
                    value = obj.symmetry_ops(indices);
                end
                if ~isscalar(reference)
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                if isscalar(reference) && ...
                        strcmp(reference(1).type, ".")
                    varargout{1} = builtin("subsref", obj, reference);
                else
                    numberOutputs = max(1, nargout);
                    [varargout{1:numberOutputs}] = ...
                        builtin("subsref", obj, reference);
                end
            end
        end
    end

    methods (Static)
        function tf = operationsEqual(first, second, tolerance)
            if nargin < 3, tolerance = 1e-5; end
            firstMatrix = first.affine_matrix;
            secondMatrix = second.affine_matrix;
            rotationEqual = all(abs(firstMatrix(1:3, 1:3) - ...
                secondMatrix(1:3, 1:3)) <= tolerance, "all");
            translation = firstMatrix(1:3, 4) - secondMatrix(1:3, 4);
            translation = translation - round(translation);
            tf = rotationEqual && all(abs(translation) <= tolerance);
        end
    end
end
