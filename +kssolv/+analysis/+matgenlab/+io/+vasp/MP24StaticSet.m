classdef MP24StaticSet < kssolv.analysis.matgenlab.io.vasp.MP24RelaxSet
    %MP24STATICSET Materials Project 2024 static inputs.
    methods
        function obj = MP24StaticSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.MP24RelaxSet( ...
                structure, varargin{:});
            obj.set_name = "MP24StaticSet";
            obj.extra_incar_updates = struct( ...
                "NSW",0,"LORBIT",11,"ISMEAR",-5);
        end
    end
end
