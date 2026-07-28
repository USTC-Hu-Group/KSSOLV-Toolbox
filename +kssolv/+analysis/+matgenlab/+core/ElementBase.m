classdef ElementBase < kssolv.analysis.matgenlab.core.Element
    %ELEMENTBASE Compatibility name for pymatgen's generated element base.
    %
    % pymatgen-core exposes ElementBase as the implementation base for its
    % generated Element enum. MATLAB has no equivalent enum metaclass
    % generation, so ElementBase delegates to the immutable Element value
    % object while preserving the full public surface.

    methods
        function obj = ElementBase(symbol)
            if nargin < 1, symbol = "H"; end
            obj@kssolv.analysis.matgenlab.core.Element(symbol);
        end
    end
end
