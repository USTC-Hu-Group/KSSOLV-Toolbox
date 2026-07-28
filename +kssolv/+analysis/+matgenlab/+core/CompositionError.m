classdef CompositionError
    %COMPOSITIONERROR Typed composition-domain error for API compatibility.

    properties (SetAccess = private)
        message (1,1) string
        identifier (1,1) string = ...
            "KSSOLV:Matgenlab:Composition:CompositionError"
    end

    methods
        function obj = CompositionError(message)
            if nargin < 1, message = "Invalid composition."; end
            obj.message = string(message);
        end

        function throw(obj)
            error(obj.identifier, "%s", obj.message);
        end
    end
end
