classdef (Abstract) AbstractStructureFilter < handle
    %ABSTRACTSTRUCTUREFILTER Base class for transmuter structure filters.

    methods (Abstract)
        accepted = test(obj, structure)
    end

    methods
        function value = asDict(obj)
            pieces = split(string(class(obj)), ".");
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", pieces(end), "x_version", []);
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end
end
