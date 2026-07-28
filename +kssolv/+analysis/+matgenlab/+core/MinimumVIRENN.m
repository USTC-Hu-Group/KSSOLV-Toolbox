classdef MinimumVIRENN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=.1
        cutoff (1,1) double=10
    end
    methods
        function obj=MinimumVIRENN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=false;
            options=struct(tol=.1,cutoff=10);options=parse(options,varargin);
            obj.tol=options.tol;obj.cutoff=options.cutoff;
        end
        function info=get_nn_info(obj,structure,n)
            evaluator=kssolv.analysis.matgenlab.core. ...
                ValenceIonicRadiusEvaluator(structure);
            decorated=evaluator.structure;
            neighbors=decorated.get_neighbors(decorated(n),obj.cutoff);
            relative=zeros(1,numel(neighbors));centerRadius=evaluator.radius_for_site(n);
            for ii=1:numel(neighbors)
                neighborRadius=evaluator.radius_for_site(neighbors{ii}.index);
                relative(ii)=neighbors{ii}.nn_distance/(centerRadius+neighborRadius);
            end
            info={};if isempty(relative),return,end
            minimum=min(relative);
            for ii=1:numel(neighbors)
                if relative(ii)<(1+obj.tol)*minimum
                    info{end+1}=obj.makeInfo(neighbors{ii},minimum/relative(ii)); %#ok<AGROW>
                end
            end
        end
    end
end
function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
