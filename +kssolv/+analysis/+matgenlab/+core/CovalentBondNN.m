classdef CovalentBondNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    %COVALENTBONDNN Molecular neighbors from built-in covalent-bond data.
    properties
        tol (1,1) double = 0.2
        order (1,1) logical = true
        bonds cell = {}
    end
    methods
        function obj=CovalentBondNN(varargin)
            obj.structures_allowed=false;obj.molecules_allowed=true;
            obj.extend_structure_molecules=false;
            options=struct(tol=.2,order=true);options=parse(options,varargin);
            obj.tol=options.tol;obj.order=options.order;
        end
        function info=get_nn_info(obj,molecule,n)
            if ~obj.molecules_allowed || ~isa(molecule, ...
                    "kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:CovalentBondNN:Molecule", ...
                    "CovalentBondNN is only appropriate for molecules.");
            end
            if n<1||n>molecule.num_sites
                error("KSSOLV:Matgenlab:CovalentBondNN:Index", ...
                    "Site index is out of bounds.");
            end
            obj.bonds=molecule.get_covalent_bonds(obj.tol);info={};
            center=molecule(n);
            for ii=1:numel(obj.bonds)
                bond=obj.bonds{ii};site=[];
                if sameSite(bond.site1,center),site=bond.site2;
                elseif sameSite(bond.site2,center),site=bond.site1;end
                if isempty(site),continue,end
                index=find(cellfun(@(candidate)sameSite(candidate,site), ...
                    molecule.sites),1);
                if obj.order,weight=bond.get_bond_order();
                else,weight=bond.length;end
                info{end+1}=struct(site=site,image=[0,0,0], ...
                    weight=weight,site_index=index); %#ok<AGROW>
            end
        end
    end
end
function tf=sameSite(first,second)
tf=first.species_string==second.species_string && ...
    norm(first.coords-second.coords)<1e-12;
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
