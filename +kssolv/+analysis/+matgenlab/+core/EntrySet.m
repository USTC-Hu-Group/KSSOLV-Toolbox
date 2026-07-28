classdef EntrySet < handle
    %ENTRYSET Mutable unique collection of Entry objects.
    properties
        entries cell=cell(1,0)
    end
    properties (Dependent,SetAccess=private)
        chemsys
        ground_states
    end
    methods
        function obj=EntrySet(entries)
            if nargin==0,return,end
            if ~iscell(entries),entries=num2cell(entries);end
            for index=1:numel(entries),obj.add(entries{index});end
        end
        function add(obj,entry)
            if ~obj.contains(entry),obj.entries{end+1}=entry;end
        end
        function discard(obj,entry)
            keep=~cellfun(@(item)item==entry,obj.entries);
            obj.entries=obj.entries(keep);
        end
        function tf=contains(obj,entry)
            tf=any(cellfun(@(item)item==entry,obj.entries));
        end
        function value=length(obj),value=numel(obj.entries);end
        function value=get.chemsys(obj)
            value=strings(1,0);
            for entry=obj.entries
                value=[value,cellfun(@(el)el.symbol,entry{1}.elements)]; %#ok<AGROW>
            end
            value=unique(value);
        end
        function value=get.ground_states(obj)
            groups=kssolv.analysis.matgenlab.core. ...
                group_entries_by_composition(obj.entries,true);
            value=cellfun(@(group)group{1},groups,"UniformOutput",false);
        end
        function remove_non_ground_states(obj),obj.entries=obj.ground_states;end
        function tf=is_ground_state(obj,entry)
            tf=any(cellfun(@(item)item==entry,obj.ground_states));
        end
        function value=get_subset_in_chemsys(obj,chemsys)
            requested=unique(string(chemsys));
            if ~all(ismember(requested,obj.chemsys))
                error("KSSOLV:Matgenlab:EntrySet:ChemicalSystem", ...
                    "Requested chemical system is not a subset.");
            end
            subset={};
            for entry=obj.entries
                symbols=cellfun(@(el)el.symbol,entry{1}.elements);
                if all(ismember(symbols,requested)),subset{end+1}=entry{1};end %#ok<AGROW>
            end
            value=kssolv.analysis.matgenlab.core.EntrySet(subset);
        end
        function data=as_dict(obj),data=struct(entries={obj.entries});end
        function data=asDict(obj),data=obj.as_dict();end
        function to_csv(obj,filename,latexify_names)
            if nargin<3,latexify_names=false;end
            elements={};
            for entry=obj.entries,elements=[elements,entry{1}.elements];end %#ok<AGROW>
            symbols=cellfun(@(el)el.symbol,elements);
            [~,uniqueIndices]=unique(symbols,"stable");elements=elements(uniqueIndices);
            electroneg=cellfun(@(el)el.X,elements);
            [~,order]=sort(electroneg);elements=elements(order);
            rows=cell(numel(obj.entries)+1,numel(elements)+2);
            rows(1,:)=[{"Name"},cellfun(@(el)char(el.symbol),elements, ...
                "UniformOutput",false),{"Energy"}];
            for index=1:numel(obj.entries)
                entry=obj.entries{index}; name=char(entry.name);
                if latexify_names,name=regexprep(name,'([0-9]+)','_{$1}');end
                rows{index+1,1}=name;
                for jj=1:numel(elements)
                    rows{index+1,jj+1}=entry.composition.amountOf(elements{jj});
                end
                rows{index+1,end}=entry.energy;
            end
            writecell(rows,filename);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            entries=data.entries;if isstruct(entries),entries=num2cell(entries);end
            if ~iscell(entries),entries={entries};end
            entries=cellfun(@(item)decode(item),entries,"UniformOutput",false);
            % Serialized rows are already an authoritative ordered set.
            obj=kssolv.analysis.matgenlab.core.EntrySet();
            obj.entries=entries;
            function value=decode(item)
                if isobject(item),value=item;return,end
                if isfield(item,"structure")
                    value=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(item);
                else
                    value=kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(item);
                end
            end
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.EntrySet.from_dict(data);
        end
        function obj=from_csv(filename)
            rows=readcell(filename);elements=string(rows(1,2:end-1));entries={};
            for ii=2:size(rows,1)
                pairs=cell(0,2);
                for jj=1:numel(elements)
                    amount=double(rows{ii,jj+1});
                    if amount>0,pairs(end+1,:)={char(elements(jj)),amount};end %#ok<AGROW>
                end
                entry=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                    pairs,double(rows{ii,end}), ...
                    "name",string(rows{ii,1}));
                entries{end+1}=entry; %#ok<AGROW>
            end
            signatures=cellfun(@(item)item.composition.formula+"|"+ ...
                string(sprintf("%.17g",item.energy)),entries);
            [~,keep]=unique(signatures,"stable");
            entries=entries(keep);
            % CSV rows are already the authoritative ordered set. Assigning in
            % bulk avoids the quadratic value-equality scan in add(), which is
            % material for the official 490-entry phase-diagram fixture.
            obj=kssolv.analysis.matgenlab.core.EntrySet();
            obj.entries=entries;
        end
    end
end
