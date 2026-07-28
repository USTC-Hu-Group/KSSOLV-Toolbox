function dimensionality=get_dimensionality_gorai(structure,varargin)
%GET_DIMENSIONALITY_GORAI Classify bonded periodic rank as 1D, 2D or 3D.
options=struct("max_hkl",2,"el_radius_updates",[], ...
    "min_slab_size",5,"min_vacuum_size",5, ...
    "standardize",true,"bonds",[]);
options=parseOptions(options,varargin);
if options.standardize
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure);
    structure=analyzer.get_conventional_standard_structure();
end
if isempty(options.bonds)
    strategy=kssolv.analysis.matgenlab.core.JmolNN( ...
        "el_radius_updates",options.el_radius_updates);
    graph=strategy.get_bonded_structure(structure);
else
    graph=graphFromExplicitBonds(structure,options.bonds);
end
rankValue=kssolv.analysis.matgenlab.analysis. ...
    get_dimensionality_larsen(graph);
dimensionality=max(1,rankValue);
% Retain these upstream surface-construction parameters in the MATLAB API.
if options.max_hkl<1||options.min_slab_size<=0|| ...
        options.min_vacuum_size<0
    error("KSSOLV:Matgenlab:Dimensionality:GoraiOptions", ...
        "Gorai surface parameters must be positive.");
end
end

function graph=graphFromExplicitBonds(structure,bonds)
graph=kssolv.analysis.matgenlab.core.StructureGraph. ...
    from_empty_graph(structure);
translations=[ ...
    -1,-1,-1;-1,-1,0;-1,-1,1;-1,0,-1;-1,0,0;-1,0,1; ...
    -1,1,-1;-1,1,0;-1,1,1;0,-1,-1;0,-1,0;0,-1,1; ...
    0,0,-1;0,0,0;0,0,1;0,1,-1;0,1,0;0,1,1; ...
    1,-1,-1;1,-1,0;1,-1,1;1,0,-1;1,0,0;1,0,1; ...
    1,1,-1;1,1,0;1,1,1];
for first=1:structure.num_sites
    for second=first:structure.num_sites
        symbolFirst=structure(first).specie.symbol;
        symbolSecond=structure(second).specie.symbol;
        limit=lookupBond(bonds,symbolFirst,symbolSecond);
        if isempty(limit),continue,end
        for imageIndex=1:size(translations,1)
            image=translations(imageIndex,:);
            if first==second&&all(image==0),continue,end
            delta=structure(second).frac_coords+image- ...
                structure(first).frac_coords;
            distance=norm(delta*structure.lattice.matrix);
            if distance<=limit+1e-12
                graph.add_edge(first,second,"to_jimage",image, ...
                    "weight",distance);
            end
        end
    end
end
end

function value=lookupBond(bonds,first,second)
keysToTry=[string(first)+"|"+string(second), ...
    string(second)+"|"+string(first), ...
    string(first)+"-"+string(second), ...
    string(second)+"-"+string(first)];
value=[];
if isa(bonds,"containers.Map")
    for key=keysToTry
        if isKey(bonds,char(key)),value=bonds(char(key));return,end
    end
elseif iscell(bonds)&&size(bonds,2)>=3
    for index=1:size(bonds,1)
        pair=sort(string(bonds(index,1:2)));
        if isequal(pair,sort([string(first),string(second)]))
            value=double(bonds{index,3});return
        end
    end
elseif isstruct(bonds)
    for key=keysToTry
        field=matlab.lang.makeValidName(key);
        if isfield(bonds,field),value=bonds.(field);return,end
    end
end
end

function output=parseOptions(output,input)
names=fieldnames(output);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            any(strcmpi(string(input{index}),string(names)))
        match=find(strcmpi(string(input{index}),string(names)),1);
        output.(names{match})=input{index+1};index=index+2;
    else
        output.(names{position})=input{index};
        position=position+1;index=index+1;
    end
end
end
