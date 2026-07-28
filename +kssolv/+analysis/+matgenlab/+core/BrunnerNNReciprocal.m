classdef BrunnerNNReciprocal < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=1e-4
        cutoff (1,1) double=8
    end
    methods
        function obj=BrunnerNNReciprocal(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=false;
            options=struct(tol=1e-4,cutoff=8);options=parse(options,varargin);
            obj.tol=options.tol;obj.cutoff=options.cutoff;
        end
        function info=get_nn_info(obj,structure,n)
            neighbors=structure.get_neighbors(structure(n),obj.cutoff);
            distances=sort(cellfun(@(item)item.nn_distance,neighbors));
            if numel(distances)<2,info=cellfun(@(item)obj.makeInfo(item,1), ...
                    neighbors,"UniformOutput",false);return,end
            gaps=1./distances(1:end-1)-1./distances(2:end);
            [~,which]=max(gaps);limit=distances(which);info={};
            for ii=1:numel(neighbors)
                if neighbors{ii}.nn_distance<limit+obj.tol
                    info{end+1}=obj.makeInfo(neighbors{ii}, ...
                        distances(1)/neighbors{ii}.nn_distance); %#ok<AGROW>
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
