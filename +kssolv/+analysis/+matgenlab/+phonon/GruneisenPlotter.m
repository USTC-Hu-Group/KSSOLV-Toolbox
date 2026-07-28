classdef GruneisenPlotter
    %GRUNEISENPLOTTER Scatter plot for mesh Gruneisen parameters.
    properties (SetAccess=private)
        gruneisen
    end
    methods
        function obj=GruneisenPlotter(gruneisen),obj.gruneisen=gruneisen;end
        function ax=get_plot(obj,marker,markerSize,units)
            if nargin<2||isempty(marker),marker="o";end
            if nargin<3||isempty(markerSize),markerSize=6;end
            if nargin<4||isempty(units),units="thz";end
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            x=reshape(obj.gruneisen.frequencies,[],1)*unit.factor;
            y=reshape(obj.gruneisen.gruneisen,[],1);
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            count=max(1,numel(y)-1);
            for index=1:numel(y)
                color=[(index-1)/count,0,(numel(y)-index)/count];
                plot(ax,x(index),y(index),marker, ...
                    "Color",color,"MarkerSize",markerSize);
            end
            xlabel(ax,"Frequency ("+unit.label+")");
            ylabel(ax,"Grüneisen parameter");hold(ax,"off");
        end
        function show(obj,units)
            if nargin<2,units="thz";end
            ax=obj.get_plot([],[],units);ax.Parent.Visible="on";
        end
        function save_plot(obj,filename,imgFormat,units)
            if nargin<3||isempty(imgFormat),imgFormat="pdf";end
            if nargin<4,units="thz";end
            ax=obj.get_plot([],[],units);
            exportgraphics(ax.Parent,filename, ...
                ContentType=imageContentType(imgFormat));
            close(ax.Parent);
        end
    end
end
function value=imageContentType(format)
if any(lower(string(format))==["pdf","eps","svg"])
    value="vector";
else
    value="image";
end
end
