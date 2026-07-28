classdef Entry < kssolv.analysis.matgenlab.core.Entry
    %ENTRY Backward-compatible pymatgen.entries.Entry namespace alias.

    methods
        function obj=Entry(varargin)
            obj@kssolv.analysis.matgenlab.core.Entry(varargin{:});
        end
    end
end
