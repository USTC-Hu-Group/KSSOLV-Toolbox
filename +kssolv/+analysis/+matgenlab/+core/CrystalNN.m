classdef CrystalNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    %CRYSTALNN Voronoi/chemistry/distance weighted coordination strategy.
    properties
        weighted_cn (1,1) logical=false
        cation_anion (1,1) logical=false
        distance_cutoffs={.5,1}
        x_diff_weight (1,1) double=3
        porous_adjustment (1,1) logical=true
        search_cutoff (1,1) double=7
        fingerprint_length=[]
    end
    methods
        function obj=CrystalNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=false;
            options=struct(weighted_cn=false,cation_anion=false, ...
                distance_cutoffs={{.5,1}},x_diff_weight=3, ...
                porous_adjustment=true,search_cutoff=7,fingerprint_length=[]);
            options=parseOptions(options,varargin);names=fieldnames(options);
            for ii=1:numel(names),obj.(names{ii})=options.(names{ii});end
            if isnumeric(obj.distance_cutoffs)
                obj.distance_cutoffs=num2cell(obj.distance_cutoffs);
            end
        end
        function info=get_nn_info(obj,structure,n)
            data=obj.get_nn_data(structure,n);
            if ~obj.weighted_cn
                keys_=cell2mat(keys(data.cn_weights));
                values_=cell2mat(values(data.cn_weights));
                [~,which]=max(values_);info=data.cn_nninfo(keys_(which));
                for ii=1:numel(info),info{ii}.weight=1;end
                return
            end
            info=data.all_nninfo;
            for ii=1:numel(info)
                weight=0;cnKeys=keys(data.cn_nninfo);
                for jj=1:numel(cnKeys)
                    candidates=data.cn_nninfo(cnKeys{jj});
                    if any(cellfun(@(item)item.site_index==info{ii}.site_index&& ...
                            isequal(item.image,info{ii}.image),candidates))
                        weight=weight+data.cn_weights(cnKeys{jj});
                    end
                end
                info{ii}.weight=weight;
            end
        end
        function data=get_nn_data(obj,structure,n,length_)
            if nargin<4||isempty(length_),length_=obj.fingerprint_length;end
            targets=[];
            if obj.cation_anion
                centerCharge=structure(n).specie.oxi_state;targets={};
                for ii=1:structure.num_sites
                    charge=structure(ii).specie.oxi_state;
                    if isfinite(charge)&&charge*centerCharge<=0
                        targets{end+1}=structure(ii).specie; %#ok<AGROW>
                    end
                end
                if isempty(targets),error("KSSOLV:Matgenlab:CrystalNN:Targets", ...
                        "No valid targets within cation_anion constraint.");end
            end
            voronoi=kssolv.analysis.matgenlab.core.VoronoiNN( ...
                "weight","solid_angle","targets",targets, ...
                "cutoff",obj.search_cutoff);
            neighbors=voronoi.get_nn_info(structure,n);
            for ii=1:numel(neighbors)
                if obj.porous_adjustment
                    polygon=neighbors{ii}.poly_info;
                    neighbors{ii}.weight=neighbors{ii}.weight* ...
                        polygon.solid_angle/polygon.area;
                end
                if obj.x_diff_weight>0
                    first=structure(n).specie.X;second=neighbors{ii}.site.specie.X;
                    chemical=1;
                    if isfinite(first)&&isfinite(second)
                        chemical=1+obj.x_diff_weight*sqrt(abs(first-second)/3.3);
                    end
                    neighbors{ii}.weight=neighbors{ii}.weight*chemical;
                end
            end
            neighbors=sortInfo(neighbors);
            if isempty(neighbors)||neighbors{1}.weight==0
                data=emptyData();data=obj.transform_to_length(data,length_);return
            end
            maximum=neighbors{1}.weight;
            for ii=1:numel(neighbors),neighbors{ii}.weight=neighbors{ii}.weight/maximum;end
            if ~isempty(obj.distance_cutoffs)
                firstRadius=siteRadius(structure(n));
                for ii=1:numel(neighbors)
                    diameter=firstRadius+siteRadius(neighbors{ii}.site);
                    distance=norm(structure(n).coords-neighbors{ii}.site.coords);
                    low=diameter+obj.distance_cutoffs{1};
                    high=diameter+obj.distance_cutoffs{2};factor=0;
                    if distance<=low,factor=1;
                    elseif distance<high
                        factor=(cos((distance-low)/(high-low)*pi)+1)/2;
                    end
                    neighbors{ii}.weight=neighbors{ii}.weight*factor;
                end
            end
            neighbors=sortInfo(neighbors);
            if isempty(neighbors)||neighbors{1}.weight==0
                data=emptyData();data=obj.transform_to_length(data,length_);return
            end
            keep=true(size(neighbors));
            for ii=1:numel(neighbors)
                neighbors{ii}.weight=round(neighbors{ii}.weight,3);
                if isfield(neighbors{ii},"poly_info"),neighbors{ii}=rmfield(neighbors{ii},"poly_info");end
                keep(ii)=neighbors{ii}.weight>0;
            end
            neighbors=neighbors(keep);
            bins=unique(cellfun(@(item)item.weight,neighbors),"stable");bins=[bins,0];
            cnWeights=containers.Map("KeyType","double","ValueType","double");
            cnInfo=containers.Map("KeyType","double","ValueType","any");
            for ii=1:numel(bins)-1
                selected=neighbors(cellfun(@(item)item.weight>=bins(ii),neighbors));
                cn=numel(selected);cnInfo(cn)=selected;
                cnWeights(cn)=semicircle(bins(ii),bins(ii+1));
            end
            zeroWeight=1-sum(cell2mat(values(cnWeights)));
            if zeroWeight>0,cnWeights(0)=zeroWeight;cnInfo(0)={};end
            data=struct(all_nninfo={neighbors},cn_weights=cnWeights,cn_nninfo=cnInfo);
            data=obj.transform_to_length(data,length_);
            function output=sortInfo(input)
                if isempty(input),output=input;return,end
                [~,order]=sort(cellfun(@(item)item.weight,input),"descend");
                output=input(order);
            end
            function value=siteRadius(site)
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
            function value=semicircle(x1,x2)
                if x1==1,area1=pi/4;
                else,area1=.5*(x1*sqrt(1-x1^2)+atan(x1/sqrt(1-x1^2)));end
                area2=.5*(x2*sqrt(1-x2^2)+atan2(x2,sqrt(1-x2^2)));
                value=(area1-area2)/(pi/4);
            end
            function value=emptyData()
                cw=containers.Map("KeyType","double","ValueType","double");cw(0)=1;
                ci=containers.Map("KeyType","double","ValueType","any");ci(0)={};
                value=struct(all_nninfo={{}},cn_weights=cw,cn_nninfo=ci);
            end
        end
        function value=get_cn(obj,structure,n,varargin)
            options=struct(use_weights=false,on_disorder="take_majority_strict");
            options=parseOptions(options,varargin);
            if obj.weighted_cn~=options.use_weights
                error("KSSOLV:Matgenlab:CrystalNN:WeightMode", ...
                    "weighted_cn and use_weights must match.");
            end
            value=get_cn@kssolv.analysis.matgenlab.core.NearNeighbors( ...
                obj,structure,n,"use_weights",options.use_weights, ...
                "on_disorder",options.on_disorder);
        end
        function value=get_cn_dict(obj,structure,n,varargin)
            options=struct(use_weights=false);options=parseOptions(options,varargin);
            if obj.weighted_cn~=options.use_weights
                error("KSSOLV:Matgenlab:CrystalNN:WeightMode", ...
                    "weighted_cn and use_weights must match.");
            end
            value=get_cn_dict@kssolv.analysis.matgenlab.core.NearNeighbors( ...
                obj,structure,n,"use_weights",options.use_weights);
        end
    end
    methods (Static)
        function data=transform_to_length(data,length_)
            if isempty(length_),return,end
            for cn=0:length_-1
                if ~isKey(data.cn_weights,cn)
                    data.cn_weights(cn)=0;data.cn_nninfo(cn)={};
                end
            end
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
