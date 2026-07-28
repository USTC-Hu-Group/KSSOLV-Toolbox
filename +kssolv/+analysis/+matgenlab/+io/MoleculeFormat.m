classdef MoleculeFormat < kssolv.analysis.matgenlab.io.IOFormat
    %MOLECULEFORMAT Plugin descriptor for molecular I/O.
    methods
        function obj=MoleculeFormat(varargin)
            obj@kssolv.analysis.matgenlab.io.IOFormat(varargin{:});
        end
    end
end
