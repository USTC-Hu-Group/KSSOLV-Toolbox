classdef DummySpecie < kssolv.analysis.matgenlab.core.DummySpecies
    %DUMMYSPECIE Backward-compatible alias for DummySpecies.
    methods
        function obj = DummySpecie(varargin)
            obj@kssolv.analysis.matgenlab.core.DummySpecies(varargin{:});
        end
    end
end
