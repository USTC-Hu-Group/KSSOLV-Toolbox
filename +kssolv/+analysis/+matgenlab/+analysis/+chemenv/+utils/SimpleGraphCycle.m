%#ok<*AGROW,*IFBDUP,*NOCOMMA>
classdef SimpleGraphCycle < kssolv.analysis.matgenlab.util.MSONable
    %SIMPLEGRAPHCYCLE Canonically ordered cycle in a simple graph.
    %#ok<*ALIGN>
    properties
        nodes
        ordered (1,1) logical=false
    end
    methods
        function obj=SimpleGraphCycle(nodes,varargin)
            if nargin==0,obj.nodes=[];return,end
            defaults=struct(validate=true,ordered=[]);
            options=parseOptions(defaults,varargin);
            obj.nodes=normalizeNodes(nodes);
            if options.validate,obj.validate();end
            if isempty(options.ordered),obj=obj.order();
            else,obj.ordered=logical(options.ordered);end
        end
        function validate(obj,varargin)
            strict=false;
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1}),strict=varargin{2};
                else,strict=varargin{1};end
            end
            count=nodeCount(obj.nodes);
            if count==0,message="Empty cycle is not valid.";
            elseif count==2,message="Simple graph cycle with 2 nodes is not valid.";
            elseif hasDuplicates(obj.nodes),message="Duplicate nodes.";
            elseif strict&&~strictlySortable(obj.nodes)
                message="The nodes are not sortable.";
            else,return,end
            error("KSSOLV:Matgenlab:ChemEnv:SimpleGraphCycle", ...
                "SimpleGraphCycle is not valid : %s",message);
        end
        function obj=order(obj,varargin)
            raise=true;
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1}),raise=varargin{2};
                else,raise=varargin{1};end
            end
            try,obj.validate(true);
            catch exception
                if ~raise,obj.ordered=false;return,end
                rethrow(exception)
            end
            count=nodeCount(obj.nodes);
            if count==1,obj.ordered=true;return,end
            keys=nodeKeys(obj.nodes);[~,minimum]=min(keys);
            previous=mod(minimum-2,count)+1;next=mod(minimum,count)+1;
            if keys(previous)<keys(next)
                indices=[minimum:-1:1,count:-1:minimum+1];
            else,indices=[minimum:count,1:minimum-1];end
            obj.nodes=subsetNodes(obj.nodes,indices);obj.ordered=true;
        end
        function value=eq(obj,other)
            if ~isa(other,class(obj)),value=false;return,end
            if ~obj.ordered||~other.ordered
                error("KSSOLV:Matgenlab:ChemEnv:CycleOrder", ...
                    "Cycles must be ordered before comparison.");
            end
            value=nodesEqual(obj.nodes,other.nodes);
        end
        function value=ne(obj,other),value=~eq(obj,other);end
        function value=length(obj),value=nodeCount(obj.nodes);end
        function value=char(obj)
            lines=["Simple cycle with nodes :",string(nodeKeys(obj.nodes))];
            value=char(strjoin(lines,newline));
        end
        function value=asDict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv.utils.graph_utils", ...
                x_class="SimpleGraphCycle",nodes=obj.nodes,ordered=obj.ordered);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_edges(edges,varargin)
            ordered=true;
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1}),ordered=varargin{2};
                else,ordered=varargin{1};end
            end
            edges=normalizeEdges(edges);
            if ordered
                nodes=edges(:,1);
                if any(~cellfun(@nodesScalarEqual,edges(1:end-1,2), ...
                        edges(2:end,1)))|| ...
                        ~nodesScalarEqual(edges{end,2},edges{1,1})
                    cycleError();
                end
            else
                remaining=edges;nodes=remaining(end,:);remaining(end,:)=[];
                while ~isempty(remaining)
                    previous=nodes{end};found=0;
                    for index=1:size(remaining,1)
                        if nodesScalarEqual(previous,remaining{index,1})
                            nodes{end+1}=remaining{index,2};found=index;break
                        elseif nodesScalarEqual(previous,remaining{index,2})
                            nodes{end+1}=remaining{index,1};found=index;break
                        end
                    end
                    if found==0,cycleError();end
                    remaining(found,:)=[];
                end
                if ~nodesScalarEqual(nodes{1},nodes{end}),cycleError();end
                nodes(end)=[];
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                SimpleGraphCycle(collapseNodes(nodes));
        end
        function obj=from_dict(value,varargin)
            validate=false;
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1}),validate=varargin{2};
                else,validate=varargin{1};end
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                SimpleGraphCycle(value.nodes,"validate",validate, ...
                "ordered",logical(value.ordered));
        end
    end
end
function output=parseOptions(output,args)
names=string(fieldnames(output));
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        name=names(strcmpi(string(args{index}),names));
        output.(char(name))=args{index+1};
    end
else
    for index=1:numel(args),output.(char(names(index)))=args{index};end
end
end
function value=normalizeNodes(nodes)
if iscell(nodes),value=reshape(nodes,1,[]);else,value=reshape(nodes,1,[]);end
end
function value=nodeCount(nodes),value=numel(nodes);end
function value=nodeKeys(nodes)
if isnumeric(nodes),value=double(nodes);return,end
value=zeros(1,numel(nodes));
for index=1:numel(nodes)
    node=nodes{index};
    if isnumeric(node),value(index)=node;
    elseif isprop(node,"isite"),value(index)=node.isite;
    else,error("KSSOLV:Matgenlab:ChemEnv:CycleOrder","Node is not sortable.");end
end
end
function value=strictlySortable(nodes)
try,keys=nodeKeys(nodes);value=numel(unique(keys))==numel(keys);
catch,value=false;end
end
function value=hasDuplicates(nodes)
try,value=numel(unique(nodeKeys(nodes)))~=numel(nodes);
catch
    value=false;
    for first=1:numel(nodes)
        for second=first+1:numel(nodes)
            if nodesScalarEqual(nodeAt(nodes,first),nodeAt(nodes,second))
                value=true;return
            end
        end
    end
end
end
function value=nodeAt(nodes,index)
if iscell(nodes),value=nodes{index};else,value=nodes(index);end
end
function value=subsetNodes(nodes,indices)
value=nodes(indices);
end
function value=nodesEqual(first,second)
if numel(first)~=numel(second),value=false;return,end
value=true;
for index=1:numel(first)
    if ~nodesScalarEqual(nodeAt(first,index),nodeAt(second,index))
        value=false;return
    end
end
end
function value=nodesScalarEqual(first,second)
try,value=logical(first==second);catch,value=isequal(first,second);end
end
function edges=normalizeEdges(input)
if isnumeric(input),edges=num2cell(input);else,edges=input;end
end
function value=collapseNodes(input)
if all(cellfun(@isnumeric,input)),value=cell2mat(input);else,value=input;end
end
function cycleError()
error("KSSOLV:Matgenlab:ChemEnv:SimpleGraphCycle", ...
    "Could not construct a cycle from edges.");
end
