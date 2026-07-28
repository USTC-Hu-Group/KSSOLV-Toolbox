classdef PhononDosPlotter < handle
    %PHONONDOSPLOTTER Mutable collection and MATLAB plotter for phonon DOS.

    properties (SetAccess=private)
        stack (1,1) logical
        sigma
        doses
    end

    methods
        function obj=PhononDosPlotter(stack,sigma)
            if nargin<1,stack=false;end
            if nargin<2,sigma=[];end
            if ~(islogical(stack)&&isscalar(stack))
                error("KSSOLV:Matgenlab:PhononDosPlotter:Stack", ...
                    "The first argument stack expects a boolean.");
            end
            obj.stack=stack;
            obj.sigma=sigma;
            obj.doses=containers.Map( ...
                "KeyType","char","ValueType","any");
        end

        function add_dos(obj,label,dos,varargin)
            options=plotOptions(varargin{:});
            if isempty(obj.sigma)
                densities=dos.densities;
            else
                densities=dos.get_smeared_densities(obj.sigma);
            end
            obj.doses(char(string(label)))=struct( ...
                "frequencies",dos.frequencies, ...
                "densities",densities, ...
                "options",options);
        end

        function add_dos_dict(obj,dosDict,keySortFunction)
            if nargin<3,keySortFunction=[];end
            [keys,getValue]=dictionaryAdapter(dosDict);
            if ~isempty(keySortFunction)
                sortValues=cellfun(keySortFunction,keys, ...
                    UniformOutput=false);
                [~,order]=sort(string(sortValues));
                keys=keys(order);
            end
            for index=1:numel(keys)
                obj.add_dos(keys{index},getValue(keys{index}));
            end
        end

        function value=get_dos_dict(obj)
            value=containers.Map( ...
                "KeyType","char","ValueType","any");
            keys=obj.doses.keys;
            for index=1:numel(keys)
                record=obj.doses(keys{index});
                clean=rmfield(record,"options");
                optionNames=fieldnames(record.options);
                for optionIndex=1:numel(optionNames)
                    name=optionNames{optionIndex};
                    clean.(name)=record.options.(name);
                end
                value(keys{index})=clean;
            end
        end

        function ax=get_plot(obj,xlimValue,ylimValue,invertAxes, ...
                units,legendOptions,ax)
            if nargin<2,xlimValue=[];end
            if nargin<3,ylimValue=[];end
            if nargin<4||isempty(invertAxes),invertAxes=false;end
            if nargin<5||isempty(units),units="thz";end
            if nargin<6,legendOptions=[];end
            if nargin<7||isempty(ax)
                fig=figure("Visible","off");
                ax=axes(fig);
            end
            unit=kssolv.analysis.matgenlab.phonon.freq_units(units);
            hold(ax,"on");
            keys=obj.doses.keys;
            cumulative=[];
            for index=1:numel(keys)
                record=obj.doses(keys{index});
                frequencies=record.frequencies*unit.factor;
                densities=record.densities;
                if isempty(cumulative),cumulative=zeros(size(densities));end
                if obj.stack
                    cumulative=cumulative+densities;
                    densities=cumulative;
                end
                options=record.options;
                color=option(options,"color",[]);
                width=option(options,"linewidth",3);
                if invertAxes
                    x=densities;y=frequencies;
                else
                    x=frequencies;y=densities;
                end
                if obj.stack
                    handle=area(ax,x,y, ...
                        "DisplayName",keys{index});
                else
                    handle=plot(ax,x,y, ...
                        "DisplayName",keys{index}, ...
                        "LineWidth",width);
                end
                if ~isempty(color)
                    if obj.stack,handle.FaceColor=color;else,handle.Color=color;end
                end
            end
            if invertAxes
                yline(ax,0,"--k","LineWidth",2);
                xlabel(ax,"Density of states");
                ylabel(ax,"Frequencies ("+unit.label+")");
            else
                xline(ax,0,"--k","LineWidth",2);
                xlabel(ax,"Frequencies ("+unit.label+")");
                ylabel(ax,"Density of states");
            end
            if ~isempty(xlimValue),xlim(ax,xlimValue);end
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            if ~isempty(keys)
                if isstruct(legendOptions) && ...
                        isfield(legendOptions,"Location")
                    legend(ax,"show","Location",legendOptions.Location);
                else
                    legend(ax,"show");
                end
            end
            hold(ax,"off");
        end

        function save_plot(obj,filename,imgFormat,xlimValue, ...
                ylimValue,invertAxes,units)
            if nargin<3||isempty(imgFormat),imgFormat="eps";end
            if nargin<4,xlimValue=[];end
            if nargin<5,ylimValue=[];end
            if nargin<6,invertAxes=false;end
            if nargin<7,units="thz";end
            ax=obj.get_plot(xlimValue,ylimValue,invertAxes,units);
            exportgraphics(ax.Parent,filename, ...
                ContentType=imageContentType(imgFormat));
            close(ax.Parent);
        end

        function show(obj,varargin)
            ax=obj.get_plot(varargin{:});
            ax.Parent.Visible="on";
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

function [keys,getValue]=dictionaryAdapter(input)
if isa(input,"containers.Map")
    keys=input.keys;
    getValue=@(key)input(key);
elseif isstruct(input)
    keys=fieldnames(input).';
    getValue=@(key)input.(key);
else
    error("KSSOLV:Matgenlab:PhononDosPlotter:Dictionary", ...
        "dos_dict must be a struct or containers.Map.");
end
end

function value=imageContentType(format)
if any(lower(string(format))==["pdf","eps","svg"])
    value="vector";
else
    value="image";
end
end
