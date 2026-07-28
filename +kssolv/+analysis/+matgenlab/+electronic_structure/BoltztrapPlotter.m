classdef BoltztrapPlotter
    %BOLTZTRAPPLOTTER Native plots for BoltzTraP analyzer-compatible objects.
    properties (SetAccess=private)
        bz
    end
    methods
        function obj=BoltztrapPlotter(bz),obj.bz=bz;end
        function ax=plot_seebeck_eff_mass_mu(obj,temps,output,Lambda)
            if nargin<2||isempty(temps),temps=300;end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(Lambda),Lambda=.5;end
            ax=obj.specialMu("get_seebeck_eff_mass",temps,output,Lambda, ...
                "Seebeck effective mass (m_e)");
        end
        function ax=plot_complexity_factor_mu(obj,temps,output,Lambda)
            if nargin<2||isempty(temps),temps=300;end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(Lambda),Lambda=.5;end
            ax=obj.specialMu("get_complexity_factor",temps,output,Lambda, ...
                "Complexity factor");
        end
        function ax=plot_seebeck_mu(obj,temp,output,xlim)
            if nargin<2||isempty(temp),temp=600;end
            if nargin<3||isempty(output),output="eig";end
            if nargin<4,xlim=[];end
            ax=obj.metricMu("get_seebeck",temp,output,1,xlim,false,"Seebeck (µV/K)");
        end
        function ax=plot_conductivity_mu(obj,temp,output,relaxationTime,xlim)
            if nargin<2||isempty(temp),temp=600;end
            if nargin<3||isempty(output),output="eig";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            if nargin<5,xlim=[];end
            ax=obj.metricMu("get_conductivity",temp,output,relaxationTime,xlim,true,"Conductivity (1/Ω/m)");
        end
        function ax=plot_power_factor_mu(obj,temp,output,relaxationTime,xlim)
            if nargin<2||isempty(temp),temp=600;end
            if nargin<3||isempty(output),output="eig";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            if nargin<5,xlim=[];end
            ax=obj.metricMu("get_power_factor",temp,output,relaxationTime,xlim,true,"Power factor");
        end
        function ax=plot_zt_mu(obj,temp,output,relaxationTime,xlim)
            if nargin<2||isempty(temp),temp=600;end
            if nargin<3||isempty(output),output="eig";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            if nargin<5,xlim=[];end
            ax=obj.metricMu("get_zt",temp,output,relaxationTime,xlim,false,"zT");
        end
        function ax=plot_seebeck_temp(obj,doping,output)
            if nargin<2||isempty(doping),doping="all";end
            if nargin<3||isempty(output),output="average";end
            ax=obj.metricTemp("get_seebeck",doping,output,1,false,"Seebeck (µV/K)");
        end
        function ax=plot_conductivity_temp(obj,doping,output,relaxationTime)
            if nargin<2||isempty(doping),doping="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricTemp("get_conductivity",doping,output,relaxationTime,true,"Conductivity (1/Ω/m)");
        end
        function ax=plot_power_factor_temp(obj,doping,output,relaxationTime)
            if nargin<2||isempty(doping),doping="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricTemp("get_power_factor",doping,output,relaxationTime,true,"Power factor");
        end
        function ax=plot_zt_temp(obj,doping,output,relaxationTime)
            if nargin<2||isempty(doping),doping="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricTemp("get_zt",doping,output,relaxationTime,false,"zT");
        end
        function ax=plot_eff_mass_temp(obj,doping,output)
            if nargin<2||isempty(doping),doping="all";end
            if nargin<3||isempty(output),output="average";end
            ax=obj.metricTemp("get_average_eff_mass",doping,output,1,false,"Effective mass (m_e)");
        end
        function ax=plot_seebeck_dop(obj,temps,output)
            if nargin<2||isempty(temps),temps="all";end
            if nargin<3||isempty(output),output="average";end
            ax=obj.metricDoping("get_seebeck",temps,output,1,false,"Seebeck (µV/K)");
        end
        function ax=plot_conductivity_dop(obj,temps,output,relaxationTime)
            if nargin<2||isempty(temps),temps="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricDoping("get_conductivity",temps,output,relaxationTime,true,"Conductivity (1/Ω/m)");
        end
        function ax=plot_power_factor_dop(obj,temps,output,relaxationTime)
            if nargin<2||isempty(temps),temps="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricDoping("get_power_factor",temps,output,relaxationTime,true,"Power factor");
        end
        function ax=plot_zt_dop(obj,temps,output,relaxationTime)
            if nargin<2||isempty(temps),temps="all";end
            if nargin<3||isempty(output),output="average";end
            if nargin<4||isempty(relaxationTime),relaxationTime=1e-14;end
            ax=obj.metricDoping("get_zt",temps,output,relaxationTime,false,"zT");
        end
        function ax=plot_eff_mass_dop(obj,temps,output)
            if nargin<2||isempty(temps),temps="all";end
            if nargin<3||isempty(output),output="average";end
            ax=obj.metricDoping("get_average_eff_mass",temps,output,1,false,"Effective mass (m_e)");
        end
        function ax=plot_dos(obj,sigma)
            if nargin<2||isempty(sigma),sigma=.05;end
            plotter=kssolv.analysis.matgenlab.electronic_structure.DosPlotter(false,false,sigma);
            plotter.add_dos("t",getMember(obj.bz,"dos"));ax=plotter.get_plot();
        end
        function ax=plot_carriers(obj,temp)
            if nargin<2||isempty(temp),temp=300;end
            concentrations=getMember(obj.bz,"carrier_conc");
            values=abs(valueAt(concentrations,temp))/(double(getMember(obj.bz,"vol"))*1e-24);
            ax=basicAxes();semilogy(ax,getMember(obj.bz,"mu_steps"),values,"LineWidth",2);
            obj.addMuGuides(ax,temp);xlabel(ax,"Chemical potential (eV)");ylabel(ax,"carrier concentration (cm^{-3})");
        end
        function ax=plot_hall_carriers(obj,temp)
            if nargin<2||isempty(temp),temp=300;end
            result=invoke(obj.bz,"get_hall_carrier_concentration");
            ax=basicAxes();semilogy(ax,getMember(obj.bz,"mu_steps"),abs(valueAt(result,temp)),"LineWidth",2);
            obj.addMuGuides(ax,temp);xlabel(ax,"Chemical potential (eV)");ylabel(ax,"Hall carrier concentration (cm^{-3})");
        end
    end
    methods (Access=private)
        function ax=specialMu(obj,method,temps,output,Lambda,ylabelText)
            ax=basicAxes();temps=reshape(double(temps),1,[]);
            for temp=temps
                values=invoke(obj.bz,method,"output",output,"temp",temp,"Lambda",Lambda);
                plot(ax,getMember(obj.bz,"mu_steps"),values,"LineWidth",2,"DisplayName",temp+" K");
            end
            xlabel(ax,"Chemical potential (eV)");ylabel(ax,ylabelText);legend(ax,"show");
        end
        function ax=metricMu(obj,method,temp,output,relaxation,xlimits,logScale,ylabelText)
            args={"output",output,"doping_levels",false};
            if method~="get_seebeck",args=[args,{"relaxation_time",relaxation}];end
            result=invoke(obj.bz,method,args{:});values=valueAt(result,temp);
            ax=basicAxes();if logScale,semilogy(ax,getMember(obj.bz,"mu_steps"),values,"LineWidth",2);
            else,plot(ax,getMember(obj.bz,"mu_steps"),values,"LineWidth",2);end
            obj.addMuGuides(ax,temp);if ~isempty(xlimits),xlim(ax,reshape(double(xlimits),1,2));end
            xlabel(ax,"Chemical potential (eV)");ylabel(ax,ylabelText);
        end
        function ax=metricTemp(obj,method,doping,output,relaxation,logScale,ylabelText)
            args={"output",output};if method~="get_seebeck"&&method~="get_average_eff_mass",args=[args,{"relaxation_time",relaxation}];end
            result=invoke(obj.bz,method,args{:});ax=basicAxes();
            for carrier=["n","p"]
                carrierData=valueAt(result,carrier);temperatures=numericKeys(carrierData);
                levels=valueAt(getMember(obj.bz,"doping"),carrier);
                requested=levels;if ~(ischar(doping)||isstring(doping))||string(doping)~="all",requested=double(doping);end
                for level=reshape(requested,1,[])
                    index=find(abs(levels-level)<=max(1,abs(level))*eps(100),1);if isempty(index),continue,end
                    y=zeros(1,numel(temperatures));
                    for tt=1:numel(temperatures),array=valueAt(carrierData,temperatures(tt));y(tt)=selectDoping(array,index);end
                    if logScale,semilogy(ax,temperatures,y,"DisplayName",carrier+" "+level);
                    else,plot(ax,temperatures,y,"DisplayName",carrier+" "+level);end
                end
            end
            xlabel(ax,"Temperature (K)");ylabel(ax,ylabelText);legend(ax,"show");
        end
        function ax=metricDoping(obj,method,temps,output,relaxation,logScale,ylabelText)
            args={"output",output};if method~="get_seebeck"&&method~="get_average_eff_mass",args=[args,{"relaxation_time",relaxation}];end
            result=invoke(obj.bz,method,args{:});ax=basicAxes();
            for carrier=["n","p"]
                carrierData=valueAt(result,carrier);available=numericKeys(carrierData);
                requested=available;if ~(ischar(temps)||isstring(temps))||string(temps)~="all",requested=double(temps);end
                x=valueAt(getMember(obj.bz,"doping"),carrier);
                for temp=reshape(requested,1,[])
                    y=valueAt(carrierData,temp);
                    if logScale,loglog(ax,x,collapseOutput(y),"DisplayName",carrier+" "+temp+" K");
                    else,semilogx(ax,x,collapseOutput(y),"DisplayName",carrier+" "+temp+" K");end
                end
            end
            xlabel(ax,"Doping concentration (cm^{-3})");ylabel(ax,ylabelText);legend(ax,"show");
        end
        function addMuGuides(obj,ax,temp)
            try
                mu=getMember(obj.bz,"mu_doping");
                for carrier=["n","p"]
                    values=valueAt(valueAt(mu,carrier),temp);
                    if ~isempty(values),xline(ax,values(1),"--");xline(ax,values(end),"--");end
                end
            catch
            end
            try
                xline(ax,double(getMember(obj.bz,"gap")),"k-");
            catch
            end
        end
    end
