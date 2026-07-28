classdef SpacegroupOperations < ...
        kssolv.analysis.matgenlab.symmetry.groups.SpacegroupOperations
    %SPACEGROUPOPERATIONS Upstream-module alias for compatibility.

    methods
        function obj = SpacegroupOperations(varargin)
            obj@kssolv.analysis.matgenlab.symmetry.groups. ...
                SpacegroupOperations(varargin{:});
        end
    end
end
