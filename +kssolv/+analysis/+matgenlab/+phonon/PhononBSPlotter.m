classdef PhononBSPlotter < handle
    %PHONONBSPLOTTER Plot and export symmetry-line phonon band structures.

    properties (Access=protected)
        bs_
        label_
    end

    properties (Dependent,SetAccess=private)
        n_bands
    end

    methods
        function obj=PhononBSPlotter(bs,label)
            if nargin<2,label=[];end
            if ~isa(bs,"kssolv.analysis.matgenlab.phonon." + ...
                    "PhononBandStructureSymmLine") && ...
                    ~isa(bs,"kssolv.analysis.matgenlab.phonon." + ...
                    "GruneisenPhononBandStructureSymmLine")
                error("KSSOLV:Matgenlab:PhononBSPlotter:Type", ...
                    "PhononBSPlotter requires a symmetry-line band structure.");
            end
            obj.bs_=bs;
            obj.label_=label;
        end

        function value=get.n_bands(obj),value=obj.bs_.nb_bands;end

        function value=bs_plot_data(obj)
            distances=cell(1,numel(obj.bs_.branches));
            frequency=cell(size(distances));
            for index=1:numel(obj.bs_.branches)
                branch=obj.bs_.branches{index};
                indices=branch.start_index:branch.end_index;
                distances{index}=obj.bs_.distance(indices);
                frequency{index}=obj.bs_.bands(:,indices);
            end
            value=struct( ...
                "ticks",obj.get_ticks(), ...
                "distances",{distances}, ...
                "frequency",{frequency}, ...
                "lattice",obj.bs_.lattice_rec.as_dict());
        end

        function ax=get_plot(obj,ylimValue,units,varargin)
            if nargin<2,ylimValue=[];end
            if nargin<3||isempty(units),units="thz";end
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            data=obj.bs_plot_data();
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            for branchIndex=1:numel(data.distances)
                distances=data.distances{branchIndex};
                frequencies=data.frequency{branchIndex};
                for bandIndex=1:obj.n_bands
                    plot(ax,distances, ...
                        frequencies(bandIndex,:)*unit.factor, ...
                        varargin{:});
                end
            end
            obj.makeTicks(ax);
            yline(ax,0,"k");
            xlabel(ax,"Wave Vector");
            ylabel(ax,"Frequencies ("+unit.label+")");
            if ~isempty(data.distances)
                xlim(ax,[0,data.distances{end}(end)]);
            end
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            hold(ax,"off");
        end

        function ax=get_proj_plot(obj,siteComb,ylimValue,units,~)
            if nargin<2||isempty(siteComb),siteComb="element";end
            if nargin<3,ylimValue=[];end
            if nargin<4||isempty(units),units="thz";end
            if isempty(obj.bs_.structure)|| ...
                    ~obj.bs_.has_eigendisplacements
                error("KSSOLV:Matgenlab:PhononBSPlotter:Projection", ...
                    "Projected plots require a structure and eigendisplacements.");
            end
            groups=projectionGroups(obj.bs_.structure,siteComb);
            if numel(groups)>4
                error("KSSOLV:Matgenlab:PhononBSPlotter:Projection", ...
                    "Only up to four projection groups are supported.");
            end
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            palette=[1,0,0;0,1,0;0,0,1;0.5,0.5,0.5];
            for bandIndex=1:obj.n_bands
                for pointIndex=1:obj.bs_.nb_qpoints
                    eigen=reshape(obj.bs_.eigendisplacements( ...
                        bandIndex,pointIndex,:,:),[],3);
                    atomWeights=sqrt(sum(abs(eigen).^2,2));
                    weights=zeros(1,numel(groups));
                    for groupIndex=1:numel(groups)
                        weights(groupIndex)=sum(atomWeights(groups{groupIndex}));
                    end
                    if sum(weights)>0,weights=weights/sum(weights);end
                    color=weights*palette(1:numel(groups),:);
                    scatter(ax,obj.bs_.distance(pointIndex), ...
                        obj.bs_.bands(bandIndex,pointIndex)*unit.factor, ...
                        12,color,"filled");
                end
            end
            obj.makeTicks(ax);
            xlabel(ax,"Wave Vector");
            ylabel(ax,"Frequencies ("+unit.label+")");
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            hold(ax,"off");
        end

        function show(obj,varargin)
            ax=obj.get_plot(varargin{:});ax.Parent.Visible="on";
        end

        function save_plot(obj,filename,ylimValue,units)
            if nargin<3,ylimValue=[];end
            if nargin<4,units="thz";end
            ax=obj.get_plot(ylimValue,units);
            exportgraphics(ax.Parent,filename);
            close(ax.Parent);
        end

        function show_proj(obj,varargin)
            ax=obj.get_proj_plot(varargin{:});ax.Parent.Visible="on";
        end

        function value=get_ticks(obj)
            distances=zeros(1,0);labels=strings(1,0);
            previousLabel=obj.bs_.qpoints{1}.label;
            previousBranch=obj.bs_.branches{1}.name;
            for index=1:obj.bs_.nb_qpoints
                point=obj.bs_.qpoints{index};
                if isempty(point.label),continue,end
                distances(end+1)=obj.bs_.distance(index); %#ok<AGROW>
                thisBranch=[];
                for branchIndex=1:numel(obj.bs_.branches)
                    branch=obj.bs_.branches{branchIndex};
                    if index>=branch.start_index && index<=branch.end_index
                        thisBranch=branch.name;break
                    end
                end
                label=prettyLabel(point.label);
                if ~isequal(point.label,previousLabel) && ...
                        ~isequal(previousBranch,thisBranch)
                    previous=prettyLabel(previousLabel);
                    labels(end)=previous+"|"+label;
                    distances(end)=[];
                else
                    labels(end+1)=label; %#ok<AGROW>
                end
                previousLabel=point.label;
                previousBranch=thisBranch;
            end
            value=struct("distance",distances,"label",labels);
        end

        function ax=plot_compare(obj,otherPlotter,units,selfLabel, ...
                colors,~,onIncompatible,~,varargin)
            if nargin<3||isempty(units),units="thz";end
            if nargin<4||isempty(selfLabel),selfLabel="self";end
            if nargin<5,colors=[];end
            if nargin<7||isempty(onIncompatible),onIncompatible="raise";end
            if isa(otherPlotter,"kssolv.analysis.matgenlab.phonon.PhononBSPlotter")
                others={otherPlotter};labels="other";
            elseif isa(otherPlotter,"containers.Map")
                labels=string(otherPlotter.keys);others=values(otherPlotter);
            else
                error("KSSOLV:Matgenlab:PhononBSPlotter:Compare", ...
                    "other_plotter must be a plotter or map.");
            end
            base=obj.bs_plot_data();
            ax=obj.get_plot([],units,varargin{:});
            hold(ax,"on");
            palette=["red","green","orange","purple","brown"];
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            for otherIndex=1:numel(others)
                data=others{otherIndex}.bs_plot_data();
                if ~compatibleBranches(base.distances,data.distances)
                    if lower(string(onIncompatible))=="raise"
                        error("KSSOLV:Matgenlab:PhononBSPlotter:Incompatible", ...
                            "The two band structures are not compatible.");
                    elseif lower(string(onIncompatible))=="warn"
                        warning("KSSOLV:Matgenlab:PhononBSPlotter:Incompatible", ...
                            "The two band structures are not compatible.");
                    end
                    ax=[];return
                end
                color=palette(mod(otherIndex-1,numel(palette))+1);
                if ~isempty(colors),color=string(colors(otherIndex+1));end
                for branchIndex=1:numel(base.distances)
                    for bandIndex=1:others{otherIndex}.n_bands
                        plot(ax,base.distances{branchIndex}, ...
                            data.frequency{branchIndex}(bandIndex,:)* ...
                            unit.factor,"Color",color);
                    end
                end
                plot(ax,nan,nan,"Color",color, ...
                    "DisplayName",labels(otherIndex));
            end
            ownLabel=string(selfLabel);
            if ~isempty(obj.label_),ownLabel=string(obj.label_);end
            plot(ax,nan,nan,"Color","blue","DisplayName",ownLabel);
            legend(ax,"show");
            hold(ax,"off");
        end

        function ax=plot_brillouin(obj)
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            for index=1:numel(obj.bs_.branches)
                branch=obj.bs_.branches{index};
                first=obj.bs_.qpoints{branch.start_index}.frac_coords;
                last=obj.bs_.qpoints{branch.end_index}.frac_coords;
                plot3(ax,[first(1),last(1)],[first(2),last(2)], ...
                    [first(3),last(3)],"-o");
            end
            axis(ax,"equal");grid(ax,"on");hold(ax,"off");
        end
    end

    methods (Access=protected)
        function makeTicks(obj,ax)
            ticks=obj.get_ticks();
            if isempty(ticks.distance),return,end
            xticks(ax,unique(ticks.distance,"stable"));
            [~,indices]=unique(ticks.distance,"stable");
            xticklabels(ax,ticks.label(indices));
            for value=ticks.distance,xline(ax,value,"k");end
        end
    end
end

function value=prettyLabel(label)
value=string(label);
value=replace(value,["GAMMA","DELTA","SIGMA"],["Γ","Δ","Σ"]);
end

function groups=projectionGroups(structure,siteComb)
if ischar(siteComb)||isstring(siteComb)
    if lower(string(siteComb))~="element"
        error("KSSOLV:Matgenlab:PhononBSPlotter:Projection", ...
            "site_comb string must be 'element'.");
    end
    names=strings(1,structure.num_sites);
    for index=1:numel(names)
        names(index)=structure(index).specie.symbol;
    end
    elements=unique(names,"stable");
    groups=arrayfun(@(name)find(names==name),elements, ...
        UniformOutput=false);
elseif iscell(siteComb)
    groups=siteComb;
    for index=1:numel(groups)
        values=reshape(double(groups{index}),1,[]);
        if any(values==0),values=values+1;end
        groups{index}=values;
    end
else
    error("KSSOLV:Matgenlab:PhononBSPlotter:Projection", ...
        "site_comb must be 'element' or a cell array.");
end
end

function value=compatibleBranches(first,second)
value=numel(first)==numel(second);
if ~value,return,end
for index=1:numel(first)
    if numel(first{index})~=numel(second{index}),value=false;return,end
end
end
