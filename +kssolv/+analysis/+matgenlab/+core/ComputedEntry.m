classdef ComputedEntry < kssolv.analysis.matgenlab.core.Entry
    %COMPUTEDENTRY Entry carrying corrections, parameters, data and an id.

    properties
        energy_adjustments cell = cell(1,0)
        parameters (1,1) struct = struct()
        data (1,1) struct = struct()
        entry_id = []
        name (1,1) string = ""
    end
    properties (Dependent)
        correction
    end
    properties (Dependent, SetAccess = private)
        uncorrected_energy
        uncorrected_energy_per_atom
        correction_per_atom
        correction_uncertainty
        correction_uncertainty_per_atom
    end

    methods
        function obj = ComputedEntry(composition, energy, varargin)
            if nargin == 0
                composition=kssolv.analysis.matgenlab.core.Composition();
                energy=0;
                emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.core.Entry(composition, energy);
            if emptyConstruction,return,end
            options = struct(correction=0, energy_adjustments={{}}, ...
                parameters=struct(), data=struct(), entry_id=[]);
            names = fieldnames(options);
            positional = 1;
            index = 1;
            while index <= numel(varargin)
                if (ischar(varargin{index}) || isstring(varargin{index})) && ...
                        any(strcmpi(string(varargin{index}), string(names)))
                    key = names{strcmpi(string(varargin{index}),string(names))};
                    if index == numel(varargin)
                        error("KSSOLV:Matgenlab:ComputedEntry:Arguments", ...
                            "Name-value arguments must occur in pairs.");
                    end
                    options.(key) = varargin{index+1}; index=index+2;
                else
                    if positional > numel(names)
                        error("KSSOLV:Matgenlab:ComputedEntry:Arguments", ...
                            "Too many positional arguments.");
                    end
                    options.(names{positional})=varargin{index};
                    positional=positional+1; index=index+1;
                end
            end
            if isempty(options.energy_adjustments)
                options.energy_adjustments={};
            elseif ~iscell(options.energy_adjustments)
                options.energy_adjustments=num2cell(options.energy_adjustments);
            end
            obj.energy_adjustments=reshape(options.energy_adjustments,1,[]);
            if abs(double(options.correction)) > 1e-12
                if ~isempty(obj.energy_adjustments)
                    error("KSSOLV:Matgenlab:ComputedEntry:CorrectionConflict", ...
                        "Specify correction or energy_adjustments, not both.");
                end
                obj.correction=options.correction;
            end
            if ~isempty(options.parameters),obj.parameters=options.parameters;end
            if ~isempty(options.data),obj.data=options.data;end
            obj.entry_id=options.entry_id;
            obj.name=obj.reduced_formula;
        end

        function value=get.uncorrected_energy(obj),value=obj.energy_;end
        function value=get.uncorrected_energy_per_atom(obj)
            value=obj.energy_/obj.composition.num_atoms;
        end
        function value=get.correction(obj)
            value=0;
            for index=1:numel(obj.energy_adjustments)
                adjustment=obj.energy_adjustments{index};
                if adjustment.value~=0,value=value+adjustment.value;end
            end
        end
        function obj=set.correction(obj,value)
            obj.energy_adjustments={ ...
                kssolv.analysis.matgenlab.core.ManualEnergyAdjustment(value)};
        end
        function value=get.correction_per_atom(obj)
            value=obj.correction/obj.composition.num_atoms;
        end
        function value=get.correction_uncertainty(obj)
            variance=0; hasNonzero=false;
            for index=1:numel(obj.energy_adjustments)
                adjustment=obj.energy_adjustments{index};
                if adjustment.value~=0
                    hasNonzero=true;
                end
                if adjustment.value~=0 && isfinite(adjustment.uncertainty)
                    variance=variance+adjustment.uncertainty^2;
                end
            end
            if ~hasNonzero || variance<=1e-24
                value=NaN;
            else
                value=sqrt(variance);
            end
        end
        function value=get.correction_uncertainty_per_atom(obj)
            value=obj.correction_uncertainty/obj.composition.num_atoms;
        end

        function value=normalize(obj,mode)
            if nargin<2,mode="formula_unit";end
            factor=obj.normalizationFactor(mode);
            adjustments=cell(size(obj.energy_adjustments));
            for index=1:numel(adjustments)
                adjustments{index}= ...
                    kssolv.analysis.matgenlab.core.ComputedEntry. ...
                    decodeAdjustment(obj.energy_adjustments{index}.as_dict());
                adjustments{index}.normalize(factor);
            end
            value=kssolv.analysis.matgenlab.core.ComputedEntry( ...
                obj.composition/factor,obj.energy_/factor, ...
                "energy_adjustments",adjustments, ...
                "parameters",obj.parameters,"data",obj.data, ...
                "entry_id",obj.entry_id);
        end

        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.core.Entry(obj);
            data.x_class="ComputedEntry";
            data.entry_id=obj.entry_id;
            data.correction=obj.correction;
            data.energy_adjustments=cellfun(@(item)item.as_dict(), ...
                obj.energy_adjustments,"UniformOutput",false);
            data.parameters=obj.parameters; data.data=obj.data;
        end
        function data=asDict(obj),data=obj.as_dict();end
        function tf=eq(obj,other)
            if ~isa(other,"kssolv.analysis.matgenlab.core.ComputedEntry")
                tf=false; return
            end
            if ~isempty(obj.entry_id)&&~isempty(other.entry_id)&& ...
                    string(obj.entry_id)~=string(other.entry_id)
                tf=false;return
            end
            tf=abs(obj.energy-other.energy)<=1e-8+1e-5*abs(other.energy) && ...
                obj.composition==other.composition;
        end
        function value=copy(obj)
            value=kssolv.analysis.matgenlab.core.ComputedEntry( ...
                obj.composition,obj.uncorrected_energy, ...
                "energy_adjustments",obj.energy_adjustments, ...
                "parameters",obj.parameters,"data",obj.data, ...
                "entry_id",obj.entry_id);
        end
    end

    methods (Static)
        function obj=from_dict(data)
            raw={};
            if isfield(data,"energy_adjustments")&&~isempty(data.energy_adjustments)
                raw=data.energy_adjustments;
                if isstruct(raw),raw=num2cell(raw);
                elseif ~iscell(raw),raw={raw};end
            end
            adjustments=cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.ComputedEntry.decodeAdjustment(item), ...
                raw,"UniformOutput",false);
            correction=0;
            if isfield(data,"correction")&&abs(data.correction)>1e-12&&isempty(adjustments)
                correction=data.correction;
            end
            obj=kssolv.analysis.matgenlab.core.ComputedEntry( ...
                data.composition,data.energy,"correction",correction, ...
                "energy_adjustments",adjustments, ...
                "parameters",fieldOr(data,"parameters",struct()), ...
                "data",fieldOr(data,"data",struct()), ...
                "entry_id",fieldOr(data,"entry_id",[]));
            function value=fieldOr(input,name,default)
                if isfield(input,name)&&~isempty(input.(name)),value=input.(name);
                else,value=default;end
            end
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
        end
        function obj=decodeAdjustment(data)
            if isa(data,"kssolv.analysis.matgenlab.core.EnergyAdjustment")
                obj=data;return
            end
            cls="";
            if isfield(data,"x_class"),cls=string(data.x_class);
            elseif isfield(data,"class"),cls=string(data.class);end
            switch cls
                case "ConstantEnergyAdjustment"
                    obj=kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment.from_dict(data);
                case "ManualEnergyAdjustment"
                    obj=kssolv.analysis.matgenlab.core.ManualEnergyAdjustment.from_dict(data);
                case "CompositionEnergyAdjustment"
                    obj=kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment.from_dict(data);
                case "TemperatureEnergyAdjustment"
                    obj=kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment.from_dict(data);
                otherwise
                    obj=kssolv.analysis.matgenlab.core.EnergyAdjustment.from_dict(data);
            end
        end
    end
end
