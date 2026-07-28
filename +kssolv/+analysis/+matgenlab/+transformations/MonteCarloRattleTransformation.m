classdef MonteCarloRattleTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    %MONTECARLORATTLETRANSFORMATION Periodic hard-sphere Monte Carlo rattle.
    properties (SetAccess=private)
        rattle_std (1,1) double
        min_distance (1,1) double
        seed (1,1) double
        kwargs
    end
    properties (Hidden,Access=private)
        state
    end
    methods
        function obj=MonteCarloRattleTransformation(rattleStd,minDistance, ...
                seed,varargin)
            if nargin<3||isempty(seed),seed=randi(1e9-1);end
            obj.rattle_std=rattleStd;obj.min_distance=minDistance;
            obj.seed=double(seed);
            if nargin>=4&&isscalar(varargin)&&isstruct(varargin{1})
                obj.kwargs=varargin{1};
            else
                obj.kwargs=struct();
                for index=1:2:numel(varargin)
                    obj.kwargs.(char(string(varargin{index})))=varargin{index+1};
                end
            end
            obj.state=kssolv.analysis.matgenlab.transformations.internal.State();
            obj.state.data=RandStream("mt19937ar","Seed",obj.seed);
        end
        function result=apply_transformation(obj,structure)
            stream=obj.state.data;
            attempts=10;
            if isfield(obj.kwargs,"n_iter"),attempts=obj.kwargs.n_iter;end
            fractional=structure.frac_coords;
            matrix=structure.lattice.matrix;
            for sweep=1:attempts
                for site=1:structure.num_sites
                    old=fractional(site,:);
                    displacement=randn(stream,1,3)*obj.rattle_std;
                    proposal=old+displacement/matrix;
                    fractional(site,:)=proposal;
                    minimum=Inf;
                    for other=1:structure.num_sites
                        if other==site,continue,end
                        delta=proposal-fractional(other,:);
                        delta=delta-round(delta);
                        minimum=min(minimum,norm(delta*matrix));
                    end
                    if minimum<obj.min_distance
                        probability=exp((minimum-obj.min_distance)/ ...
                            max(obj.rattle_std,.01));
                        if rand(stream)>probability
                            fractional(site,:)=old;
                        end
                    end
                end
            end
            result=kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice,structure.species_and_occu, ...
                fractional);
        end
        function value=char(obj)
            value=sprintf("%s : rattle_std = %g", ...
                class(obj),obj.rattle_std);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                MonteCarloRattleTransformation(value.rattle_std, ...
                value.min_distance,value.seed,value.kwargs);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                MonteCarloRattleTransformation.from_dict(value);end
    end
end
