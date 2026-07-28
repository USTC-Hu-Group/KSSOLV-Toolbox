classdef ExpEntry < kssolv.analysis.matgenlab.analysis.PDEntry
    %EXPENTRY Experimental solid formation-enthalpy phase-diagram entry.
    properties
        thermodata cell = cell(1,0)
        temperature (1,1) double = 298
    end
    methods
        function obj=ExpEntry(composition,thermodata,varargin)
            if nargin==0
                composition=kssolv.analysis.matgenlab.core.Composition();
                thermodata={};emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            options=struct(temperature=298);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if isstruct(thermodata),thermodata=num2cell(thermodata);end
            if ~iscell(thermodata),thermodata=num2cell(thermodata);end
            energy=Inf;
            for index=1:numel(thermodata)
                item=thermodata{index};
                type=string(item.type);phase=string(item.phaseinfo);
                value=item.value;
                if type=="fH"&&~any(phase==["gas","liquid"])&&value<energy
                    energy=value;
                end
            end
            if emptyConstruction,energy=0;
            elseif ~isfinite(energy)
                error("KSSOLV:Matgenlab:ExpEntry:ThermoData", ...
                    "ThermoData does not contain a solid formation enthalpy.");
            end
            obj@kssolv.analysis.matgenlab.analysis.PDEntry(composition,energy);
            if emptyConstruction,return,end
            obj.thermodata=thermodata;obj.temperature=options.temperature;
        end
        function data=as_dict(obj)
            raw=cellfun(@encodeThermo,obj.thermodata,"UniformOutput",false);
            data=struct(x_module="pymatgen.entries.exp_entries", ...
                x_class="ExpEntry",thermodata={raw}, ...
                composition=obj.composition.as_dict(), ...
                temperature=obj.temperature);
            function value=encodeThermo(item)
                if isstruct(item),value=item;else,value=item.as_dict();end
            end
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            raw=data.thermodata;if isstruct(raw),raw=num2cell(raw);end
            items=cellfun(@(item) ...
                kssolv.analysis.matgenlab.analysis.ThermoData.from_dict(item), ...
                raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.compatibility.ExpEntry( ...
                data.composition,items,"temperature",data.temperature);
        end
    end
end
