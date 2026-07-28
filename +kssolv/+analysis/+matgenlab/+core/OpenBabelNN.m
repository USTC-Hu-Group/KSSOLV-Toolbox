classdef OpenBabelNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    %OPENBABELNN Molecular bond perception without a Python runtime.
    %
    % The native implementation first perceives the covalent graph and then
    % assigns integral bond orders from element valence deficits. It preserves
    % OpenBabelNN's discrete-order contract without Open Babel bindings.
    properties
        order (1,1) logical = true
    end
    methods
        function obj=OpenBabelNN(varargin)
            options=struct(order=true);options=parse(options,varargin);
            obj.order=logical(options.order);
            obj.structures_allowed=false;obj.molecules_allowed=true;
            obj.extend_structure_molecules=false;
        end
        function info=get_nn_info(obj,molecule,n)
            if ~isa(molecule,"kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:OpenBabelNN:Molecule", ...
                    "OpenBabelNN is only appropriate for molecules.");
            end
            if n<1||n>molecule.num_sites
                error("KSSOLV:Matgenlab:OpenBabelNN:Index", ...
                    "Site index is out of bounds.");
            end
            bonds=molecule.get_covalent_bonds(.2);
            pairs=zeros(numel(bonds),2);lengths=zeros(1,numel(bonds));
            preferences=zeros(1,numel(bonds));
            for ii=1:numel(bonds)
                pairs(ii,1)=siteIndex(molecule,bonds{ii}.site1);
                pairs(ii,2)=siteIndex(molecule,bonds{ii}.site2);
                lengths(ii)=bonds{ii}.length;
                preferences(ii)=bonds{ii}.get_bond_order();
            end
            orders=perceiveOrders(molecule,pairs,preferences);
            info=cell(1,sum(any(pairs==n,2)));position=0;
            for ii=1:size(pairs,1)
                if pairs(ii,1)==n,neighbor=pairs(ii,2);
                elseif pairs(ii,2)==n,neighbor=pairs(ii,1);
                else,continue,end
                weight=lengths(ii);
                if obj.order,weight=orders(ii);end
                position=position+1;
                info{position}=struct(site=molecule(neighbor),image=[0,0,0], ...
                    weight=weight,site_index=neighbor);
            end
        end
        function graph=get_bonded_structure(obj,molecule,varargin)
            options=struct(decorate=false);options=parse(options,varargin);
            graph=get_bonded_structure@kssolv.analysis.matgenlab.core. ...
                NearNeighbors(obj,molecule,"decorate",options.decorate);
        end
        function info=get_nn_shell_info(obj,molecule,siteIdx,shell)
            info=get_nn_shell_info@kssolv.analysis.matgenlab.core. ...
                NearNeighbors(obj,molecule,siteIdx,shell);
        end
    end
end

function index=siteIndex(molecule,site)
index=find(cellfun(@(candidate) ...
    candidate.species_string==site.species_string&& ...
    norm(candidate.coords-site.coords)<1e-10,molecule.sites),1);
if isempty(index)
    error("KSSOLV:Matgenlab:OpenBabelNN:Site", ...
        "Perceived bond site is absent from the molecule.");
end
end

function orders=perceiveOrders(molecule,pairs,preferences)
orders=ones(1,size(pairs,1));degree=zeros(1,molecule.num_sites);
for ii=1:size(pairs,1)
    degree(pairs(ii,1))=degree(pairs(ii,1))+1;
    degree(pairs(ii,2))=degree(pairs(ii,2))+1;
end
targets=arrayfun(@(ii)targetValence(molecule(ii).specie.symbol), ...
    1:molecule.num_sites);
deficit=max(targets-degree,0);
[~,sequence]=sort(preferences,"descend");
changed=true;
while changed
    changed=false;
    for ii=sequence
        first=pairs(ii,1);second=pairs(ii,2);
        if orders(ii)<3&&deficit(first)>0&&deficit(second)>0
            orders(ii)=orders(ii)+1;
            deficit([first,second])=deficit([first,second])-1;
            changed=true;
        end
    end
end
end

function value=targetValence(symbol)
switch string(symbol)
    case {"H","F","Cl","Br","I"},value=1;
    case {"B","Al","N","P"},value=3;
    case {"C","Si"},value=4;
    case {"O","S","Se"},value=2;
    otherwise,value=0;
end
end

function output=parse(output,input)
if isempty(input),return,end
if isscalar(input) && ~(ischar(input{1})||isstring(input{1}))
    output.order=input{1};return
end
for ii=1:2:numel(input),output.(char(string(input{ii})))=input{ii+1};end
end
