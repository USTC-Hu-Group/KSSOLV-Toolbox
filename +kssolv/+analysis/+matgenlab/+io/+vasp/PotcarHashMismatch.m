classdef PotcarHashMismatch
    %POTCARHASHMISMATCH Stable error category for requested hash checks.
    %
    % Frozen pymatgen removed cryptographic POTCAR validation. This category
    % is retained for callers that explicitly request downstream hash checks.
    properties (Constant)
        identifier = "KSSOLV:Matgenlab:PotcarHashMismatch"
    end
end
