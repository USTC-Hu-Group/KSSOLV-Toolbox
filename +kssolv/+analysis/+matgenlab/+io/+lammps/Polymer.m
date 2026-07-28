classdef Polymer
    properties
        start; end_index; monomer; n_units; link_distance; linear_chain
        moves; prev_move=1; molecule; length=1
    end
    methods
        function obj=Polymer(start_monomer,s_head,s_tail,monomer,head,tail,end_monomer,e_head,e_tail,n_units,link_distance,linear_chain)
            if nargin<11, link_distance=1; end
            if nargin<12, linear_chain=false; end
            obj.start=s_head+1; obj.end_index=s_tail+1; obj.monomer=monomer;
            obj.n_units=n_units; obj.link_distance=link_distance; obj.linear_chain=linear_chain;
            start_monomer=start_monomer.translate_sites(1:start_monomer.num_sites,-start_monomer.cart_coords(s_head+1,:));
            monomer=monomer.translate_sites(1:monomer.num_sites,-monomer.cart_coords(head+1,:));
            end_monomer=end_monomer.translate_sites(1:end_monomer.num_sites,-end_monomer.cart_coords(e_head+1,:));
            obj.moves=[1 0 0;0 1 0;0 0 1;-1 0 0;0 -1 0;0 0 -1];
            obj.molecule=start_monomer;
            monvec=monomer.cart_coords(tail+1,:)-monomer.cart_coords(head+1,:);
            while obj.length~=obj.n_units-1
                if linear_chain, dir=monvec/norm(monvec); else, [obj,dir]=obj.nextDirection(); end
                obj=obj.addMonomer(monomer,monvec,dir);
            end
            obj.n_units=obj.n_units+1;
            endvec=end_monomer.cart_coords(e_tail+1,:)-end_monomer.cart_coords(e_head+1,:);
            while obj.length~=obj.n_units-1
                if linear_chain, dir=endvec/norm(endvec); else, [obj,dir]=obj.nextDirection(); end
                obj=obj.addMonomer(end_monomer,endvec,dir);
            end
            obj.molecule=kssolv.analysis.matgenlab.core.Molecule.from_sites(obj.molecule.sites);
        end
    end
    methods (Access=private)
        function [obj,dir]=nextDirection(obj)
            move=randi(6); opposite=mod(obj.prev_move+2,6)+1;
            while move==opposite, move=randi(6); end
            obj.prev_move=move; dir=obj.moves(move,:);
        end
        function obj=addMonomer(obj,monomer,monvec,dir)
            mon=monomer; translation=obj.molecule.cart_coords(obj.end_index,:)+obj.link_distance*dir;
            mon=mon.translate_sites(1:mon.num_sites,translation);
            if ~obj.linear_chain
                u=monvec/norm(monvec); v=dir/norm(dir); axis=cross(u,v);
                if norm(axis)>1e-12
                    theta=acos(max(-1,min(1,dot(u,v))));
                    mon=mon.rotate_sites(1:mon.num_sites,theta,axis,mon.cart_coords(obj.start,:));
                elseif dot(u,v)<0
                    axis=null(u).'; mon=mon.rotate_sites(1:mon.num_sites,pi,axis(1,:),mon.cart_coords(obj.start,:));
                end
            end
            for k=1:mon.num_sites
                site=mon.sites{k}; obj.molecule=obj.molecule.append(site.specie,site.coords,properties=site.properties);
            end
            obj.length=obj.length+1; obj.end_index=obj.end_index+mon.num_sites;
        end
    end
end
