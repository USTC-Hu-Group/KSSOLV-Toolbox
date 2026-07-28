classdef MultiEntry < kssolv.analysis.matgenlab.analysis.PourbaixEntry
    %MULTIENTRY Weighted mixture satisfying a multi-element composition.
    %#ok<*ALIGN>
    properties
        entry_list cell={}
        weights double=[]
    end
    methods
        function obj=MultiEntry(entryList,varargin)
            obj@kssolv.analysis.matgenlab.analysis.PourbaixEntry();
            if nargin==0,return,end
            if ~iscell(entryList),entryList=num2cell(entryList);end
            obj.entry_list=reshape(entryList,1,[]);
            weights=[];
            if ~isempty(varargin)
                if (ischar(varargin{1})||isstring(varargin{1}))&& ...
                        strcmpi(string(varargin{1}),"weights")
                    if numel(varargin)<2
                        error("KSSOLV:Matgenlab:Pourbaix:Arguments", ...
                            "A value is required after 'weights'.");
                    end
                    weights=varargin{2};
                else,weights=varargin{1};end
            end
            if isempty(weights),weights=ones(1,numel(entryList));end
            if numel(weights)~=numel(entryList)
                error("KSSOLV:Matgenlab:Pourbaix:Weights", ...
                    "One weight is required for each entry.");
            end
            obj.weights=reshape(double(weights),1,[]);
            obj.phase_type="Multi";obj.entry_id=cellfun(@(x)x.entry_id, ...
                obj.entry_list,"UniformOutput",false);
        end
        function value=asDict(obj)
            entries=cellfun(@(x)x.as_dict(),obj.entry_list, ...
                "UniformOutput",false);
            value=struct(x_module="pymatgen.analysis.pourbaix_diagram", ...
                x_class="MultiEntry",entry_list={entries},weights=obj.weights);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_dict(value)
            entries=cell(1,numel(value.entry_list));
            for index=1:numel(entries)
                entries{index}=kssolv.analysis.matgenlab.analysis. ...
                    PourbaixEntry.from_dict(value.entry_list{index});
            end
            obj=kssolv.analysis.matgenlab.analysis.MultiEntry( ...
                entries,value.weights);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.analysis.MultiEntry.from_dict(value);
        end
    end
end
