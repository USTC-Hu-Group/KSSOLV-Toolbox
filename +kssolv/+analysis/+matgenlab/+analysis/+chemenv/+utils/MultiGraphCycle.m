%#ok<*ALIGN,*NOCOMMA>
classdef MultiGraphCycle < kssolv.analysis.matgenlab.util.MSONable
    %MULTIGRAPHCYCLE Canonically ordered cycle in an undirected multigraph.
    properties
        nodes
        edge_indices double=[]
        ordered (1,1) logical=false
        edge_deltas=[]
        per=[]
    end
    methods
        function obj=MultiGraphCycle(nodes,edgeIndices,varargin)
            if nargin==0,return,end
            defaults=struct(validate=true,ordered=[]);
            options=parseOptions(defaults,varargin);
            obj.nodes=reshape(nodes,1,[]);
            obj.edge_indices=reshape(double(edgeIndices),1,[]);
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
            count=numel(obj.nodes);
            if count~=numel(obj.edge_indices),message="Number of nodes differs from edges.";
            elseif count==0,message="Empty cycle is not valid.";
            elseif numel(unique(nodeKeys(obj.nodes)))~=count,message="Duplicate nodes.";
            elseif count==2&&obj.edge_indices(1)==obj.edge_indices(2)
                message="A two-node cycle cannot use the same edge twice.";
            elseif strict&&numel(unique(nodeKeys(obj.nodes)))~=count
                message="Nodes cannot be strictly ordered.";
            else,return,end
            error("KSSOLV:Matgenlab:ChemEnv:MultiGraphCycle", ...
                "MultiGraphCycle is not valid : %s",message);
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
            count=numel(obj.nodes);
            if count==1,obj.ordered=true;return,end
            if count==2
                [~,order_]=sort(nodeKeys(obj.nodes));obj.nodes=obj.nodes(order_);
                obj.edge_indices=sort(obj.edge_indices);obj.ordered=true;return
            end
            keys=nodeKeys(obj.nodes);[~,minimum]=min(keys);
            previous=mod(minimum-2,count)+1;next=mod(minimum,count)+1;
            if keys(previous)<keys(next)
                indices=[minimum:-1:1,count:-1:minimum+1];
                edgeStart=previous;
                edgeIndices=[edgeStart:-1:1,count:-1:edgeStart+1];
            else
                indices=[minimum:count,1:minimum-1];
                edgeIndices=indices;
            end
            obj.nodes=obj.nodes(indices);
            obj.edge_indices=obj.edge_indices(edgeIndices);obj.ordered=true;
        end
        function value=eq(obj,other)
            if ~isa(other,class(obj)),value=false;return,end
            if ~obj.ordered||~other.ordered
                error("KSSOLV:Matgenlab:ChemEnv:CycleOrder", ...
                    "Cycles must be ordered before comparison.");
            end
            value=isequal(obj.nodes,other.nodes)&& ...
                isequal(obj.edge_indices,other.edge_indices);
        end
        function value=ne(obj,other),value=~eq(obj,other);end
        function value=length(obj),value=numel(obj.nodes);end
        function value=asDict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv.utils.graph_utils", ...
                x_class="MultiGraphCycle",nodes=obj.nodes, ...
                edge_indices=obj.edge_indices,ordered=obj.ordered);
        end
        function value=as_dict(obj),value=obj.asDict();end
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
function value=nodeKeys(nodes)
if isnumeric(nodes),value=double(nodes);return,end
value=zeros(1,numel(nodes));
for index=1:numel(nodes)
    if isnumeric(nodes{index}),value(index)=nodes{index};
    else,value(index)=nodes{index}.isite;end
end
end
