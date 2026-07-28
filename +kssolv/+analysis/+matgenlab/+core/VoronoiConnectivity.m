classdef VoronoiConnectivity
    %VORONOICONNECTIVITY Periodic Voronoi-face solid-angle connectivity.
    properties
        structure
        cutoff (1,1) double = 10
        offsets (:,3) double
        cart_offsets (:,3) double
    end
    properties (Dependent)
        connectivity_array
        max_connectivity
    end
    methods
        function obj=VoronoiConnectivity(structure,cutoff)
            if nargin<2||isempty(cutoff),cutoff=10;end
            obj.structure=structure;obj.cutoff=cutoff;
            reciprocal=structure.lattice.reciprocal_lattice.lengths;
            vector=ceil(cutoff*reciprocal/(2*pi));
            obj.offsets=zeros(prod(2*vector+1),3);next=0;
            for z=-vector(3):vector(3)
                for y=-vector(2):vector(2)
                    for x=-vector(1):vector(1)
                        next=next+1;obj.offsets(next,:)=[x,y,z];
                    end
                end
            end
            obj.cart_offsets=structure.lattice. ...
                get_cartesian_coords(obj.offsets);
        end
        function connectivity=get.connectivity_array(obj)
            count=obj.structure.num_sites;
            connectivity=zeros(count,count,size(obj.offsets,1));
            strategy=kssolv.analysis.matgenlab.core.VoronoiNN( ...
                "cutoff",obj.cutoff,"allow_pathological",true);
            for first=1:count
                polyhedra=strategy.get_voronoi_polyhedra( ...
                    obj.structure,first);
                for facet=1:numel(polyhedra)
                    site=polyhedra{facet}.site;
                    image=reshape(double(site.image),1,3);
                    offset=find(all(obj.offsets==image,2),1);
                    if isempty(offset),continue,end
                    connectivity(first,site.index,offset)= ...
                        polyhedra{facet}.solid_angle;
                end
            end
        end
        function value=get.max_connectivity(obj)
            value=max(obj.connectivity_array,[],3);
        end
        function connections=get_connections(obj)
            maximum=obj.max_connectivity;
            connections=zeros(nnz(maximum),3);next=0;
            for first=1:size(maximum,1)
                for second=1:size(maximum,2)
                    if maximum(first,second)~=0
                        next=next+1;
                        connections(next,:)=[first,second, ...
                            obj.structure.get_distance(first,second)];
                    end
                end
            end
        end
        function site=get_sitej(obj,siteIndex,imageIndex)
            source=obj.structure(siteIndex);
            site=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                source.species,source.frac_coords+ ...
                obj.offsets(imageIndex,:),obj.structure.lattice);
        end
    end
end
