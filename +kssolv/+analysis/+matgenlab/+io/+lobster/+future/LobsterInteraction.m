classdef LobsterInteraction
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERINTERACTION Value model for one LOBSTER interaction.
    properties
        index (1,1) double = 0
        centers cell = {}
        cells cell = {}
        orbitals cell = {}
        length = []
    end
    methods
        function obj = LobsterInteraction(value)
            if nargin == 0, return; end
            names = ["index", "centers", "cells", "orbitals", "length"];
            for name = names
                if isfield(value, name), obj.(name) = value.(name); end
            end
        end
        function value = as_dict(obj)
            value = struct("index", obj.index, "centers", {obj.centers}, ...
                "cells", {obj.cells}, "orbitals", {obj.orbitals}, ...
                "length", obj.length);
        end
    end
end
