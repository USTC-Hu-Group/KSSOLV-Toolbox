classdef GibbsComputedStructureEntry < kssolv.analysis.matgenlab.core.ComputedStructureEntry
    %GIBBSCOMPUTEDSTRUCTUREENTRY SISSO finite-temperature formation energy.
    properties
        formation_enthalpy_per_atom (1,1) double = 0
        temp (1,1) double = 300
        gibbs_model (1,1) string = "SISSO"
        interpolated (1,1) logical = false
        experimental (1,1) logical = false
    end
    methods
        function obj=GibbsComputedStructureEntry(structure,formationEnthalpy,varargin)
            if nargin==0
                structure=kssolv.analysis.matgenlab.core.Structure( ...
                    eye(3),{"H"},[0,0,0]);
                formationEnthalpy=0;emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            options=struct(temp=300,gibbs_model="SISSO",composition=[], ...
                correction=0,energy_adjustments={{}},parameters=struct(), ...
                data=struct(),entry_id=[]);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            if options.temp<300||options.temp>2000
                error("KSSOLV:Matgenlab:GibbsEntry:Temperature", ...
                    "Temperature must be in [300, 2000] K.");
            end
            if lower(string(options.gibbs_model))~="sisso"
                error("KSSOLV:Matgenlab:GibbsEntry:Model", ...
                    "The only supported Gibbs model is SISSO.");
            end
            [formula,~]=structure.composition.get_integer_formula_and_factor();
            [~,gases]= ...
                kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.tables();
            experimentalValue=isfield(gases,char(formula));
            entryId=options.entry_id;
            if experimentalValue&&(isempty(entryId)|| ...
                    ~contains(string(entryId),"Experimental"))
                entryId=string(entryId)+" (Experimental)";
            end
            obj@kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
                structure,0,"composition",options.composition, ...
                "correction",options.correction, ...
                "energy_adjustments",options.energy_adjustments, ...
                "parameters",options.parameters,"data",options.data, ...
                "entry_id",entryId);
            obj.temp=options.temp;obj.gibbs_model=string(options.gibbs_model);
            obj.experimental=experimentalValue;
            obj.formation_enthalpy_per_atom=formationEnthalpy;
            obj.interpolated=mod(obj.temp,100)~=0;
            if ~emptyConstruction,obj.energy_=obj.gf_sisso();end
        end
        function value=gf_sisso(obj)
            comp=obj.composition;
            if comp.is_element,value=0;return,end
            [formula,factor]=comp.get_integer_formula_and_factor();
            [elements,gases]= ...
                kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.tables();
            if obj.experimental
                data=gases.(char(formula));
                value=obj.interpolateMap(data,obj.temp)*factor;return
            end
            volumePerAtom=obj.structure.volume/obj.structure.num_sites;
            reducedMass=obj.reducedMass();
            delta=((-2.48e-4*log(volumePerAtom)- ...
                8.94e-5*reducedMass/volumePerAtom)*obj.temp+ ...
                .181*log(obj.temp)-.882);
            sumElements=0;
            amounts=comp.get_el_amt_dict();
            symbols=fieldnames(amounts);
            for index=1:numel(symbols)
                values=obj.temperatureSeries(elements,symbols{index});
                sumElements=sumElements+amounts.(symbols{index})* ...
                    interp1(values(:,1),values(:,2),obj.temp,"linear");
            end
            value=comp.num_atoms*(obj.formation_enthalpy_per_atom+delta)- ...
                sumElements;
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.core. ...
                ComputedStructureEntry(obj);
            data.x_module="pymatgen.entries.computed_entries";
            data.x_class="GibbsComputedStructureEntry";
            data.formation_enthalpy_per_atom=obj.formation_enthalpy_per_atom;
            data.temp=obj.temp;data.gibbs_model=obj.gibbs_model;
            data.interpolated=obj.interpolated;
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Access=private)
        function value=reducedMass(obj)
            reduced=obj.structure.composition.reduced_composition;
            symbols=string(cellfun(@(item)item.symbol,reduced.elements, ...
                "UniformOutput",false));
            denominator=(numel(symbols)-1)*reduced.num_atoms;
            if denominator==0,value=0;return,end
            total=0;
            for first=1:numel(symbols)-1
                for second=first+1:numel(symbols)
                    mass1=kssolv.analysis.matgenlab.core.Element( ...
                        symbols(first)).atomic_mass;
                    mass2=kssolv.analysis.matgenlab.core.Element( ...
                        symbols(second)).atomic_mass;
                    amount1=reduced.amountOf(symbols(first));
                    amount2=reduced.amountOf(symbols(second));
                    total=total+(amount1+amount2)*mass1*mass2/(mass1+mass2);
                end
            end
            value=total/denominator;
        end
        function value=interpolateMap(~,map,temp)
            names=fieldnames(map);temperatures=zeros(numel(names),1);
            values=zeros(numel(names),1);
            for index=1:numel(names)
                temperatures(index)=str2double(erase(names{index},"x"));
                values(index)=map.(names{index});
            end
            [temperatures,order]=sort(temperatures);
            value=interp1(temperatures,values(order),temp,"linear");
        end
        function values=temperatureSeries(~,table,symbol)
            names=fieldnames(table);values=zeros(numel(names),2);
            for index=1:numel(names)
                values(index,1)=str2double(erase(names{index},"x"));
                values(index,2)=table.(names{index}).(symbol);
            end
            values=sortrows(values,1);
        end
    end
    methods (Static)
        function values=from_pd(diagram,varargin)
            options=struct(temp=300,gibbs_model="SISSO");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            values={};
            for index=1:numel(diagram.all_entries)
                entry=diagram.all_entries{index};
                if ~isa(entry,"kssolv.analysis.matgenlab.core.ComputedStructureEntry")
                    error("KSSOLV:Matgenlab:GibbsEntry:Structure", ...
                        "Phase diagram entries must contain structures.");
                end
                if entry.is_element
                    isReference=any(cellfun(@(item)item==entry,diagram.el_refs(:,2)));
                    if ~isReference,continue,end
                end
                values{end+1}= ...
                    kssolv.analysis.matgenlab.analysis.compatibility. ...
                    GibbsComputedStructureEntry(entry.structure, ...
                    diagram.get_form_energy_per_atom(entry), ...
                    "temp",options.temp,"gibbs_model",options.gibbs_model, ...
                    "data",entry.data,"entry_id",entry.entry_id); %#ok<AGROW>
            end
        end
        function values=from_entries(entries,varargin)
            diagram=kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries);
            values=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.from_pd(diagram,varargin{:});
        end
        function obj=from_dict(data)
            structure=data.structure;
            if ~isa(structure,"kssolv.analysis.matgenlab.core.Structure")
                structure=kssolv.analysis.matgenlab.core.Structure.from_dict(structure);
            end
            adjustments={};
            if isfield(data,"energy_adjustments")
                raw=data.energy_adjustments;if isstruct(raw),raw=num2cell(raw);end
                adjustments=cellfun(@(item) ...
                    kssolv.analysis.matgenlab.core.ComputedEntry. ...
                    decodeAdjustment(item),raw,"UniformOutput",false);
            end
            obj=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry(structure, ...
                data.formation_enthalpy_per_atom,"temp",data.temp, ...
                "gibbs_model",data.gibbs_model, ...
                "energy_adjustments",adjustments, ...
                "parameters",kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.field_or(data,"parameters",struct()), ...
                "data",kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.field_or(data,"data",struct()), ...
                "entry_id",kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.field_or(data,"entry_id",[]));
        end
        function [elements,gases]=tables()
            persistent elementTable gasTable
            if isempty(elementTable)
                folder=fileparts(kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.config_path("g_els.json"));
                elementTable=jsondecode(fileread(fullfile(folder,"g_els.json")));
                gasTable=jsondecode(fileread(fullfile(folder,"nist_gas_gf.json")));
            end
            elements=elementTable;gases=gasTable;
        end
    end
end
