function graph=metal_edge_extender(graph,varargin)
%#ok<*ALIGN>
%METAL_EDGE_EXTENDER Add short metal-coordinator edges to a MoleculeGraph.
options=struct(cutoff=2.5,metals=["Li","Mg","Ca","Zn","B","Al"], ...
    coordinators=["O","N","F","S","Cl"]);options=parse(options,varargin);
if ~isobject(graph)||~ismethod(graph,"get_connected_sites")|| ...
        ~ismethod(graph,"add_edge")||~isprop(graph,"molecule")
    error("KSSOLV:Matgenlab:LocalEnv:GraphsUnavailable", ...
        "metal_edge_extender requires a MoleculeGraph-compatible object.");
end
autoDetect=isnumeric(options.metals)&&isempty(options.metals);
metals=string(options.metals);coordinators=string(options.coordinators);
if autoDetect
    metals=strings(1,0);
    for ii=1:graph.molecule.num_sites
        specie=graph.molecule(ii).specie;
        if specie.element.is_metal,metals(end+1)=specie.symbol;end %#ok<AGROW>
    end
end
for metal=1:graph.molecule.num_sites
    if ~any(graph.molecule(metal).specie.symbol==metals),continue,end
    connected=connectedIndices(graph.get_connected_sites(metal));
    found=false;
    for pass=0:1
        radius=options.cutoff+pass;
        for candidate=1:graph.molecule.num_sites
            if candidate==metal||any(connected==candidate)|| ...
                    ~any(graph.molecule(candidate).specie.symbol==coordinators)
                continue
            end
            if graph.molecule(metal).distance(graph.molecule(candidate))<radius
                graph=graph.add_edge(metal,candidate);found=true;
            end
        end
        if found,break,end
    end
end
end
function indices=connectedIndices(connected)
indices=zeros(1,numel(connected));
for ii=1:numel(connected),indices(ii)=connected{ii}.index;end
end
function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
