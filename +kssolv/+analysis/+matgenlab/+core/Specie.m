classdef Specie < kssolv.analysis.matgenlab.core.Species
    %SPECIE Backward-compatible alias for the historical pymatgen name.
    methods
        function obj = Specie(varargin)
            obj@kssolv.analysis.matgenlab.core.Species(varargin{:});
        end
    end
end
