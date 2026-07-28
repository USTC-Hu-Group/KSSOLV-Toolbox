function value=get_delta(first,second,edge)
%GET_DELTA Directed periodic-image delta for an undirected edge.
start=fieldValue(edge,"start");finish=fieldValue(edge,"end");
delta=reshape(double(fieldValue(edge,"delta")),1,[]);
if first.isite==start&&second.isite==finish,value=delta;
elseif second.isite==start&&first.isite==finish,value=-delta;
else
    error("KSSOLV:Matgenlab:ChemEnv:Delta", ...
        "The supplied edge does not link the two nodes.");
end
end
function value=fieldValue(input,name)
if isa(input,"containers.Map"),value=input(char(name));
else,value=input.(char(name));end
end
