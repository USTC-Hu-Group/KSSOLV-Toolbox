classdef JmolNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        tol (1,1) double=.45
        min_bond_distance (1,1) double=.4
        el_radius
    end
    methods
        function obj=JmolNN(varargin)
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
            options=struct(tol=.45,min_bond_distance=.4,el_radius_updates=[]);
            options=parse(options,varargin);
            obj.tol=options.tol;obj.min_bond_distance=options.min_bond_distance;
            obj.el_radius=containers.Map("KeyType","char","ValueType","double");
            updates=options.el_radius_updates;
            if ~isempty(updates)
                if isstruct(updates),names=fieldnames(updates);
                    for ii=1:numel(names),obj.el_radius(names{ii})=updates.(names{ii});end
                elseif isa(updates,"containers.Map")
                    names=keys(updates);
                    for ii=1:numel(names),obj.el_radius(names{ii})=updates(names{ii});end
                end
            end
        end
        function value=get_max_bond_distance(obj,first,second)
            value=obj.radius(first)+obj.radius(second)+obj.tol;
        end
        function info=get_nn_info(obj,structure,n)
            center=structure(n);maxDistance=0;
            for element=structure.elements
                maxDistance=max(maxDistance,obj.get_max_bond_distance( ...
                    center.specie.symbol,element{1}.symbol));
            end
            neighbors=structure.get_neighbors(center,maxDistance+obj.tol);
            info={};minDistance=Inf;
            for element=structure.elements
                minDistance=min(minDistance,obj.get_max_bond_distance( ...
                    center.specie.symbol,element{1}.symbol));
            end
            for ii=1:numel(neighbors)
                neighbor=neighbors{ii};limit=obj.get_max_bond_distance( ...
                    center.specie.symbol,neighbor.specie.symbol);
                if neighbor.nn_distance<=limit&& ...
                        neighbor.nn_distance>obj.min_bond_distance
                    info{end+1}=obj.makeInfo(neighbor,minDistance/neighbor.nn_distance); %#ok<AGROW>
                end
            end
        end
    end
    methods (Access=private)
        function value=radius(obj,symbol)
            key=char(string(symbol));
            if isKey(obj.el_radius,key),value=obj.el_radius(key);return,end
            radii=jmolRadii();
            if isKey(radii,key),value=radii(key);return,end
            error("KSSOLV:Matgenlab:JmolNN:Radius", ...
                "No Jmol radius is available for element %s.",key);
        end
    end
end

function radii=jmolRadii()
persistent cached
if isempty(cached)
symbols=["Ac","Ag","Al","Am","Ar","As","At","Au","B","Ba","Be","Bh", ...
    "Bi","Bk","Br","C","Ca","Cd","Ce","Cf","Cl","Cm","Co","Cr","Cs", ...
    "Cu","Db","Dy","Er","Es","Eu","F","Fe","Fm","Fr","Ga","Gd","Ge", ...
    "H","He","Hf","Hg","Ho","Hs","I","In","Ir","K","Kr","La","Li", ...
    "Lr","Lu","Md","Mg","Mn","Mo","Mt","N","Na","Nb","Nd","Ne","Ni", ...
    "No","Np","O","Os","P","Pa","Pb","Pd","Pm","Po","Pr","Pt","Pu", ...
    "Ra","Rb","Re","Rf","Rh","Rn","Ru","S","Sb","Sc","Se","Sg","Si", ...
    "Sm","Sn","Sr","Ta","Tb","Tc","Te","Th","Ti","Tl","Tm","U","V", ...
    "W","Xe","Y","Yb","Zn","Zr"];
values=[1.88,1.59,1.35,1.51,1.57,1.21,1.7,1.5,.83,1.34,.35,1.6, ...
    1.54,1.5,1.21,.68,.99,1.69,1.83,1.5,.99,1.5,1.33,1.35,1.67, ...
    1.52,1.6,1.75,1.73,1.5,1.99,.64,1.34,1.5,2,1.22,1.79,1.17, ...
    .23,.93,1.57,1.7,1.74,1.6,1.4,1.63,1.32,1.33,1.91,1.87,.68, ...
    1.5,1.72,1.5,1.1,1.35,1.47,1.6,.68,.97,1.48,1.81,1.12,1.5, ...
    1.5,1.55,.68,1.37,.75,1.61,1.54,1.5,1.8,1.68,1.82,1.5,1.53, ...
    1.9,1.47,1.35,1.6,1.45,2.4,1.4,1.02,1.46,1.44,1.22,1.6,1.2, ...
    1.8,1.46,1.12,1.43,1.76,1.35,1.47,1.79,1.47,1.55,1.72,1.58, ...
    1.33,1.37,1.98,1.78,1.94,1.45,1.56];
cached=containers.Map(cellstr(symbols),num2cell(values));
end
radii=cached;
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
