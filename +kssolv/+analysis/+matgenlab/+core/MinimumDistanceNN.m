classdef MinimumDistanceNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=.1
        cutoff (1,1) double=10
        get_all_sites (1,1) logical=false
    end
    methods
        function obj=MinimumDistanceNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
            options=struct(tol=.1,cutoff=10,get_all_sites=false);
            options=parse(options,varargin);
            obj.tol=options.tol;obj.cutoff=options.cutoff;
            obj.get_all_sites=options.get_all_sites;
        end
        function info=get_nn_info(obj,structure,n)
            neighbors=structure.get_neighbors(structure(n),obj.cutoff);info={};
            if isempty(neighbors),return,end
            minimum=min(cellfun(@(item)item.nn_distance,neighbors));
            for ii=1:numel(neighbors)
                distance=neighbors{ii}.nn_distance;
                if obj.get_all_sites||distance<(1+obj.tol)*minimum
                    weight=distance;if ~obj.get_all_sites,weight=minimum/distance;end
                    info{end+1}=obj.makeInfo(neighbors{ii},weight); %#ok<AGROW>
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
