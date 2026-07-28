classdef Topology < kssolv.analysis.matgenlab.util.MSONable
    properties
        sites
        ff_label=[]
        charges=[]
        velocities=[]
        topologies=[]
        type_by_sites
        species
    end
    methods
        function obj=Topology(sites,options)
            arguments
                sites
                options.ff_label=[]
                options.charges=[]
                options.velocities=[]
                options.topologies=[]
            end
            if iscell(sites), sites=kssolv.analysis.matgenlab.core.Molecule.from_sites(sites); end
            obj.sites=sites; obj.ff_label=options.ff_label;
            props=sites.site_properties;
            if ~isempty(options.ff_label)&&isfield(props,char(options.ff_label))
                obj.type_by_sites=string(props.(char(options.ff_label)));
            else
                obj.type_by_sites=strings(sites.num_sites,1);
                for k=1:sites.num_sites, obj.type_by_sites(k)=sites.sites{k}.specie.symbol; end
            end
            if isempty(options.charges)&&isfield(props,'charge'), options.charges=props.charge; end
            if isempty(options.velocities)&&isfield(props,'velocities'), options.velocities=props.velocities; end
            if ~isempty(options.charges)&&numel(options.charges)~=sites.num_sites
                error("KSSOLV:Matgenlab:Topology:Charges","Charges shape mismatch.");
            end
            if ~isempty(options.velocities)&&~isequal(size(options.velocities),[sites.num_sites,3])
                error("KSSOLV:Matgenlab:Topology:Velocities","Velocities shape mismatch.");
            end
            obj.charges=options.charges; obj.velocities=options.velocities;
            obj.topologies=options.topologies; obj.species=unique(obj.type_by_sites);
        end
        function d=asDict(obj)
            d=struct('sites',obj.sites.asDict(),'ff_label',obj.ff_label, ...
                'charges',obj.charges,'velocities',obj.velocities, ...
                'topologies',obj.topologies);
        end
    end
    methods (Static)
        function obj=from_bonding(molecule,bond,angle,dihedral,tol,varargin)
            if nargin<2, bond=true; end
            if nargin<3, angle=true; end
            if nargin<4, dihedral=true; end
            if nargin<5, tol=.1; end
            real=molecule.get_covalent_bonds(tol); bonds=zeros(numel(real),2);
            for k=1:numel(real)
                bonds(k,1)=find(vecnorm(molecule.cart_coords-real{k}.site1.coords,2,2)<1e-10,1)-1;
                bonds(k,2)=find(vecnorm(molecule.cart_coords-real{k}.site2.coords,2,2)<1e-10,1)-1;
            end
            tops=struct();
            if bond&&~isempty(bonds), tops.Bonds=bonds; end
            if bond&&angle
                a=zeros(0,3);
                for hub=0:molecule.num_sites-1
                    neigh=unique(bonds(any(bonds==hub,2),:)); neigh(neigh==hub)=[];
                    if numel(neigh)>=2
                        pairs=nchoosek(neigh,2); a=[a,[pairs(:,1),repmat(hub,size(pairs,1),1),pairs(:,2)]']; %#ok<AGROW>
                    end
                end
                a=reshape(a,3,[])'; if ~isempty(a), tops.Angles=a; end
            end
            if bond&&dihedral
                d=zeros(0,4);
                for k=1:size(bonds,1)
                    i=bonds(k,1); j=bonds(k,2);
                    ni=unique(bonds(any(bonds==i,2),:)); ni(ni==i|ni==j)=[];
                    nj=unique(bonds(any(bonds==j,2),:)); nj(nj==i|nj==j)=[];
                    for x=ni', for y=nj', if x~=y, d(end+1,:)=[x i j y]; end, end, end %#ok<AGROW>
                end
                if ~isempty(d), tops.Dihedrals=d; end
            end
            args=varargin;
            obj=kssolv.analysis.matgenlab.io.lammps.Topology(molecule,args{:},topologies=tops);
        end
    end
end
