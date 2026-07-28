classdef Hint
    properties
        ecut
        pawecutdg
    end
    methods
        function obj = Hint(ecut, pawecutdg)
            if nargin < 1, ecut = 0; end
            if nargin < 2 || isempty(pawecutdg), pawecutdg = ecut; end
            obj.ecut = ecut; obj.pawecutdg = pawecutdg;
        end
        function value = char(obj)
            value = sprintf("ecut: %g, pawecutdg: %g", obj.ecut, obj.pawecutdg);
        end
        function value = string(obj), value = string(char(obj)); end
        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.abinit.pseudos", ...
                "x_class", "Hint", "ecut", obj.ecut, "pawecutdg", obj.pawecutdg);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.abinit.Hint( ...
                value.ecut, value.pawecutdg);
        end
        function obj = fromDict(value), obj = kssolv.analysis.matgenlab.io.abinit.Hint.from_dict(value); end
    end
end
