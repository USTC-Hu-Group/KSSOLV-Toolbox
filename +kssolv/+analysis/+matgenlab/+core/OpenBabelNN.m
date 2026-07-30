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
            [pairs,lengths,orders]=obj.get_bonds(molecule);
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
            if ~isa(molecule,"kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:OpenBabelNN:Molecule", ...
                    "OpenBabelNN is only appropriate for molecules.");
            end
            [pairs,lengths,orders]=obj.get_bonds(molecule);
            graph=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_empty_graph(molecule,"edge_weight_name","weight", ...
                "edge_weight_units","");
            for ii=1:size(pairs,1)
                weight=lengths(ii);
                if obj.order,weight=orders(ii);end
                properties=struct("origin","OpenBabelNN", ...
                    "bond_order",orders(ii),"distance",lengths(ii));
                graph.add_edge(pairs(ii,1),pairs(ii,2), ...
                    "weight",weight,"edge_properties",properties);
            end
            if options.decorate
                local=cell(1,molecule.num_sites);
                for ii=1:molecule.num_sites
                    local{ii}=obj.get_local_order_parameters(molecule,ii);
                end
                graph.molecule=graph.molecule.add_site_property( ...
                    "order_parameters",local);
                graph.set_node_attributes();
            end
        end
        function [pairs,lengths,orders]=get_bonds(~,molecule)
            %GET_BONDS Perceive molecular pairs without materializing a graph.
            if ~isa(molecule,"kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:OpenBabelNN:Molecule", ...
                    "OpenBabelNN is only appropriate for molecules.");
            end
            [pairs,lengths,orders]=perceiveMolecule(molecule);
        end
        function info=get_nn_shell_info(obj,molecule,siteIdx,shell)
            info=get_nn_shell_info@kssolv.analysis.matgenlab.core. ...
                NearNeighbors(obj,molecule,siteIdx,shell);
        end
    end
end

function [pairs,lengths,orders]=perceiveMolecule(molecule)
pairs=molecule.get_covalent_bond_pairs(.2);
lengths=zeros(1,size(pairs,1));
preferences=zeros(1,size(pairs,1));
for ii=1:size(pairs,1)
    bond=kssolv.analysis.matgenlab.core.CovalentBond( ...
        molecule(pairs(ii,1)),molecule(pairs(ii,2)));
    lengths(ii)=bond.length;
    preferences(ii)=bond.get_bond_order();
end
orders=perceiveOrders(molecule,pairs,preferences);
end

function orders=perceiveOrders(molecule,pairs,preferences)
orders=ones(1,size(pairs,1));
if isempty(pairs)
    return
end
degree=zeros(1,molecule.num_sites);
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
