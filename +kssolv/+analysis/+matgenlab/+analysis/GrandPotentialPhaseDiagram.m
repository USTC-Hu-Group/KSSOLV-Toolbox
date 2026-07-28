classdef GrandPotentialPhaseDiagram < kssolv.analysis.matgenlab.analysis.PhaseDiagram
    %#ok<*ALIGN>
    %GRANDPOTENTIALPHASEDIAGRAM Phase diagram open to specified components.
    properties
        chempots cell=cell(0,2)
        original_entries cell=cell(1,0)
    end
    methods
        function obj=GrandPotentialPhaseDiagram(entries,chempots,elements,varargin)
            if nargin==0
                entries={kssolv.analysis.matgenlab.analysis.PDEntry("H",0)};
                chempots=cell(0,2);elements={"H"};emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            if isa(entries,"kssolv.analysis.matgenlab.core.EntrySet")
                entries=entries.entries;
            elseif ~iscell(entries),entries=num2cell(entries);end
            normalized=normalizeChempots(chempots);
            if nargin<3||isempty(elements)
                elements={};
                for item=entries,elements=[elements,item{1}.elements];end %#ok<AGROW>
                elements=uniqueElements(elements);
            else
                if ~iscell(elements),elements=num2cell(elements);end
                elements=cellfun(@(x)kssolv.analysis.matgenlab.core. ...
                    getElSp(x),elements,"UniformOutput",false);
            end
            open=cellfun(@(x)x.symbol,normalized(:,1));
            elements=elements(~cellfun(@(x)any(open==string(x.symbol)),elements));
            wrapped={};
            for item=entries
                originalSymbols=cellfun(@(x)x.symbol,item{1}.elements);
                if any(ismember(originalSymbols,cellfun(@(x)x.symbol,elements)))
                    wrapped{end+1}=kssolv.analysis.matgenlab.analysis. ...
                        GrandPotPDEntry(item{1},normalized); %#ok<AGROW>
                end
            end
            obj@kssolv.analysis.matgenlab.analysis.PhaseDiagram( ...
                wrapped,elements,varargin{:});
            obj.chempots=normalized;
            obj.original_entries=entries;
            if emptyConstruction,return,end
        end
        function text=char(obj)
            pieces=strings(1,size(obj.chempots,1));
            for ii=1:numel(pieces)
                pieces(ii)=sprintf("mu_%s = %.4f",obj.chempots{ii,1}.symbol,obj.chempots{ii,2});
            end
            names=cellfun(@(x)x.name,obj.stable_entries);
            text=sprintf("%s GrandPotentialPhaseDiagram with chempots = '%s'%d stable phases: %s", ...
                strjoin(cellfun(@(x)x.symbol,obj.elements),"-"), ...
                strjoin(pieces,", "),numel(names),strjoin(names,", "));
        end
        function data=as_dict(obj)
            pots=cell(size(obj.chempots,1),2);
            for ii=1:size(pots,1),pots(ii,:)={char(obj.chempots{ii,1}.symbol),obj.chempots{ii,2}};end
            data=struct(x_module="pymatgen.analysis.phase_diagram", ...
                x_class="GrandPotentialPhaseDiagram", ...
                all_entries={cellfun(@(x)x.as_dict(),obj.original_entries,"UniformOutput",false)}, ...
                chempots={pots}, ...
                elements={cellfun(@(x)char(x.symbol),obj.elements,"UniformOutput",false)});
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            raw=data.all_entries;if isstruct(raw),raw=num2cell(raw);end
            entries=cellfun(@decodeEntry,raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram( ...
                entries,data.chempots,data.elements);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.analysis.GrandPotentialPhaseDiagram.from_dict(data);end
    end
end

function value=normalizeChempots(input)
if isa(input,"containers.Map")
    keys_=input.keys;value=cell(numel(keys_),2);
    for ii=1:numel(keys_),value(ii,:)={keys_{ii},input(keys_{ii})};end
elseif isstruct(input)
    keys_=fieldnames(input);value=cell(numel(keys_),2);
    for ii=1:numel(keys_),value(ii,:)={keys_{ii},input.(keys_{ii})};end
elseif iscell(input),value=input;
else,error("KSSOLV:Matgenlab:GrandPotentialPhaseDiagram:Chempots","Unsupported mapping.");end
for ii=1:size(value,1)
    value{ii,1}=kssolv.analysis.matgenlab.core.getElSp(value{ii,1});
    value{ii,2}=double(value{ii,2});
end
end
function elements=uniqueElements(input)
elements={};symbols=strings(1,0);
for item=input
    if ~any(symbols==item{1}.symbol),symbols(end+1)=item{1}.symbol;elements{end+1}=item{1};end %#ok<AGROW>
end
[~,order]=sort(cellfun(@(x)x.X,elements));elements=elements(order);
end
function value=decodeEntry(data)
if isobject(data),value=data;return,end
cls="";if isfield(data,"x_class"),cls=string(data.x_class);end
if cls=="ComputedEntry",value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(data);
elseif cls=="PDEntry",value=kssolv.analysis.matgenlab.analysis.PDEntry.from_dict(data);
else,value=kssolv.analysis.matgenlab.core.Entry.from_dict(data);end
end
