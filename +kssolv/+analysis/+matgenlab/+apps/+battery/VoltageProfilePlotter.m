classdef VoltageProfilePlotter < handle
    %VOLTAGEPROFILEPLOTTER Stair-step voltage-profile rendering.
    properties
        xaxis (1,1) string = "capacity"
        hide_negative (1,1) logical = false
    end
    properties (Access=private)
        labels_ string = strings(1,0)
        electrodes_ cell = cell(1,0)
    end
    methods
        function obj=VoltageProfilePlotter(xaxis,hideNegative)
            if nargin>=1,obj.xaxis=string(xaxis);end
            if nargin>=2,obj.hide_negative=logical(hideNegative);end
        end
        function add_electrode(obj,electrode,label)
            if nargin<3||strlength(string(label))==0
                label="Electrode "+string(numel(obj.electrodes_)+1);
            end
            existing=find(obj.labels_==string(label),1);
            if isempty(existing)
                obj.labels_(end+1)=string(label);
                obj.electrodes_{end+1}=electrode;
            else
                obj.electrodes_{existing}=electrode;
            end
        end
        function [x,y]=get_plot_data(obj,electrode,termZero)
            if nargin<3,termZero=true;end
            sub=electrode.get_sub_electrodes(true);
            x=zeros(1,2*numel(sub)+1);y=x;cursor=0;capacity=0;
            for index=1:numel(sub)
                item=sub{index};voltage=item.get_average_voltage();
                if obj.hide_negative&&voltage<0,continue,end
                cursor=cursor+2;
                switch obj.xaxis
                    case {"capacity_grav","capacity"}
                        x(cursor-1)=capacity;
                        capacity=capacity+item.get_capacity_grav();
                        x(cursor)=capacity;
                    case "capacity_vol"
                        x(cursor-1)=capacity;
                        capacity=capacity+item.get_capacity_vol();
                        x(cursor)=capacity;
                    case "x_form"
                        x(cursor-1:cursor)=[item.x_charge,item.x_discharge];
                    case "frac_x"
                        pair=item.voltage_pairs{1};
                        x(cursor-1:cursor)=[pair.frac_charge,pair.frac_discharge];
                    otherwise
                        error("KSSOLV:Matgenlab:BatteryPlotter:XAxis", ...
                            "xaxis must be capacity_grav, capacity_vol, x_form, or frac_x.");
                end
                y(cursor-1:cursor)=voltage;
            end
            x=x(1:cursor);y=y(1:cursor);
            if termZero&&~isempty(x),x(end+1)=x(end);y(end+1)=0;end
        end
        function ax=get_plot(obj,width,height,termZero,ax)
            if nargin<2,width=8;end
            if nargin<3,height=8;end
            if nargin<4,termZero=true;end
            if nargin<5||isempty(ax)
                figureHandle=figure("Visible","off", ...
                    "Units","inches","Position",[1,1,width,height]);
                ax=axes("Parent",figureHandle);
            end
            hold(ax,"on");ions=strings(1,0);formulas=strings(1,0);
            for index=1:numel(obj.electrodes_)
                electrode=obj.electrodes_{index};
                [x,y]=obj.get_plot_data(electrode,termZero);
                plot(ax,x,y,"-","LineWidth",2, ...
                    "DisplayName",obj.labels_(index));
                ions(end+1)=electrode.working_ion.symbol; %#ok<AGROW>
                formulas(end+1)=electrode.framework_formula; %#ok<AGROW>
            end
            legend(ax,"show");xlabel(ax,obj.chooseLabel(formulas,ions));
            ylabel(ax,"Voltage (V)");
        end
        function figureData=get_plotly_figure(obj,width,height,fontDict,termZero,varargin)
            if nargin<2,width=800;end
            if nargin<3,height=600;end
            if nargin<4||isempty(fontDict)
                fontDict=struct("family","Arial","size",24,"color","#000000");
            end
            if nargin<5,termZero=true;end
            traces=repmat(struct("x",[],"y",[],"mode","lines", ...
                "name",""),1,numel(obj.electrodes_));
            ions=strings(1,0);formulas=strings(1,0);
            for index=1:numel(obj.electrodes_)
                electrode=obj.electrodes_{index};
                [traces(index).x,traces(index).y]= ...
                    obj.get_plot_data(electrode,termZero);
                traces(index).name=obj.labels_(index);
                ions(end+1)=electrode.working_ion.symbol; %#ok<AGROW>
                formulas(end+1)=electrode.framework_formula; %#ok<AGROW>
            end
            layout=struct("title","Voltage vs. Capacity","width",width, ...
                "height",height,"font",fontDict, ...
                "xaxis",struct("title",obj.chooseLabel(formulas,ions)), ...
                "yaxis",struct("title","Voltage (V)"));
            for index=1:2:numel(varargin)
                layout.(matlab.lang.makeValidName(string(varargin{index})))= ...
                    varargin{index+1};
            end
            figureData=struct("data",traces,"layout",layout);
        end
        function show(obj,width,height)
            if nargin<2,width=8;end
            if nargin<3,height=6;end
            ax=obj.get_plot(width,height);set(ancestor(ax,"figure"),"Visible","on");
        end
        function save(obj,filename,width,height)
            if nargin<3,width=8;end
            if nargin<4,height=6;end
            ax=obj.get_plot(width,height);
            exportgraphics(ancestor(ax,"figure"),filename);
            close(ancestor(ax,"figure"));
        end
    end
    methods (Access=private)
        function label=chooseLabel(obj,formulas,ions)
            if any(obj.xaxis==["capacity","capacity_grav"])
                label="Capacity (mAh/g)";
            elseif obj.xaxis=="capacity_vol"
                label="Capacity (Ah/l)";
            elseif obj.xaxis=="x_form"
                if isscalar(unique(formulas))&&isscalar(unique(ions))
                    label="x in "+ions(1)+"<sub>x</sub>"+formulas(1);
                else
                    label="x Work Ion per Host F.U.";
                end
            elseif obj.xaxis=="frac_x"
                if isscalar(unique(ions))
                    label="Atomic Fraction of "+ions(1);
                else
                    label="Atomic Fraction of Working Ion";
                end
            else
                error("KSSOLV:Matgenlab:BatteryPlotter:XAxis", ...
                    "No xaxis label can be determined.");
            end
        end
    end
end
