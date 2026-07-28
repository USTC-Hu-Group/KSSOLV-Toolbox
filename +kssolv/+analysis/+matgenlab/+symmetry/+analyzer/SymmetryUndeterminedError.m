classdef SymmetryUndeterminedError < MException
    %SYMMETRYUNDETERMINEDERROR Symmetry could not be resolved by spglib.

    methods
        function obj = SymmetryUndeterminedError(message)
            if nargin < 1
                message = "Symmetry could not be determined.";
            end
            obj@MException( ...
                "KSSOLV:Matgenlab:SymmetryUndetermined", char(message));
        end
    end
end
