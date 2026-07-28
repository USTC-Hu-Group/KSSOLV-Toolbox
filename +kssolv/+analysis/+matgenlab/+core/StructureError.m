classdef StructureError
    %STRUCTUREERROR Typed factory for structure-related MExceptions.

    methods (Static)
        function exception = create(message, varargin)
            exception = MException( ...
                "KSSOLV:Matgenlab:StructureError", message, varargin{:});
        end

        function throw(message, varargin)
            throwAsCaller( ...
                kssolv.analysis.matgenlab.core.StructureError. ...
                create(message, varargin{:}));
        end
    end
end
