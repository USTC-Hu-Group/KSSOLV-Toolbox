classdef GruneisenPhononBSPlotter < ...
        kssolv.analysis.matgenlab.phonon.PhononBSPlotter
    %GRUNEISENPHONONBSPLOTTER Plot symmetry-line Gruneisen parameters.

    methods
        function obj=GruneisenPhononBSPlotter(bs)
            if ~isa(bs,"kssolv.analysis.matgenlab.phonon." + ...
                    "GruneisenPhononBandStructureSymmLine")
                error("KSSOLV:Matgenlab:GruneisenPhononBSPlotter:Type", ...
                    "A Gruneisen symmetry-line band structure is required.");
            end
            obj@kssolv.analysis.matgenlab.phonon.PhononBSPlotter(bs);
        end

        function value=bs_plot_data(obj)
            distances=cell(1,numel(obj.bs_.branches));
            frequency=cell(size(distances));
            gruneisen=cell(size(distances));
            for index=1:numel(obj.bs_.branches)
                branch=obj.bs_.branches{index};
                indices=branch.start_index:branch.end_index;
                distances{index}=obj.bs_.distance(indices);
                frequency{index}=obj.bs_.bands(:,indices);
                gruneisen{index}=obj.bs_.gruneisen(:,indices);
            end
            value=struct( ...
                "ticks",obj.get_ticks(), ...
                "distances",{distances}, ...
                "frequency",{frequency}, ...
                "gruneisen",{gruneisen}, ...
                "lattice",obj.bs_.lattice_rec.as_dict());
        end

        function ax=get_plot_gs(obj,ylimValue,plotPhononWithGruneisen,varargin)
            if nargin<2,ylimValue=[];end
            if nargin<3||isempty(plotPhononWithGruneisen)
                plotPhononWithGruneisen=false;
            end
            options=plotOptions(varargin{:});
            units=option(options,"units","thz");
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            data=obj.bs_plot_data();
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            allGamma=cell2mat(cellfun(@(v)v(:), ...
                data.gruneisen,UniformOutput=false));
            limit=max(abs(allGamma));
            if limit==0,limit=1;end
            for branchIndex=1:numel(data.distances)
                distance=data.distances{branchIndex};
                for bandIndex=1:obj.n_bands
                    gamma=data.gruneisen{branchIndex}(bandIndex,:);
                    if plotPhononWithGruneisen
                        color=(gamma/limit+1)/2;
                        scatter(ax,distance, ...
                            data.frequency{branchIndex}(bandIndex,:)* ...
                            unit.factor,10,color,"filled");
                    else
                        plot(ax,distance,gamma,"b-o", ...
                            "MarkerSize",2,"LineWidth",2);
                    end
                end
            end
            obj.makeTicks(ax);yline(ax,0,"k");
            xlabel(ax,"Wave Vector");
            if plotPhononWithGruneisen
                ylabel(ax,"Frequencies ("+unit.label+")");
                colorbar(ax);
            else
                ylabel(ax,"Grüneisen Parameter");
            end
            if ~isempty(data.distances)
                xlim(ax,[0,data.distances{end}(end)]);
            end
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            hold(ax,"off");
        end

        function show_gs(obj,varargin)
            ax=obj.get_plot_gs(varargin{:});ax.Parent.Visible="on";
        end

        function save_plot_gs(obj,filename,imgFormat, ...
                ylimValue,plotPhononWithGruneisen,varargin)
            if nargin<3||isempty(imgFormat),imgFormat="eps";end
            if nargin<4,ylimValue=[];end
            if nargin<5,plotPhononWithGruneisen=false;end
            ax=obj.get_plot_gs(ylimValue, ...
                plotPhononWithGruneisen,varargin{:});
            exportgraphics(ax.Parent,filename, ...
                ContentType=imageContentType(imgFormat));
            close(ax.Parent);
        end

        function ax=plot_compare_gs(obj,otherPlotter)
            first=obj.bs_plot_data();second=otherPlotter.bs_plot_data();
            if numel(first.distances)~=numel(second.distances)
                error("KSSOLV:Matgenlab:GruneisenPhononBSPlotter:Compare", ...
                    "The two plotters are incompatible.");
            end
            ax=obj.get_plot_gs();hold(ax,"on");
            for branchIndex=1:numel(first.distances)
                if numel(first.distances{branchIndex})~= ...
                        numel(second.distances{branchIndex})
                    error("KSSOLV:Matgenlab:GruneisenPhononBSPlotter:Compare", ...
                        "The two plotters are incompatible.");
                end
                for bandIndex=1:otherPlotter.n_bands
                    plot(ax,first.distances{branchIndex}, ...
                        second.gruneisen{branchIndex}(bandIndex,:),"r-");
                end
            end
            hold(ax,"off");
        end
    end
end

function options=plotOptions(varargin)
if isempty(varargin),options=struct();return,end
if isscalar(varargin)&&isstruct(varargin{1}),options=varargin{1};return,end
options=struct();
for index=1:2:numel(varargin)
    options.(char(string(varargin{index})))=varargin{index+1};
end
end
function value=option(options,name,default)
if isfield(options,name),value=options.(name);else,value=default;end
end
function value=imageContentType(format)
if any(lower(string(format))==["pdf","eps","svg"])
    value="vector";
else
    value="image";
end
end
