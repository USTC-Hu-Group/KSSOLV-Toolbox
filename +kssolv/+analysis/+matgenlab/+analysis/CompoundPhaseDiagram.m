classdef CompoundPhaseDiagram < kssolv.analysis.matgenlab.analysis.PhaseDiagram
    %#ok<*ALIGN,*NOCOMMA>
    %COMPOUNDPHASEDIAGRAM Phase diagram with compound terminal coordinates.
    properties (Constant)
        amount_tol=1e-5
    end
    properties
        original_entries cell=cell(1,0)
        terminal_compositions cell=cell(1,0)
        normalize_terminals (1,1) logical=true
        species_mapping cell=cell(0,2)
    end
    methods
        function obj=CompoundPhaseDiagram(entries,terminalCompositions,normalizeTerminals)
            if nargin==0
                entries={kssolv.analysis.matgenlab.analysis.PDEntry("H",0)};
                terminalCompositions={kssolv.analysis.matgenlab.core.Composition("H")};
                normalizeTerminals=true;emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            if nargin<3,normalizeTerminals=true;end
            if isa(entries,"kssolv.analysis.matgenlab.core.EntrySet")
                entries=entries.entries;
            elseif ~iscell(entries),entries=num2cell(entries);end
            if ~iscell(terminalCompositions),terminalCompositions=num2cell(terminalCompositions);end
            terminals=cellfun(@(x)asComposition(x),terminalCompositions,"UniformOutput",false);
            transformedTerminals=terminals;
            if normalizeTerminals
                transformedTerminals=cellfun(@(x)x.fractional_composition, ...
                    terminals,"UniformOutput",false);
            end
            mapping=cell(numel(terminals),2);
            for ii=1:numel(terminals)
                mapping(ii,:)={transformedTerminals{ii}, ...
                    kssolv.analysis.matgenlab.core.DummySpecies("X"+ ...
                    kssolv.analysis.matgenlab.analysis.CompoundPhaseDiagram.num2str(ii-1))};
            end
            transformed={};
            for item=entries
                try
                    transformed{end+1}=kssolv.analysis.matgenlab.analysis. ...
                        TransformedPDEntry(item{1},mapping); %#ok<AGROW>
                catch exception
                    if exception.identifier~="KSSOLV:Matgenlab:TransformedPDEntryError"
                        rethrow(exception);
                    end
                end
            end
            obj@kssolv.analysis.matgenlab.analysis.PhaseDiagram( ...
                transformed,mapping(:,2).');
            obj.original_entries=entries;obj.terminal_compositions=terminals;
            obj.normalize_terminals=normalizeTerminals;obj.species_mapping=mapping;
            if emptyConstruction,return,end
        end
        function [entries,mapping]=transform_entries(obj,entries,terminals)
            if isa(entries,"kssolv.analysis.matgenlab.core.EntrySet"),entries=entries.entries;end
            if ~iscell(entries),entries=num2cell(entries);end
            if ~iscell(terminals),terminals=num2cell(terminals);end
            if obj.normalize_terminals
                terminals=cellfun(@(x)asComposition(x).fractional_composition, ...
                    terminals,"UniformOutput",false);
            else
                terminals=cellfun(@asComposition,terminals,"UniformOutput",false);
            end
            mapping=cell(numel(terminals),2);
            for ii=1:numel(terminals)
                mapping(ii,:)={terminals{ii},kssolv.analysis.matgenlab.core. ...
                    DummySpecies("X"+obj.num2str(ii-1))};
            end
            output={};
            for item=entries
                try,output{end+1}=kssolv.analysis.matgenlab.analysis. ...
                        TransformedPDEntry(item{1},mapping); %#ok<AGROW>
                catch exception
                    if exception.identifier~="KSSOLV:Matgenlab:TransformedPDEntryError",rethrow(exception);end
                end
            end
            entries=output;
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.analysis.phase_diagram", ...
                x_class="CompoundPhaseDiagram", ...
                original_entries={cellfun(@(x)x.as_dict(),obj.original_entries,"UniformOutput",false)}, ...
                terminal_compositions={cellfun(@(x)x.as_dict(),obj.terminal_compositions,"UniformOutput",false)}, ...
                normalize_terminal_compositions=obj.normalize_terminals);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function value=num2str(number)
            code=double('f');count=double('z')-code+1;
            multiplier=floor(number/count);remainder=mod(number,count)+1;
            value=string([repmat(char(code),1,multiplier),char(code-1+remainder)]);
        end
        function obj=from_dict(data)
            raw=data.original_entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cellfun(@decodeEntry,raw,"UniformOutput",false);
            raw=data.terminal_compositions;if isstruct(raw),raw=num2cell(raw);end
            terminals=cellfun(@(x)kssolv.analysis.matgenlab.core.Composition.from_dict(x), ...
                raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.CompoundPhaseDiagram( ...
                entries,terminals,data.normalize_terminal_compositions);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.CompoundPhaseDiagram.from_dict(data);end
    end
end

function value=asComposition(input)
if isa(input,"kssolv.analysis.matgenlab.core.Composition"),value=input;
else,value=kssolv.analysis.matgenlab.core.Composition(input);end
end
function value=decodeEntry(data)
if isobject(data),value=data;return,end
cls="";if isfield(data,"x_class"),cls=string(data.x_class);end
if cls=="ComputedEntry",value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
elseif cls=="PDEntry",value=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
else,value=kssolv.analysis.matgenlab.core.Entry.from_dict(data);end
end