end

function ax=basicAxes(),fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");box(ax,"on");end
function value=invoke(subject,name,varargin)
name=char(name);
if isobject(subject)&&ismethod(subject,name)
    value=subject.(name)(varargin{:});
elseif isstruct(subject)&&isfield(subject,name)&&isa(subject.(name),"function_handle")
    value=subject.(name)(varargin{:});
else
    error("KSSOLV:Matgenlab:BoltztrapPlotter:AnalyzerMethod", ...
        "Analyzer does not provide %s.",name);
end
end
function value=getMember(subject,name)
name=char(name);
if isobject(subject)&&isprop(subject,name)
    value=subject.(name);
elseif isstruct(subject)&&isfield(subject,name)
    value=subject.(name);
elseif strcmp(name,"carrier_conc")
    if isobject(subject)&&isprop(subject,"_carrier_conc")
        value=subject.("_carrier_conc");
    elseif isstruct(subject)&&isfield(subject,"x_carrier_conc")
        value=subject.x_carrier_conc;
    else
        error("missing");
    end
else
    error("KSSOLV:Matgenlab:BoltztrapPlotter:AnalyzerField", ...
        "Analyzer does not provide %s.",name);
end
end
function value=valueAt(mapping,key)
if isa(mapping,"containers.Map")
    candidates={key,char(string(key))};value=[];found=false;
    for ii=1:numel(candidates),if isKey(mapping,candidates{ii}),value=mapping(candidates{ii});found=true;break,end,end
    if ~found,error("missing key");end
elseif isstruct(mapping)
    field=matlab.lang.makeValidName(char(string(key)));
    if isfield(mapping,field)
        value=mapping.(field);
    elseif isfield(mapping,char(string(key)))
        value=mapping.(char(string(key)));
    else
        error("missing key");
    end
else
    if isnumeric(key),value=mapping(key);else,error("missing key");end
end
end
function keys=numericKeys(mapping)
if isa(mapping,"containers.Map"),raw=string(mapping.keys);
else,raw=string(fieldnames(mapping));end
raw=erase(raw,"x");keys=sort(str2double(raw));keys=keys(~isnan(keys));
end
function value=selectDoping(array,index),array=squeeze(array);if isvector(array),value=array(index);else,value=mean(array(index,:),"all");end,end
function value=collapseOutput(array),array=squeeze(array);if isvector(array),value=reshape(array,1,[]);else,value=mean(array,ndims(array));value=reshape(value,1,[]);end,end
