classdef ShiftMode
    properties (Constant)
        GammaCentered = "G"
        MonkhorstPack = "M"
        Symmetric = "S"
        OneSymmetric = "O"
    end
    methods (Static)
        function value = from_object(input)
            input = string(input);
            if ~isscalar(input) || strlength(input) == 0
                error("KSSOLV:Matgenlab:Abinit:ShiftMode", "The object provided is not handled.");
            end
            initial = upper(extractBetween(input, 1, 1));
            if ~ismember(initial, ["G","M","S","O"])
                error("KSSOLV:Matgenlab:Abinit:ShiftMode", "Unknown shift mode '%s'.", input);
            end
            value = initial;
        end
    end
end
