classdef PDPlotter < handle
    %#ok<*PROP,*MSNU,*ALIGN>
    %PDPLOTTER MATLAB-native phase-diagram plotting and plot-data adapter.
    properties
        phasediagram
        show_unstable=0.2
        backend (1,1) string="plotly"
        ternary_style (1,1) string="2d"
        plotkwargs struct=struct()
        lines double=zeros(0,2)
    end
    properties (Dependent,SetAccess=private)
        pd_plot_data
    end
    methods
        function obj=PDPlotter(phasediagram,varargin)
            obj.phasediagram=phasediagram;
            options=struct(show_unstable=.2,backend="plotly", ...
                ternary_style="2d",plotkwargs=struct());
            options=parseOptions(options,varargin);
            obj.show_unstable=options.show_unstable;obj.backend=string(options.backend);
            obj.ternary_style=lower(string(options.ternary_style));
            obj.plotkwargs=options.plotkwargs;
            if phasediagram.dim>4
                error("KSSOLV:Matgenlab:PDPlotter:Dimension","Only 1-4 components supported.");
            end
            obj.lines=kssolv.analysis.matgenlab.analysis.uniquelines(phasediagram.facets);
        end
        function value=get.pd_plot_data(obj)
            [lines,stable,unstable]=obj.buildPlotData();
            value={lines,stable,unstable};
        end
        function [lines,stable,unstable]=get_pd_plot_data(obj)
            [lines,stable,unstable]=obj.buildPlotData();
        end
        function axesHandle=get_plot(obj,varargin)
            options=struct(label_stable=true,label_unstable=true,ordering=[], ...
                energy_colormap=[],process_attributes=false,ax=[], ...
                label_uncertainties=false,fill=true,highlight_entries={{}}); %#ok<NASGU>
            options=parseOptions(options,varargin);
            [lines,stable,unstable]=obj.buildPlotData();
            if ~isempty(options.ordering)&&obj.phasediagram.dim==3
                [lines,stable,unstable]=kssolv.analysis.matgenlab.analysis. ...
                    order_phase_diagram(lines,stable,unstable,options.ordering);
            end
            if isempty(options.ax)
                figureHandle=figure("Visible","off");
                if obj.phasediagram.dim==4,axesHandle=axes(figureHandle);view(axesHandle,3);
                else,axesHandle=axes(figureHandle);end
            else,axesHandle=options.ax;end
            hold(axesHandle,"on");
            for ii=1:numel(lines)
                coordinates=lines{ii};
                if size(coordinates,2)==3
                    plot3(axesHandle,coordinates(:,1),coordinates(:,2),coordinates(:,3),"k-");
                else
                    plot(axesHandle,coordinates(:,1),coordinates(:,2),"k-");
                end
            end
            for ii=1:size(stable,1)
                coordinate=stable{ii,1};
                if numel(coordinate)==3
                    scatter3(axesHandle,coordinate(1),coordinate(2),coordinate(3),45,"filled");
                else
                    scatter(axesHandle,coordinate(1),coordinate(2),45,"filled");
                end
                if options.label_stable,text(axesHandle,coordinate(1),coordinate(2), ...
                        " "+entryName(stable{ii,2}));end
            end
            if obj.show_unstable
                for ii=1:size(unstable,1)
                    if obj.phasediagram.get_e_above_hull(unstable{ii,1},"on_error","ignore")<=obj.show_unstable
                        coordinate=unstable{ii,2};
                        if numel(coordinate)==3,scatter3(axesHandle,coordinate(1),coordinate(2),coordinate(3),18,"x");
                        else,scatter(axesHandle,coordinate(1),coordinate(2),18,"x");end
                    end
                end
            end
            hold(axesHandle,"off");
        end
        function show(obj,varargin)
            axesHandle=obj.get_plot(varargin{:});
            axesHandle.Parent.Visible="on";
        end
        function write_image(obj,stream,imageFormat,varargin)
            if nargin<3||strlength(string(imageFormat))==0,imageFormat="svg";end
            axesHandle=obj.get_plot(varargin{:});
            exportgraphics(axesHandle,string(stream),ContentType= ...
                ternary(string(imageFormat)=="svg","vector","image"));
        end
        function axesHandle=plot_element_profile(obj,element,composition,varargin)
            options=struct(show_label_index=[],xlim=5);options=parseOptions(options,varargin);
            profile=obj.phasediagram.get_element_profile(element,composition);
            figureHandle=figure("Visible","off");axesHandle=axes(figureHandle);hold(axesHandle,"on");
            if isempty(profile),return,end
            reference=profile(1).chempot;
            for ii=1:numel(profile)
                x1=-(profile(ii).chempot-reference);
                if ii<numel(profile),x2=-(profile(ii+1).chempot-reference);else,x2=options.xlim;end
                plot(axesHandle,[x1,x2],[profile(ii).evolution,profile(ii).evolution],"k-");
            end
            xlim(axesHandle,[0,options.xlim]);xlabel(axesHandle,"-\Delta\mu (eV)");
            ylabel(axesHandle,"Uptake per formula");
        end
        function plot_chempot_range_map(obj,elements,referenced)
            if nargin<3,referenced=true;end
            axesHandle=obj.get_chempot_range_map_plot(elements,referenced);
            axesHandle.Parent.Visible="on";
        end
        function axesHandle=get_chempot_range_map_plot(obj,elements,referenced)
            if nargin<3,referenced=true;end
            ranges=obj.phasediagram.get_chempot_range_map(elements,referenced);
            figureHandle=figure("Visible","off");axesHandle=axes(figureHandle);hold(axesHandle,"on");
            for ii=1:size(ranges,1)
                coords=zeros(0,2);
                for simplex=ranges{ii,2}
                    line=simplex{1}.coords;plot(axesHandle,line(:,1),line(:,2),"k-");
                    coords=[coords;line]; %#ok<AGROW>
                end
                if ~isempty(coords),text(axesHandle,mean(coords(:,1)),mean(coords(:,2)),entryName(ranges{ii,1}));end
            end
            hold(axesHandle,"off");
        end
        function axesHandle=get_contour_pd_plot(obj)
            axesHandle=obj.get_plot();
        end
    end
    methods (Access=private)
        function [lines,stable,unstable]=buildPlotData(obj)
            pd=obj.phasediagram;dimension=pd.dim;lines=cell(1,size(obj.lines,1));
            stable=cell(0,2);
            for ii=1:size(obj.lines,1)
                indices=obj.lines(ii,:);entries=pd.qhull_entries(indices);
                if dimension<3
                    coordinates=[pd.qhull_data(indices,1), ...
                        cellfun(@(x)pd.get_form_energy_per_atom(x),entries).'];
                elseif dimension==3
                    coordinates=kssolv.analysis.matgenlab.analysis. ...
                        triangular_coord(pd.qhull_data(indices,1:2));
                else
                    coordinates=kssolv.analysis.matgenlab.analysis. ...
                        tet_coord(pd.qhull_data(indices,1:3));
                end
                lines{ii}=coordinates;
                for jj=1:2
                    row=find(cellfun(@(x)samePhaseEntry(x,entries{jj}),stable(:,2)),1);
                    if isempty(row),stable(end+1,:)={coordinates(jj,:),entries{jj}};end %#ok<AGROW>
                end
            end
            unstable=cell(0,2);allData=pd.all_entries_hulldata;
            for ii=1:numel(pd.all_entries)
                entry=pd.all_entries{ii};
                if any(cellfun(@(x)samePhaseEntry(x,entry),pd.stable_entries)),continue,end
                if dimension<3
                    coordinate=[allData(ii,1),pd.get_form_energy_per_atom(entry)];
                elseif dimension==3
                    coordinate=kssolv.analysis.matgenlab.analysis.triangular_coord(allData(ii,1:2));
                else
                    coordinate=kssolv.analysis.matgenlab.analysis.tet_coord(allData(ii,1:3));
                end
                unstable(end+1,:)={entry,coordinate}; %#ok<AGROW>
            end
        end
    end
end

function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&&any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        if position>numel(names),break,end
        output.(names{position})=input{ii};position=position+1;ii=ii+1;
    end
end
end
function value=entryName(entry)
if isprop(entry,"name"),value=string(entry.name);else,value=entry.reduced_formula;end
end
function tf=samePhaseEntry(first,second)
tf=first.composition==second.composition&&abs(first.energy-second.energy)<=1e-12;
end
function value=ternary(condition,a,b)
if condition,value=a;else,value=b;end
end
