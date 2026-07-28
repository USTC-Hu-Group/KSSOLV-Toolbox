classdef SpectrumPlotter < handle
    %SPECTRUMPLOTTER Lightweight multi-spectrum MATLAB plotter.

    properties (SetAccess=private)
        spectra
        xshift (1,1) double = 0
        yshift (1,1) double = 0
        stack (1,1) logical = false
    end

    properties (Access=private)
        labels_ (1,:) string = strings(1,0)
        colors_ cell = cell(1,0)
    end

    methods
        function obj=SpectrumPlotter(xshift,yshift,stack,~)
            if nargin>=1 && ~isempty(xshift),obj.xshift=double(xshift);end
            if nargin>=2 && ~isempty(yshift),obj.yshift=double(yshift);end
            if nargin>=3 && ~isempty(stack),obj.stack=logical(stack);end
            obj.spectra=containers.Map( ...
                "KeyType","char","ValueType","any");
        end

        function add_spectrum(obj,label,spectrum,color)
            if nargin<4,color=[];end
            if ~isprop(spectrum,"x") || ~isprop(spectrum,"y")
                error("KSSOLV:Matgenlab:SpectrumPlotter:Spectrum", ...
                    "spectrum must expose x and y properties.");
            end
            key=string(label);
            existing=find(obj.labels_==key,1);
            obj.spectra(char(key))=spectrum;
            if isempty(existing)
                obj.labels_(end+1)=key;
                obj.colors_{end+1}=color;
            else
                obj.colors_{existing}=color;
            end
        end

        function add_spectra(obj,spectra,keySortFunction)
            if nargin<3,keySortFunction=[];end
            if isa(spectra,"containers.Map")
                keys=spectra.keys;
                if ~isempty(keySortFunction)
                    values=cellfun(keySortFunction,keys, ...
                        UniformOutput=false);
                    [~,order]=sort(string(values));
                    keys=keys(order);
                end
                for index=1:numel(keys)
                    obj.add_spectrum(keys{index},spectra(keys{index}));
                end
            elseif isstruct(spectra)
                names=fieldnames(spectra);
                for index=1:numel(names)
                    obj.add_spectrum(names{index},spectra.(names{index}));
                end
            else
                error("KSSOLV:Matgenlab:SpectrumPlotter:Spectra", ...
                    "spectra must be a struct or containers.Map.");
            end
        end

        function ax=get_plot(obj,xlimValue,ylimValue)
            if nargin<2,xlimValue=[];end
            if nargin<3,ylimValue=[];end
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            base=0;
            palette=lines(max(1,numel(obj.labels_)));
            for index=1:numel(obj.labels_)
                key=obj.labels_(index);
                spectrum=obj.spectra(char(key));
                color=obj.colors_{index};
                if isempty(color),color=palette(index,:);end
                shifted=spectrum.y+obj.yshift*(index-1);
                if obj.stack
                    if isscalar(base),base=zeros(size(shifted));end
                    x=[spectrum.x(:);flipud(spectrum.x(:))];
                    y=[base(:);flipud(shifted(:))];
                    fill(ax,x,y,color,"DisplayName",key, ...
                        "LineWidth",3);
                    base=base+spectrum.y;
                else
                    plot(ax,spectrum.x,shifted, ...
                        "Color",color,"DisplayName",key, ...
                        "LineWidth",3);
                end
                xlabel(ax,spectrum.XLABEL);
                ylabel(ax,spectrum.YLABEL);
            end
            if ~isempty(obj.labels_),legend(ax,"show");end
            if ~isempty(xlimValue),xlim(ax,xlimValue);end
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            hold(ax,"off");
        end

        function save_plot(obj,filename,imgFormat,xlimValue,ylimValue)
            if nargin<3||isempty(imgFormat),imgFormat="eps";end
            if nargin<4,xlimValue=[];end
            if nargin<5,ylimValue=[];end
            ax=obj.get_plot(xlimValue,ylimValue);
            exportgraphics(ax.Parent,filename,ContentType= ...
                imageContentType(imgFormat));
            close(ax.Parent);
        end

        function show(obj,varargin)
            obj.get_plot(varargin{:});
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
