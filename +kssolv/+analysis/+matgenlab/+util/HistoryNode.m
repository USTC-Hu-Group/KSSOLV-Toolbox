classdef HistoryNode
    %HISTORYNODE Provenance breadcrumb for StructureNL.
    properties
        name (1,1) string
        url (1,1) string
        description
    end
    methods
        function obj=HistoryNode(name,url,description)
            obj.name=string(name);obj.url=string(url);
            obj.description=description;
        end
        function data=as_dict(obj)
            data=struct("name",obj.name,"url",obj.url, ...
                "description",obj.description);
        end
        function data=asDict(obj),data=obj.as_dict();end
        function equal=eq(obj,other)
            equal=isa(other,class(obj))&&obj.name==other.name&& ...
                obj.url==other.url&&isequaln(obj.description, ...
                other.description);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.util.HistoryNode( ...
                data.name,data.url,data.description);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.util.HistoryNode.from_dict(data);
        end
        function obj=parse_history_node(value)
            if isa(value,"kssolv.analysis.matgenlab.util.HistoryNode")
                obj=value;
            elseif isstruct(value)
                required={'name','url','description'};
                if ~all(isfield(value,required))
                    error("KSSOLV:Matgenlab:HistoryNode:Fields", ...
                        "History node requires name, url and description.");
                end
                obj=kssolv.analysis.matgenlab.util.HistoryNode. ...
                    from_dict(value);
            elseif iscell(value)&&numel(value)==3
                obj=kssolv.analysis.matgenlab.util.HistoryNode( ...
                    value{1},value{2},value{3});
            else
                error("KSSOLV:Matgenlab:HistoryNode:Format", ...
                    "History node must be a struct or three-element cell.");
            end
        end
        function obj=parseHistoryNode(value)
            obj=kssolv.analysis.matgenlab.util.HistoryNode. ...
                parse_history_node(value);
        end
    end
end
