classdef EOSError < MException
    %EOSERROR Equation-of-state fitting failure.
    methods
        function obj = EOSError(message, varargin)
            obj@MException("KSSOLV:Matgenlab:EOS:FitError", ...
                message, varargin{:});
        end
    end
end
