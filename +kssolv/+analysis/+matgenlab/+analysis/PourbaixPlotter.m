classdef PourbaixPlotter
    %POURBAIXPLOTTER MATLAB graphics for Pourbaix domains and stability.
    %#ok<*ALIGN>
    properties (SetAccess=private)
        pourbaix_diagram
    end
    methods
        function obj=PourbaixPlotter(diagram),obj.pourbaix_diagram=diagram;end
        function show(obj,varargin)
            axesHandle=obj.get_pourbaix_plot(varargin{:});
            figure(ancestor(axesHandle,"figure"));
        end
        function axesHandle=get_pourbaix_plot(obj,varargin)
            defaults=struct(limits=[-2,16;-3,3],title="", ...
                label_domains=true,label_fontsize=20, ...
                show_water_lines=true,show_neutral_axes=true,ax=[]);
            options=parsePlotOptions(defaults,varargin);
            if isempty(options.ax)
                figureHandle=figure("Visible","off");
                axesHandle=axes(figureHandle);
            else,axesHandle=options.ax;end
            hold(axesHandle,"on");xlim_=options.limits(1,:);
            ylim_=options.limits(2,:);lineWidth=3;
            if options.show_water_lines
                plot(axesHandle,xlim_,-.0591*xlim_,"r--", ...
                    "LineWidth",lineWidth);
                plot(axesHandle,xlim_,-.0591*xlim_+1.23,"r--", ...
                    "LineWidth",lineWidth);
            end
            if options.show_neutral_axes
                plot(axesHandle,[7,7],ylim_,"k-.","LineWidth",lineWidth);
                plot(axesHandle,xlim_,[0,0],"k-.","LineWidth",lineWidth);
            end
            vertices=obj.pourbaix_diagram.x_stable_domain_vertices;
            for index=1:size(vertices,1)
                points=vertices{index,2};closed=[points;points(1,:)];
                plot(axesHandle,closed(:,1),closed(:,2),"k-", ...
                    "LineWidth",lineWidth);
                if options.label_domains
                    center=mean(points,1);
                    text(axesHandle,center(1),center(2), ...
                        entryLabel(vertices{index,1}), ...
                        "HorizontalAlignment","center", ...
                        "VerticalAlignment","middle", ...
                        "FontSize",options.label_fontsize,"Color","b");
                end
            end
            title(axesHandle,options.title,"FontSize",20,"FontWeight","bold");
            xlabel(axesHandle,"pH");ylabel(axesHandle,"E (V)");
            xlim(axesHandle,xlim_);ylim(axesHandle,ylim_);
        end
        function axesHandle=plot_entry_stability(obj,entry,varargin)
            defaults=struct(pH_range=[-2,16],pH_resolution=100, ...
                V_range=[-3,3],V_resolution=100,e_hull_max=1, ...
                cmap="turbo",ax=[],limits=[]);
            options=parsePlotOptions(defaults,varargin);
            plotArgs={};
            if ~isempty(options.limits),plotArgs={"limits",options.limits};end
            if ~isempty(options.ax),plotArgs=[plotArgs,{"ax",options.ax}];end
            axesHandle=obj.get_pourbaix_plot(plotArgs{:});
            pH=linspace(options.pH_range(1),options.pH_range(2), ...
                options.pH_resolution);
            voltage=linspace(options.V_range(1),options.V_range(2), ...
                options.V_resolution);
            [pHGrid,voltageGrid]=meshgrid(pH,voltage);
            stability=obj.pourbaix_diagram.get_decomposition_energy( ...
                entry,pHGrid,voltageGrid);
            surface(axesHandle,pHGrid,voltageGrid,zeros(size(stability)), ...
                stability,"EdgeColor","none","FaceColor","flat");
            view(axesHandle,2);colormap(axesHandle,options.cmap);
            clim(axesHandle,[0,options.e_hull_max]);
            colorbar(axesHandle);
        end
        function value=domain_vertices(obj,entry)
            rows=obj.pourbaix_diagram.x_stable_domain_vertices;
            index=find(cellfun(@(x)x==entry,rows(:,1)),1);
            if isempty(index)
                error("KSSOLV:Matgenlab:Pourbaix:Domain", ...
                    "The requested entry has no stable domain.");
            end
            value=rows{index,2};
        end
    end
end
function value=entryLabel(entry)
if isa(entry,"kssolv.analysis.matgenlab.analysis.MultiEntry")
    value=strjoin(string(cellfun(@(x)x.name,entry.entry_list, ...
        "UniformOutput",false))," + ");
else,value=entry.to_pretty_string();end
end
function output=parsePlotOptions(output,input)
names=fieldnames(output);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            index<numel(input)&& ...
            any(strcmpi(string(input{index}),string(names)))
        key=names{strcmpi(string(input{index}),string(names))};
        output.(key)=input{index+1};index=index+2;
    else
        output.(names{position})=input{index};
        position=position+1;index=index+1;
    end
end
end
