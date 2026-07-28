classdef AbstractComparator < kssolv.analysis.matgenlab.util.MSONable
    %ABSTRACTCOMPARATOR Site-species comparison interface.

    methods
        function tf = are_equal(~,~,~)
            tf=false;
            exception=MException( ...
                "KSSOLV:Matgenlab:Comparator:Abstract", ...
                "are_equal must be implemented by a concrete comparator.");
            if ~tf,throwAsCaller(exception);end
        end

        function value = get_hash(~,~)
            value=[];
            exception=MException( ...
                "KSSOLV:Matgenlab:Comparator:Abstract", ...
                "get_hash must be implemented by a concrete comparator.");
            if isempty(value),throwAsCaller(exception);end
        end

        function value = asDict(obj)
            pieces = split(string(class(obj)), ".");
            value = struct("version", "1.0", "x_module", ...
                "pymatgen.core.structure_matcher", ...
                "x_class", pieces(end));
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            if isfield(value, "x_class")
                name = string(value.x_class);
            else
                error("KSSOLV:Matgenlab:Comparator:Dictionary", ...
                    "Comparator dictionary has no class field.");
            end
            valid = ["SpeciesComparator", "SpinComparator", ...
                "ElementComparator", "FrameworkComparator", ...
                "OrderDisorderElementComparator", "OccupancyComparator"];
            if ~any(name == valid)
                error("KSSOLV:Matgenlab:Comparator:Dictionary", ...
                    "Invalid comparator class '%s'.", name);
            end
            constructor = str2func( ...
                "kssolv.analysis.matgenlab.core." + name);
            obj = constructor();
        end
    end
end
