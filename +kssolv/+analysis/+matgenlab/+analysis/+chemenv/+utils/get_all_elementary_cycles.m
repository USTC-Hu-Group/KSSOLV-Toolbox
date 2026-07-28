%#ok<*ISCL>
function value=get_all_elementary_cycles(input)
%GET_ALL_ELEMENTARY_CYCLES Generate elementary cycles from a cycle basis.
if isa(input,"kssolv.analysis.matgenlab.core.GraphStore")
    endpoints=[[input.edges.from_index].',[input.edges.to_index].'];
    graph_=graph(endpoints(:,1),endpoints(:,2),[],input.number_of_nodes());
elseif isa(input,"graph"),graph_=input;
else
    error("KSSOLV:Matgenlab:ChemEnv:Graph", ...
        "graph must be a MATLAB graph or GraphStore.");
end
basis=cyclebasis(graph_);
if isempty(basis),value={};return,end
if numel(basis)==1
    value={kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        SimpleGraphCycle(basis{1})};return
end
endpoints=graph_.Edges.EndNodes;incidence=false(numel(basis),numedges(graph_));
for cycle=1:numel(basis)
    nodes=basis{cycle};
    for index=1:numel(nodes)
        first=nodes(index);second=nodes(mod(index,numel(nodes))+1);
        edge=findedge(graph_,first,second);incidence(cycle,edge(1))=true;
    end
end
value={};
for count=1:numel(basis)
    selections=nchoosek(1:numel(basis),count);
    for row=1:size(selections,1)
        mask=mod(sum(incidence(selections(row,:),:),1),2)==1;
        edges=endpoints(mask,:);
        try
            cycle=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                SimpleGraphCycle.from_edges(edges,false);
            if ~any(cellfun(@(existing)existing==cycle,value))
                value{end+1}=cycle; %#ok<AGROW>
            end
        catch exception
            if ~startsWith(exception.identifier, ...
                    "KSSOLV:Matgenlab:ChemEnv:SimpleGraphCycle")
                rethrow(exception)
            end
        end
    end
end
end
