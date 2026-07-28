classdef AbstractElectrode < kssolv.analysis.matgenlab.util.MSONable
    %ABSTRACTELECTRODE Shared thermodynamic metrics for voltage-pair paths.
    properties
        voltage_pairs cell = cell(1,0)
        working_ion_entry = []
        framework_formula (1,1) string = ""
    end
    properties (Dependent,SetAccess=private)
        working_ion
        framework
        x_charge
        x_discharge
        max_delta_volume
        num_steps
        max_voltage
        min_voltage
        max_voltage_step
        normalization_mass
        normalization_volume
    end
    methods
        function obj=AbstractElectrode(voltagePairs,workingIonEntry,frameworkFormula)
            if nargin==0,return,end
            if ~iscell(voltagePairs),voltagePairs=num2cell(voltagePairs);end
            obj.voltage_pairs=reshape(voltagePairs,1,[]);
            obj.working_ion_entry=workingIonEntry;
            obj.framework_formula=string(frameworkFormula);
            if strlength(obj.framework_formula)==0,return,end
            obj.framework_formula=obj.framework.reduced_formula;
        end
        function value=get.working_ion(obj),value=obj.working_ion_entry.elements{1};end
        function value=get.framework(obj)
            value=kssolv.analysis.matgenlab.core.Composition(obj.framework_formula);
        end
        function value=get.x_charge(obj),value=obj.voltage_pairs{1}.x_charge;end
        function value=get.x_discharge(obj),value=obj.voltage_pairs{end}.x_discharge;end
        function value=get.max_delta_volume(obj)
            values=cellfun(@(x)x.vol_charge,obj.voltage_pairs);
            values=[values,cellfun(@(x)x.vol_discharge,obj.voltage_pairs)];
            value=max(values)/min(values)-1;
        end
        function value=get.num_steps(obj),value=numel(obj.voltage_pairs);end
        function value=get.max_voltage(obj)
            value=max(cellfun(@(x)x.voltage,obj.voltage_pairs));
        end
        function value=get.min_voltage(obj)
            value=min(cellfun(@(x)x.voltage,obj.voltage_pairs));
        end
        function value=get.max_voltage_step(obj)
            values=cellfun(@(x)x.voltage,obj.voltage_pairs);
            if numel(values)<2,value=0;else,value=max(values(1:end-1)-values(2:end));end
        end
        function value=get.normalization_mass(obj)
            value=obj.voltage_pairs{end}.mass_discharge;
        end
        function value=get.normalization_volume(obj)
            value=obj.voltage_pairs{end}.vol_discharge;
        end
        function count=length(obj),count=numel(obj.voltage_pairs);end
        function iterator=iter(obj),iterator=obj.voltage_pairs;end
        function tf=contains(obj,value)
            tf=any(cellfun(@(x)x==value,obj.voltage_pairs));
        end
        function varargout=subsref(obj,reference)
            if strcmp(reference(1).type,"()")&&isscalar(reference(1).subs)
                value=obj.voltage_pairs{reference(1).subs{1}};
                if numel(reference)>1
                    value=builtin("subsref",value,reference(2:end));
                end
                varargout{1}=value;
            else
                [varargout{1:nargout}]=builtin("subsref",obj,reference);
            end
        end
        function get_sub_electrodes(~,~)
            error("KSSOLV:Matgenlab:Battery:Abstract", ...
                "Concrete electrodes must implement get_sub_electrodes.");
        end
        function value=get_average_voltage(obj,minVoltage,maxVoltage)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            pairs=obj.selectVoltage(minVoltage,maxVoltage);
            if isempty(pairs),value=0;return,end
            capacity=sum(cellfun(@(x)x.mAh,pairs));
            value=sum(cellfun(@(x)x.mAh*x.voltage,pairs))/capacity;
        end
        function value=get_capacity_grav(obj,minVoltage,maxVoltage,useOverall)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            if nargin<4,useOverall=true;end
            pairs=obj.selectVoltage(minVoltage,maxVoltage);
            if useOverall||isempty(pairs),mass=obj.normalization_mass;
            else,mass=pairs{end}.mass_discharge;end
            value=sum(cellfun(@(x)x.mAh,pairs))/mass;
        end
        function value=get_capacity_vol(obj,minVoltage,maxVoltage,useOverall)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            if nargin<4,useOverall=true;end
            pairs=obj.selectVoltage(minVoltage,maxVoltage);
            if useOverall||isempty(pairs),volume=obj.normalization_volume;
            else,volume=pairs{end}.vol_discharge;end
            value=sum(cellfun(@(x)x.mAh,pairs))/volume*1e24/6.02214076e23;
        end
        function value=get_specific_energy(obj,minVoltage,maxVoltage,useOverall)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            if nargin<4,useOverall=true;end
            value=obj.get_capacity_grav(minVoltage,maxVoltage,useOverall)* ...
                obj.get_average_voltage(minVoltage,maxVoltage);
        end
        function value=get_energy_density(obj,minVoltage,maxVoltage,useOverall)
            if nargin<2,minVoltage=[];end
            if nargin<3,maxVoltage=[];end
            if nargin<4,useOverall=true;end
            value=obj.get_capacity_vol(minVoltage,maxVoltage,useOverall)* ...
                obj.get_average_voltage(minVoltage,maxVoltage);
        end
        function data=get_summary_dict(obj,printSubelectrodes)
            if nargin<2,printSubelectrodes=true;end
            data=struct("average_voltage",obj.get_average_voltage(), ...
                "max_voltage",obj.max_voltage,"min_voltage",obj.min_voltage, ...
                "max_delta_volume",obj.max_delta_volume, ...
                "max_voltage_step",obj.max_voltage_step, ...
                "capacity_grav",obj.get_capacity_grav(), ...
                "capacity_vol",obj.get_capacity_vol(), ...
                "energy_grav",obj.get_specific_energy(), ...
                "energy_vol",obj.get_energy_density(), ...
                "working_ion",obj.working_ion.symbol,"nsteps",obj.num_steps, ...
                "fracA_charge",obj.voltage_pairs{1}.frac_charge, ...
                "fracA_discharge",obj.voltage_pairs{end}.frac_discharge, ...
                "framework_formula",obj.framework_formula);
            if printSubelectrodes
                adjacent=obj.get_sub_electrodes(true);
                allPairs=obj.get_sub_electrodes(false);
                data.adj_pairs=cellfun(@(x)x.get_summary_dict(false), ...
                    adjacent,"UniformOutput",false);
                data.all_pairs=cellfun(@(x)x.get_summary_dict(false), ...
                    allPairs,"UniformOutput",false);
            end
        end
        function data=as_dict(obj)
            data=struct("x_module","pymatgen.apps.battery.battery_abc", ...
                "x_class",classLeaf(obj), ...
                "voltage_pairs",{cellfun(@(x)x.as_dict(),obj.voltage_pairs, ...
                "UniformOutput",false)}, ...
                "working_ion_entry",obj.working_ion_entry.as_dict(), ...
                "framework_formula",obj.framework_formula);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Access=protected)
        function pairs=selectVoltage(obj,minVoltage,maxVoltage)
            if isempty(minVoltage),minVoltage=obj.min_voltage;end
            if isempty(maxVoltage),maxVoltage=obj.max_voltage;end
            mask=cellfun(@(x)x.voltage>=minVoltage&&x.voltage<=maxVoltage, ...
                obj.voltage_pairs);
            pairs=obj.voltage_pairs(mask);
        end
    end
end
function name=classLeaf(obj)
parts=split(string(class(obj)),".");name=parts(end);
end
