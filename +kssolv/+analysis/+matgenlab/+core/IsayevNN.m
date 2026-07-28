classdef IsayevNN < kssolv.analysis.matgenlab.core.VoronoiNN
    %#ok<*ALIGN>
    methods
        function obj=IsayevNN(varargin)
            options=struct(tol=.25,targets=[],cutoff=13, ...
                allow_pathological=false,extra_nn_info=true, ...
                compute_adj_neighbors=true);
            options=parseOptions(options,varargin);
            obj@kssolv.analysis.matgenlab.core.VoronoiNN( ...
                "tol",0,"targets",options.targets,"cutoff",options.cutoff, ...
                "allow_pathological",options.allow_pathological, ...
                "extra_nn_info",options.extra_nn_info, ...
                "compute_adj_neighbors",options.compute_adj_neighbors);
            obj.tol=options.tol;
        end
        function info=get_nn_info(obj,structure,n)
            poly=obj.get_voronoi_polyhedra(structure,n);
            areas=cellfun(@(item)item.area,poly);maximum=max(areas);info={};
            center=structure(n);
            for ii=1:numel(poly)
                neighbor=poly{ii}.site;
                cutoff=defaultRadius(center)+defaultRadius(neighbor)+obj.tol;
                if norm(center.coords-neighbor.coords)<=cutoff
                    entry=obj.makeInfo(neighbor,poly{ii}.area/maximum);
                    if obj.extra_nn_info
                        entry.poly_info=rmfield(poly{ii},"site");
                    end
                    info{end+1}=entry; %#ok<AGROW>
                end
            end
            function value=defaultRadius(site)
                radii=kssolv.analysis.matgenlab.core.CovalentRadius.radius();
                key=matlab.lang.makeValidName(char(site.specie.symbol));
                if isfield(radii,key),value=radii.(key);
                else
                    value=site.specie.atomic_radius;
                    if isempty(value)||isnan(value)
                        value=site.specie.atomic_radius_calculated;
                    end
                end
                if isempty(value)||isnan(value),value=.7;end
            end
        end
        function value=get_all_nn_info(obj,structure)
            value=cell(1,structure.num_sites);
            for ii=1:structure.num_sites,value{ii}=obj.get_nn_info(structure,ii);end
        end
    end
end

function output=parseOptions(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
