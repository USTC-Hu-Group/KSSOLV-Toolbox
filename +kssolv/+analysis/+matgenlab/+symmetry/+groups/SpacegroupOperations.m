classdef SpacegroupOperations < kssolv.analysis.matgenlab.util.MSONable
    %SPACEGROUPOPERATIONS Collection of operations for one space group.

    properties (SetAccess = private)
        int_symbol (1,1) string
        int_number (1,1) double
        symmops cell
    end

    methods
        function obj = SpacegroupOperations(int_symbol, int_number, symmops)
            arguments
                int_symbol {mustBeTextScalar}
                int_number (1,1) double {mustBeInteger}
                symmops
            end
            if ~(int_number == -1 || ...
                    (int_number >= 1 && int_number <= 230))
                error("KSSOLV:Matgenlab:SpacegroupOperations:Number", ...
                    "International space-group number must be -1 for an " + ...
                    "unparsed placeholder or between 1 and 230.");
            end
            if isa(symmops, "kssolv.analysis.matgenlab.core.SymmOp")
                symmops = num2cell(reshape(symmops, 1, []));
            elseif ~iscell(symmops)
                error("KSSOLV:Matgenlab:SpacegroupOperations:Operations", ...
                    "symmops must be a cell array or SymmOp array.");
            end
            symmops = reshape(symmops, 1, []);
            for index = 1:numel(symmops)
                if ~isa(symmops{index}, ...
                        "kssolv.analysis.matgenlab.core.SymmOp")
                    error("KSSOLV:Matgenlab:SpacegroupOperations:Operations", ...
                        "Every operation must be a matgenlab SymmOp.");
                end
            end
            obj.int_symbol = string(int_symbol);
            obj.int_number = int_number;
            obj.symmops = symmops;
        end

        function value = length(obj), value = numel(obj.symmops); end

        function value = char(obj)
            value = sprintf("%s (%d) spacegroup", ...
                obj.int_symbol, obj.int_number);
        end

        function value = string(obj), value = string(char(obj)); end

        function tf = are_symmetrically_equivalent( ...
                obj, sites1, sites2, symm_prec)
            if nargin < 4, symm_prec = 1e-3; end
            if ~iscell(sites1), sites1 = num2cell(sites1); end
            if ~iscell(sites2), sites2 = num2cell(sites2); end
            sites1 = reshape(sites1, 1, []);
            sites2 = reshape(sites2, 1, []);
            if numel(sites1) ~= numel(sites2)
                tf = false;
                return
            end
            tf = false;
            for operationIndex = 1:numel(obj.symmops)
                operation = obj.symmops{operationIndex};
                matched = false(1, numel(sites1));
                valid = true;
                for siteIndex = 1:numel(sites2)
                    site = sites2{siteIndex};
                    transformed = ...
                        kssolv.analysis.matgenlab.core.PeriodicSite( ...
                        site.species, operation.operate(site.frac_coords), ...
                        site.lattice);
                    found = false;
                    for candidateIndex = 1:numel(sites1)
                        if ~matched(candidateIndex) && ...
                                sites1{candidateIndex}.is_periodic_image( ...
                                transformed, symm_prec, false)
                            matched(candidateIndex) = true;
                            found = true;
                            break
                        end
                    end
                    if ~found
                        valid = false;
                        break
                    end
                end
                if valid
                    tf = true;
                    return
                end
            end
        end

        function tf = areSymmetricallyEquivalent(obj, varargin)
            tf = obj.are_symmetrically_equivalent(varargin{:});
        end

        function value = as_dict(obj)
            operations = cellfun(@(operation) operation.as_dict(), ...
                obj.symmops, "UniformOutput", false);
            value = struct( ...
                "x_module", "pymatgen.symmetry.analyzer", ...
                "x_class", "SpacegroupOperations", ...
                "int_symbol", obj.int_symbol, ...
                "int_number", obj.int_number, ...
                "symmops", {operations});
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                value = obj.symmops{reference(1).subs{1}};
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
        function obj = from_dict(value)
            operations = value.symmops;
            if isstruct(operations), operations = num2cell(operations); end
            operations = cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.SymmOp.from_dict(item), ...
                operations, "UniformOutput", false);
            obj = ...
                kssolv.analysis.matgenlab.symmetry.groups. ...
                SpacegroupOperations(value.int_symbol, ...
                value.int_number, operations);
        end
    end
end
