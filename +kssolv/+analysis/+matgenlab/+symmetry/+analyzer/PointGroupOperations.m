classdef PointGroupOperations
    %POINTGROUPOPERATIONS Closed set of molecular point-group operations.

    properties (SetAccess = private)
        sch_symbol (1,1) string
        operations cell
        tol (1,1) double
    end

    methods
        function obj = PointGroupOperations(sch_symbol, operations, tol)
            if nargin < 3, tol = 0.1; end
            obj.sch_symbol = string(sch_symbol);
            obj.operations = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                generate_full_symmops(operations, tol);
            obj.tol = tol;
        end

        function value = length(obj), value = numel(obj.operations); end
        function value = char(obj), value = char(obj.sch_symbol); end
        function value = string(obj), value = obj.sch_symbol; end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                index = reference(1).subs{1};
                if isscalar(index)
                    value = obj.operations{index};
                else
                    value = obj.operations(index);
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
end
