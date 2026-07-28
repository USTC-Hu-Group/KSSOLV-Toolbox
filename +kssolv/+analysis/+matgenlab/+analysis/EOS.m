classdef EOS
    %EOS Equation-of-state model selector and fitting facade.
    properties (SetAccess = immutable)
        eos_name (1,1) string
        model (1,1) string
    end

    methods
        function obj = EOS(name)
            if nargin < 1 || isempty(name), name = "murnaghan"; end
            name = string(name);
            supported = ["murnaghan","birch","birch_murnaghan", ...
                "pourier_tarantola","vinet","deltafactor","numerical_eos"];
            if ~any(name == supported)
                throw(kssolv.analysis.matgenlab.analysis.EOSError( ...
                    "The equation of state '%s' is not supported.", name));
            end
            obj.eos_name = name;
            obj.model = name;
        end

        function value = fit(obj, volumes, energies)
            prefix = "kssolv.analysis.matgenlab.analysis.";
            switch obj.eos_name
                case "murnaghan", className = prefix+"Murnaghan";
                case "birch", className = prefix+"Birch";
                case "birch_murnaghan", className = prefix+"BirchMurnaghan";
                case "pourier_tarantola", className = prefix+"PourierTarantola";
                case "vinet", className = prefix+"Vinet";
                case "deltafactor", className = prefix+"DeltaFactor";
                otherwise, className = prefix+"NumericalEOS";
            end
            constructor = str2func(className);
            value = constructor(volumes, energies);
            value = value.fit();
        end
    end
end
