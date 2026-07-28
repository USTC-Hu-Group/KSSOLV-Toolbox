classdef BSDOSPlotter
    %BSDOSPLOTTER Combined band-structure and density-of-states plot.
    properties
        bs_projection="elements"
        dos_projection="elements"
        vb_energy_range (1,1) double=4
        cb_energy_range (1,1) double=4
        fixed_cb_energy (1,1) logical=false
        egrid_interval (1,1) double=1
        font (1,1) string="Times New Roman"
        axis_fontsize (1,1) double=20
        tick_fontsize (1,1) double=15
        legend_fontsize (1,1) double=14
        bs_legend="best"
        dos_legend="best"
        rgb_legend (1,1) logical=true
        fig_size (1,2) double=[11,8.5]
    end
    methods
        function obj=BSDOSPlotter(varargin)
            options=struct(bs_projection="elements",dos_projection="elements", ...
                vb_energy_range=4,cb_energy_range=4,fixed_cb_energy=false, ...
                egrid_interval=1,font="Times New Roman",axis_fontsize=20, ...
                tick_fontsize=15,legend_fontsize=14,bs_legend="best", ...
                dos_legend="best",rgb_legend=true,fig_size=[11,8.5]);
            options=parseOptions(options,varargin);names=fieldnames(options);
            for ii=1:numel(names),obj.(names{ii})=options.(names{ii});end
        end
        function axesOut=get_plot(obj,bs,dos)
            if nargin<3,dos=[];end
            fig=figure("Visible","off","Position",[100,100,obj.fig_size(1)*80,obj.fig_size(2)*80]);
            if isempty(dos),layout=tiledlayout(fig,1,1);else,layout=tiledlayout(fig,1,2,"TileSpacing","compact");end
            bsAx=nexttile(layout);hold(bsAx,"on");
            plotter=kssolv.analysis.matgenlab.electronic_structure.BSPlotter(bs);
            data=plotter.bs_plot_data(true);colors=lines(4);spins=fieldnames(data.energy);
            for ss=1:numel(spins)
                style="-";if strcmp(spins{ss},"down"),style="--";end
                for pp=1:numel(data.distances)
                    plot(bsAx,data.distances{pp},data.energy.(spins{ss}){pp}.', ...
                        style,"Color",colors(ss,:),"DisplayName",spins{ss});
                end
            end
            ticks=plotter.get_ticks();[tickDistance,tickLabels]=uniqueTicks(ticks);
            set(bsAx,"XTick",tickDistance, ...
                "XTickLabel",tickLabels,"FontSize",obj.tick_fontsize, ...
                "FontName",obj.font);
            emin=-obj.vb_energy_range;
            if obj.fixed_cb_energy
                emax=obj.cb_energy_range;
            elseif data.is_metal
                emax=obj.cb_energy_range;
            else
                emax=obj.cb_energy_range+bs.get_band_gap().energy;
            end
            ylim(bsAx,[emin,emax]);xlim(bsAx,[0,bs.distance(end)]);
            xlabel(bsAx,"Wavevector k","FontSize",obj.axis_fontsize);
            ylabel(bsAx,"E-E_F / eV","FontSize",obj.axis_fontsize);
            yline(bsAx,0,"k--");box(bsAx,"on");
            if ~isempty(obj.bs_legend),legend(bsAx,"show","Location","best");end
            if isempty(dos),axesOut=bsAx;return,end
            dosAx=nexttile(layout);hold(dosAx,"on");
            curves=selectDos(dos,obj.dos_projection);labels=curves.keys;
            for ii=1:numel(labels)
                curve=curves(labels{ii});names=fieldnames(curve.densities);
                for ss=1:numel(names)
                    density=curve.densities.(names{ss});
                    if strcmp(names{ss},"down"),density=-density;end
                    plot(dosAx,density,curve.energies-curve.efermi, ...
                        "LineWidth",1.5,"DisplayName",labels{ii});
                end
            end
            ylim(dosAx,[emin,emax]);yline(dosAx,0,"k--");
            xlabel(dosAx,"DOS","FontSize",obj.axis_fontsize);
            set(dosAx,"YTickLabel",[],"FontSize",obj.tick_fontsize,"FontName",obj.font);
            if ~isempty(obj.dos_legend),legend(dosAx,"show","Location","best");end
            box(dosAx,"on");axesOut=[bsAx,dosAx];
        end
    end
end
function curves=selectDos(dos,projection)
curves=containers.Map("KeyType","char","ValueType","any");
if isa(dos,"kssolv.analysis.matgenlab.electronic_structure.CompleteDos")
    if isempty(projection)
        curves("Total")=dos;
    elseif strcmpi(projection,"elements")
        curves=asMap(dos.get_element_dos());
    elseif strcmpi(projection,"orbitals")
        curves=asMap(dos.get_spd_dos());
    else
        error("KSSOLV:Matgenlab:BSDOSPlotter:Projection", ...
            "dos_projection must be elements, orbitals, or empty.");
    end
else
    curves("Total")=dos;
end
end
function value=asMap(input)
if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end
end
function output=parseOptions(output,input)
names=fieldnames(output);pos=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&&any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;
    end
end
end
function [distance,labels]=uniqueTicks(ticks)
[distance,~,groups]=unique(ticks.distance,"stable");labels=strings(size(distance));
for ii=1:numel(distance),labels(ii)=strjoin(unique(ticks.label(groups==ii),"stable"),"|");end
end
