classdef ThermoPlotter
    %THERMOPLOTTER Thermodynamic curves computed from a PhononDos.

    properties (SetAccess=private)
        dos
        structure
    end

    methods
        function obj=ThermoPlotter(dos,structure)
            if nargin<2,structure=[];end
            obj.dos=dos;obj.structure=structure;
        end

        function fig=plot_cv(obj,tmin,tmax,ntemp,ylimValue,varargin)
            if nargin<5,ylimValue=[];end
            fig=obj.plotThermo("cv",linspace(tmin,tmax,ntemp), ...
                1,cvLabel(obj),ylimValue,varargin{:});
        end

        function fig=plot_entropy(obj,tmin,tmax,ntemp,ylimValue,varargin)
            if nargin<5,ylimValue=[];end
            fig=obj.plotThermo("entropy",linspace(tmin,tmax,ntemp), ...
                1,entropyLabel(obj),ylimValue,varargin{:});
        end

        function fig=plot_internal_energy( ...
                obj,tmin,tmax,ntemp,ylimValue,varargin)
            if nargin<5,ylimValue=[];end
            fig=obj.plotThermo("internal_energy", ...
                linspace(tmin,tmax,ntemp),1e-3, ...
                energyLabel(obj,"E"),ylimValue,varargin{:});
        end

        function fig=plot_helmholtz_free_energy( ...
                obj,tmin,tmax,ntemp,ylimValue,varargin)
            if nargin<5,ylimValue=[];end
            fig=obj.plotThermo("helmholtz_free_energy", ...
                linspace(tmin,tmax,ntemp),1e-3, ...
                energyLabel(obj,"F"),ylimValue,varargin{:});
        end

        function fig=plot_thermodynamic_properties( ...
                obj,tmin,tmax,ntemp,ylimValue,varargin)
            if nargin<5,ylimValue=[];end
            temperatures=linspace(tmin,tmax,ntemp);
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            plot(ax,temperatures,obj.values("cv",temperatures), ...
                "DisplayName",cvLabel(obj),varargin{:});
            plot(ax,temperatures,obj.values("entropy",temperatures), ...
                "DisplayName",entropyLabel(obj),varargin{:});
            plot(ax,temperatures,1e-3*obj.values( ...
                "internal_energy",temperatures), ...
                "DisplayName",energyLabel(obj,"E"),varargin{:});
            plot(ax,temperatures,1e-3*obj.values( ...
                "helmholtz_free_energy",temperatures), ...
                "DisplayName",energyLabel(obj,"F"),varargin{:});
            xlabel(ax,"T (K)");ylabel(ax,"Thermodynamic properties");
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
            legend(ax,"show","Location","best");hold(ax,"off");
        end
    end

    methods (Access=private)
        function fig=plotThermo(obj,name,temperatures,factor, ...
                label,ylimValue,varargin)
            fig=figure("Visible","off");ax=axes(fig);
            plot(ax,temperatures,factor*obj.values(name,temperatures), ...
                varargin{:});
            xlabel(ax,"T (K)");ylabel(ax,label);
            xlim(ax,[min(temperatures),max(temperatures)]);
            if ~isempty(ylimValue),ylim(ax,ylimValue);end
        end

        function result=values(obj,name,temperatures)
            result=zeros(size(temperatures));
            for index=1:numel(temperatures)
                temp=temperatures(index);
                switch name
                    case "cv"
                        result(index)=obj.dos.cv(temp,obj.structure);
                    case "entropy"
                        result(index)=obj.dos.entropy(temp,obj.structure);
                    case "internal_energy"
                        result(index)=obj.dos.internal_energy( ...
                            temp,obj.structure);
                    case "helmholtz_free_energy"
                        result(index)=obj.dos.helmholtz_free_energy( ...
                            temp,obj.structure);
                end
            end
        end
    end
end

function value=cvLabel(obj)
if isempty(obj.structure),value="C_v (J/K/mol-c)";
else,value="C_v (J/K/mol)";end
end
function value=entropyLabel(obj)
if isempty(obj.structure),value="S (J/K/mol-c)";
else,value="S (J/K/mol)";end
end
function value=energyLabel(obj,symbol)
if isempty(obj.structure),suffix="mol-c";else,suffix="mol";end
value="Δ"+symbol+" (kJ/"+suffix+")";
end
