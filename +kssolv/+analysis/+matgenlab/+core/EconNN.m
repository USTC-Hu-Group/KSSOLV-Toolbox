classdef EconNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=.2
        cutoff (1,1) double=10
        cation_anion (1,1) logical=false
        use_fictive_radius (1,1) logical=false
    end
    methods
        function obj=EconNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
            options=struct(tol=.2,cutoff=10,cation_anion=false, ...
                use_fictive_radius=false);options=parse(options,varargin);
            obj.tol=options.tol;obj.cutoff=options.cutoff;
            obj.cation_anion=options.cation_anion;
            obj.use_fictive_radius=options.use_fictive_radius;
        end
        function info=get_nn_info(obj,structure,n)
            center=structure(n);neighbors=structure.get_neighbors(center,obj.cutoff);
            if obj.cation_anion
                centerCharge=localCharge(center);
                keep=cellfun(@(item)localCharge(item)*centerCharge<=0,neighbors);
                neighbors=neighbors(keep);
            end
            radii=zeros(1,numel(neighbors));
            for ii=1:numel(neighbors)
                if obj.use_fictive_radius
                    centerRadius=localRadius(center);
                    neighborRadius=localRadius(neighbors{ii});
                    radii(ii)=neighbors{ii}.nn_distance* ...
                        centerRadius/(centerRadius+neighborRadius);
                else,radii(ii)=neighbors{ii}.nn_distance;end
            end
            info={};if isempty(radii),return,end
            meanRadius=weightedMean(radii,min(radii));previous=Inf;
            while abs(previous-meanRadius)>1e-4
                previous=meanRadius;meanRadius=weightedMean(radii,meanRadius);
            end
            for ii=1:numel(neighbors)
                weight=exp(1-(radii(ii)/meanRadius)^6);
                if weight>obj.tol
                    info{end+1}=obj.makeInfo(neighbors{ii},weight); %#ok<AGROW>
                end
            end
            function value=weightedMean(values,minimum)
                weights=exp(1-(values/minimum).^6);
                value=sum(values.*weights)/sum(weights);
            end
            function value=localCharge(site)
                value=0;
                try
                    value=site.specie.oxi_state;
                    if isnan(value),value=0;end
                catch
                end
            end
            function value=localRadius(site)
                value=NaN;
                specie=site.specie;
                element=specie;
                if isa(specie,"kssolv.analysis.matgenlab.core.Species")
                    value=specie.ionic_radius;
                    element=specie.element;
                end
                if isempty(value)||isnan(value),value=element.atomic_radius;end
                if isempty(value)||isnan(value)
                    value=element.atomic_radius_calculated;
                end
                if isempty(value)||isnan(value),value=.7;end
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
