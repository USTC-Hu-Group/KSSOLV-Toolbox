classdef StructureFormat < kssolv.analysis.matgenlab.io.IOFormat
    %STRUCTUREFORMAT Plugin descriptor for periodic structure I/O.
    methods
        function obj=StructureFormat(varargin)
            obj@kssolv.analysis.matgenlab.io.IOFormat(varargin{:});
        end
    end
end
