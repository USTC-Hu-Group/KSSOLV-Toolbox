classdef DictSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %DICTSET Backward-compatible configurable VaspInputSet.
    methods
        function obj = DictSet(structure, config_dict, varargin)
            if nargin < 1, structure = []; end
            if nargin < 2, config_dict = struct(); end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, config_dict, varargin{:});
            obj.set_name = "DictSet";
        end
    end
end
