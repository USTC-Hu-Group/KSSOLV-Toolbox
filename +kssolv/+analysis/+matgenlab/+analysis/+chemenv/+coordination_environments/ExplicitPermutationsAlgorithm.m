classdef ExplicitPermutationsAlgorithm < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.AbstractChemenvAlgorithm
    %EXPLICITPERMUTATIONSALGORITHM Explicit CSM permutations.
    properties (SetAccess=private)
        permutations cell={}
    end
    methods
        function obj=ExplicitPermutationsAlgorithm(permutations)
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractChemenvAlgorithm( ...
                "EXPLICIT_PERMUTATIONS");
            if nargin>0,obj.permutations=rowsToCells(permutations);end
        end
        function value=char(obj),value=char(obj.algorithm_type);end
        function value=string(obj),value=obj.algorithm_type;end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.coordination_geometries", ...
                x_class="ExplicitPermutationsAlgorithm", ...
                permutations={cellfun(@(x)x-1,obj.permutations, ...
                "UniformOutput",false)});
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments. ...
                ExplicitPermutationsAlgorithm.from_dictWire(value);
        end
        function obj=from_dictWire(value)
            raw=rowsToCells(value.permutations);
            raw=cellfun(@(x)x+1,raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.ExplicitPermutationsAlgorithm(raw);
        end
    end
end
function out=rowsToCells(value)
if isempty(value),out={};elseif iscell(value),out=value(:).'; ...
else,out=mat2cell(value,ones(1,size(value,1)),size(value,2));end
out=cellfun(@(x)reshape(double(x),1,[]),out,"UniformOutput",false);
end
