classdef PourbaixEntry < kssolv.analysis.matgenlab.util.MSONable
    %POURBAIXENTRY Thermodynamic plane for a solid or aqueous ion.
    %#ok<*ALIGN>
    properties
        entry
        concentration (1,1) double=1
        phase_type (1,1) string="Solid"
        charge (1,1) double=0
        uncorrected_energy (1,1) double=0
        entry_id=[]
    end
    properties (Dependent,SetAccess=private)
        npH
        nH2O
        nPhi
        name
        energy
        energy_per_atom
        elements
        normalized_energy
        conc_term
        normalization_factor
        composition
        num_atoms
    end
    methods
        function obj=PourbaixEntry(entry,varargin)
            if nargin==0,return,end
            entryId=[];concentration=1e-6;
            if ~isempty(varargin)&&isName(varargin{1},["entry_id","concentration"])
                for index=1:2:numel(varargin)
                    if index==numel(varargin)
                        error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                            "A value is required after '%s'.",varargin{index});
                    end
                    switch lower(string(varargin{index}))
                        case "entry_id",entryId=varargin{index+1};
                        case "concentration",concentration=varargin{index+1};
                        otherwise
                            error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                                "Unknown option '%s'.",varargin{index});
                    end
                end
            else
                if ~isempty(varargin),entryId=varargin{1};end
                if numel(varargin)>1,concentration=varargin{2};end
            end
            obj.entry=entry;
            if isa(entry,"kssolv.analysis.matgenlab.analysis.IonEntry")
                obj.concentration=double(concentration);
                obj.phase_type="Ion";obj.charge=entry.ion.charge;
            else
                obj.concentration=1;obj.phase_type="Solid";obj.charge=0;
            end
            obj.uncorrected_energy=entry.energy;
            if ~isempty(entryId),obj.entry_id=entryId;
            elseif isprop(entry,"entry_id")&&~isempty(entry.entry_id)
                obj.entry_id=entry.entry_id;
            end
        end
        function value=get.npH(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=weightedMulti(obj,"npH");return
            end
            value=obj.composition.amountOf("H")-2*obj.composition.amountOf("O");
        end
        function value=get.nH2O(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=weightedMulti(obj,"nH2O");
            else,value=obj.composition.amountOf("O");end
        end
        function value=get.nPhi(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=weightedMulti(obj,"nPhi");
            else,value=obj.npH-obj.charge;end
        end
        function value=get.name(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=strjoin(string(cellfun(@(entry)entryName(entry),obj.entry_list, ...
                    "UniformOutput",false))," + ");
            elseif obj.phase_type=="Solid",value=string(obj.entry.reduced_formula)+"(s)";
            else,value=string(obj.entry.name);end
        end
        function value=get.energy(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=weightedMulti(obj,"energy");
            else
                value=obj.uncorrected_energy+obj.conc_term-(-2.4583)*obj.nH2O;
            end
        end
        function value=get.energy_per_atom(obj),value=obj.energy/obj.num_atoms;end
        function value=get.elements(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=obj.composition.elements;
            else,value=obj.entry.elements;end
        end
        function value=energy_at_conditions(obj,pH,V)
            value=obj.energy+obj.npH*.0591.*pH+obj.nPhi.*V;
        end
        function value=get_element_fraction(obj,element)
            value=obj.composition.amountOf(element)*obj.normalization_factor;
        end
        function value=get.normalized_energy(obj)
            value=obj.energy*obj.normalization_factor;
        end
        function value=normalized_energy_at_conditions(obj,pH,V)
            value=obj.energy_at_conditions(pH,V)*obj.normalization_factor;
        end
        function value=get.conc_term(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=weightedMulti(obj,"conc_term");
            else,value=.0591*log10(obj.concentration);end
        end
        function value=get.normalization_factor(obj)
            value=1/(obj.num_atoms-obj.composition.amountOf("H")- ...
                obj.composition.amountOf("O"));
        end
        function value=get.composition(obj)
            if isa(obj,"kssolv.analysis.matgenlab.analysis.MultiEntry")
                value=kssolv.analysis.matgenlab.core.Composition();
                for index=1:numel(obj.entry_list)
                    component=obj.entry_list{index};
                    componentComposition=entryComposition(component);
                    value=value+componentComposition*obj.weights(index);
                end
            else,value=obj.entry.composition;end
        end
        function value=get.num_atoms(obj),value=obj.composition.num_atoms;end
        function value=to_pretty_string(obj),value=obj.name;end
        function value=eq(obj,other)
            value=isa(other,"kssolv.analysis.matgenlab.analysis.PourbaixEntry")&& ...
                obj.composition==other.composition&& ...
                abs(obj.energy-other.energy)<1e-10&&obj.name==other.name;
        end
        function value=ne(obj,other),value=~eq(obj,other);end
        function value=asDict(obj)
            value=struct(x_module="pymatgen.analysis.pourbaix_diagram", ...
                x_class="PourbaixEntry",entry=obj.entry.as_dict(), ...
                concentration=obj.concentration,entry_id=obj.entry_id, ...
                entry_type=obj.phase_type);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_dict(value)
            if string(value.entry_type)=="Ion"
                entry=kssolv.analysis.matgenlab.analysis.IonEntry. ...
                    from_dict(value.entry);
            else
                entry=decodeEntry(value.entry);
            end
            obj=kssolv.analysis.matgenlab.analysis.PourbaixEntry( ...
                entry,value.entry_id,value.concentration);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.analysis.PourbaixEntry.from_dict(value);
        end
    end
end

function entry=decodeEntry(value)
kind="";
if isfield(value,"x_class"),kind=string(value.x_class);
elseif isfield(value,"class"),kind=string(value.class);end
switch kind
    case "ComputedStructureEntry"
        entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(value);
    case "PDEntry"
        entry=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(value);
    otherwise
        entry=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(value);
end
end
function value=weightedMulti(obj,name)
value=0;
for index=1:numel(obj.entry_list)
    component=obj.entry_list{index};
    candidate=entryValue(component,name);
    value=value+obj.weights(index)*candidate;
end
end
function value=entryValue(entry,name)
if isa(entry,"kssolv.analysis.matgenlab.analysis.MultiEntry")
    value=weightedMulti(entry,name);return
end
composition=entry.entry.composition;
switch name
    case "npH"
        value=composition.amountOf("H")-2*composition.amountOf("O");
    case "nH2O"
        value=composition.amountOf("O");
    case "nPhi"
        value=composition.amountOf("H")-2*composition.amountOf("O")- ...
            entry.charge;
    case "conc_term"
        value=.0591*log10(entry.concentration);
    case "energy"
        value=entry.uncorrected_energy+.0591*log10(entry.concentration)+ ...
            2.4583*composition.amountOf("O");
    otherwise
        error("KSSOLV:Matgenlab:Pourbaix:Property", ...
            "Unsupported weighted property '%s'.",name);
end
end
function value=entryComposition(entry)
if ~isa(entry,"kssolv.analysis.matgenlab.analysis.MultiEntry")
    value=entry.entry.composition;return
end
value=kssolv.analysis.matgenlab.core.Composition();
for index=1:numel(entry.entry_list)
    value=value+entryComposition(entry.entry_list{index})*entry.weights(index);
end
end
function value=entryName(entry)
if isa(entry,"kssolv.analysis.matgenlab.analysis.MultiEntry")
    names=cellfun(@entryName,entry.entry_list,"UniformOutput",false);
    value=strjoin(string(names)," + ");
elseif entry.phase_type=="Solid"
    value=string(entry.entry.reduced_formula)+"(s)";
else
    value=string(entry.entry.name);
end
end
function tf=isName(value,names)
tf=(ischar(value)||isstring(value))&&isscalar(string(value))&& ...
    any(strcmpi(string(value),names));
end
