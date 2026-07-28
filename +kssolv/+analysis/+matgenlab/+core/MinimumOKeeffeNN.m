classdef MinimumOKeeffeNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=.1
        cutoff (1,1) double=10
    end
    methods
        function obj=MinimumOKeeffeNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
            options=struct(tol=.1,cutoff=10);options=parse(options,varargin);
            obj.tol=options.tol;obj.cutoff=options.cutoff;
        end
        function info=get_nn_info(obj,structure,n)
            center=structure(n);neighbors=structure.get_neighbors(center,obj.cutoff);
            relative=zeros(1,numel(neighbors));
            first=center.specie.symbol;
            for ii=1:numel(neighbors)
                prediction=kssolv.analysis.matgenlab.core. ...
                    get_okeeffe_distance_prediction(first,neighbors{ii}.specie.symbol);
                relative(ii)=neighbors{ii}.nn_distance/prediction;
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
