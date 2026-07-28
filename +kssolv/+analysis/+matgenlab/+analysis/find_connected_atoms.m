function connectedMatrix=find_connected_atoms(structure,tolerance,ldict)
%FIND_CONNECTED_ATOMS Build Cheon's periodic covalent-radius adjacency.
if nargin<2||isempty(tolerance),tolerance=.45;end
if nargin<3,ldict=[];end
count=structure.num_sites;
connectedMatrix=zeros(count);
strategy=kssolv.analysis.matgenlab.core.JmolNN("tol",tolerance);
fractional=structure.frac_coords;
translations=[ ...
    -1,-1,-1;-1,-1,0;-1,-1,1;-1,0,-1;-1,0,0;-1,0,1; ...
    -1,1,-1;-1,1,0;-1,1,1;0,-1,-1;0,-1,0;0,-1,1; ...
    0,0,-1;0,0,0;0,0,1;0,1,-1;0,1,0;0,1,1; ...
    1,-1,-1;1,-1,0;1,-1,1;1,0,-1;1,0,0;1,0,1; ...
    1,1,-1;1,1,0;1,1,1];
for first=1:count
    firstSymbol=structure(first).specie.symbol;
    for second=first+1:count
        secondSymbol=structure(second).specie.symbol;
        limit=bondLimit(firstSymbol,secondSymbol,ldict,strategy,tolerance);
        differences=fractional(second,:)-fractional(first,:)-translations;
        cartesian=differences*structure.lattice.matrix;
        if any(vecnorm(cartesian,2,2)<limit)
            connectedMatrix(first,second)=1;
            connectedMatrix(second,first)=1;
        end
    end
end
end

function limit=bondLimit(first,second,ldict,strategy,tolerance)
if isempty(ldict)
    limit=strategy.get_max_bond_distance(first,second);return
end
firstRadius=radiusValue(ldict,first);
secondRadius=radiusValue(ldict,second);
limit=firstRadius+secondRadius+tolerance;
end

function value=radiusValue(dictionary,symbol)
key=char(string(symbol));
if isa(dictionary,"containers.Map")
    if isKey(dictionary,key),value=dictionary(key);return,end
elseif isstruct(dictionary)
    field=matlab.lang.makeValidName(key);
    if isfield(dictionary,field),value=dictionary.(field);return,end
end
error("KSSOLV:Matgenlab:Dimensionality:Radius", ...
    "No radius is available for element %s.",key);
end
