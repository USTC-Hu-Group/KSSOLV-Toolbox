classdef ComputedStructureEntry < kssolv.analysis.matgenlab.core.ComputedEntry
    properties (Access = protected)
        structure_
    end
    properties (Dependent,SetAccess=private)
        structure
    end
    methods
        function obj=ComputedStructureEntry(structure,energy,varargin)
            if nargin==0
                structure=kssolv.analysis.matgenlab.core.Structure( ...
                    eye(3),{"H"},[0,0,0]);
                energy=0;emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            obj@kssolv.analysis.matgenlab.core.ComputedEntry( ...
                structure.composition,energy);
            obj.structure_=structure;
            if emptyConstruction,return,end
            options=struct(correction=0,composition=[],energy_adjustments={{}}, ...
                parameters=struct(),data=struct(),entry_id=[]);
            names=fieldnames(options); positional=1;index=1;
            while index<=numel(varargin)
                if (ischar(varargin{index})||isstring(varargin{index}))&& ...
                        any(strcmpi(string(varargin{index}),string(names)))
                    key=names{strcmpi(string(varargin{index}),string(names))};
                    options.(key)=varargin{index+1};index=index+2;
                else
                    options.(names{positional})=varargin{index};
                    positional=positional+1;index=index+1;
                end
            end
            composition=options.composition;
            if isempty(composition),composition=structure.composition;
            elseif ~isa(composition,"kssolv.analysis.matgenlab.core.Composition")
                composition=kssolv.analysis.matgenlab.core.Composition(composition);
            end
            [formula1,~]=composition.get_integer_formula_and_factor();
            [formula2,~]=structure.composition.get_integer_formula_and_factor();
            if string(formula1)~=string(formula2)
                error("KSSOLV:Matgenlab:ComputedStructureEntry:Composition", ...
                    "Mismatching composition provided.");
            end
            obj.composition_=composition;
            obj.energy_adjustments=options.energy_adjustments;
            if ~iscell(obj.energy_adjustments)
                obj.energy_adjustments=num2cell(obj.energy_adjustments);
            end
            if abs(options.correction)>1e-12
                if ~isempty(obj.energy_adjustments)
                    error("KSSOLV:Matgenlab:ComputedEntry:CorrectionConflict", ...
                        "Specify correction or energy_adjustments, not both.");
                end
                obj.correction=options.correction;
            end
            obj.parameters=options.parameters;obj.data=options.data;
            obj.entry_id=options.entry_id;obj.name=obj.reduced_formula;
            obj.structure_=structure;
        end
        function value=get.structure(obj),value=obj.structure_;end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.core.ComputedEntry(obj);
            data.x_class="ComputedStructureEntry";
            data.structure=obj.structure.as_dict();
        end
        function data=asDict(obj),data=obj.as_dict();end
        function value=normalize(obj,mode)
            if nargin<2,mode="formula_unit";end
            factor=obj.normalizationFactor(mode);
            base=normalize@kssolv.analysis.matgenlab.core.ComputedEntry(obj,mode);
            value=kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
                obj.structure,obj.energy_/factor,"composition",obj.composition/factor, ...
                "energy_adjustments",base.energy_adjustments, ...
                "parameters",obj.parameters,"data",obj.data, ...
                "entry_id",obj.entry_id);
        end
        function value=copy(obj)
            value=kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
                obj.structure,obj.uncorrected_energy,"composition",obj.composition, ...
                "energy_adjustments",obj.energy_adjustments, ...
                "parameters",obj.parameters,"data",obj.data, ...
                "entry_id",obj.entry_id);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            structure=data.structure;
            if ~isa(structure,"kssolv.analysis.matgenlab.core.Structure")
                structure=kssolv.analysis.matgenlab.core.Structure.from_dict(structure);
            end
            raw=fieldOr(data,"energy_adjustments",{});
            if isstruct(raw),raw=num2cell(raw);
            elseif ~iscell(raw),raw={raw};end
            adjustments=cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.ComputedEntry.decodeAdjustment(item), ...
                raw,"UniformOutput",false);
            correction=0;
            if isfield(data,"correction")&&abs(data.correction)>1e-12&&isempty(adjustments)
                correction=data.correction;
            end
            composition=fieldOr(data,"composition",[]);
            if isstruct(composition)
                names=string(fieldnames(composition));
                if any(endsWith(names,"_"))
                    % JSON sanitizes charged-species keys (e.g. Na+). The
                    % structure retains the exact decorated species.
                    composition=[];
                end
            end
            obj=kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
                structure,data.energy,"correction",correction, ...
                "composition",composition, ...
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
            obj=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);
        end
    end
end
