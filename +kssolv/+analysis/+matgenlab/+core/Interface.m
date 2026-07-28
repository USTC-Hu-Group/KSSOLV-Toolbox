classdef Interface < kssolv.analysis.matgenlab.core.Structure
    %INTERFACE Joined film/substrate slabs with geometric controls.
    properties
        interface_properties (1,1) struct = struct()
    end
    properties (Access=private)
        inPlaneOffset_ (1,2) double = [0,0]
        gap_ (1,1) double = 0
        vacuumOverFilm_ (1,1) double = 0
    end
    properties (Dependent)
        in_plane_offset
        gap
        vacuum_over_film
        substrate_indices
        substrate_sites
        substrate
        film_indices
        film_sites
        film
        film_termination
        substrate_termination
        film_layers
        substrate_layers
    end
    methods
        function obj=Interface(lattice,species,coords,siteProperties,varargin)
            if ~isfield(siteProperties,"interface_label")
                error("KSSOLV:Matgenlab:Interface:Labels", ...
                    "Must provide labeling of substrate and film sites.");
            end
            options=struct("validate_proximity",false, ...
                "to_unit_cell",false,"coords_are_cartesian",false, ...
                "in_plane_offset",[0,0],"gap",0, ...
                "vacuum_over_film",0,"interface_properties",struct());
            options=parseOptions(options,varargin{:});
            obj@kssolv.analysis.matgenlab.core.Structure(lattice,species, ...
                coords,validate_proximity=options.validate_proximity, ...
                to_unit_cell=options.to_unit_cell, ...
                coords_are_cartesian=options.coords_are_cartesian, ...
                site_properties=siteProperties);
            obj.inPlaneOffset_=reshape(double(options.in_plane_offset),1,2);
            obj.gap_=double(options.gap);
            obj.vacuumOverFilm_=double(options.vacuum_over_film);
            obj.interface_properties=options.interface_properties;
            obj=obj.sort();
        end
        function value=get.in_plane_offset(obj),value=obj.inPlaneOffset_;end
        function obj=set.in_plane_offset(obj,value)
            value=reshape(double(value),1,[]);
            if numel(value)~=2
                error("KSSOLV:Matgenlab:Interface:Shift", ...
                    "In-plane shifts require two values.");
            end
            value=mod(value,1);delta=value-obj.inPlaneOffset_;
            obj.inPlaneOffset_=value;
            obj=obj.translate_sites(obj.film_indices,[delta,0], ...
                frac_coords=true,to_unit_cell=true);
        end
        function value=get.gap(obj),value=obj.gap_;end
        function obj=set.gap(obj,value)
            if value<0
                error("KSSOLV:Matgenlab:Interface:Gap", ...
                    "Interface gap cannot be negative.");
            end
            delta=value-obj.gap_;obj.gap_=value;
            obj=obj.updateC(obj.lattice.lengths(3)+delta);
            obj=obj.translate_sites(obj.film_indices,[0,0,delta], ...
                frac_coords=false,to_unit_cell=true);
        end
        function value=get.vacuum_over_film(obj),value=obj.vacuumOverFilm_;end
        function obj=set.vacuum_over_film(obj,value)
            if value<0
                error("KSSOLV:Matgenlab:Interface:Vacuum", ...
                    "Vacuum over film cannot be negative.");
            end
            delta=value-obj.vacuumOverFilm_;obj.vacuumOverFilm_=value;
            obj=obj.updateC(obj.lattice.lengths(3)+delta);
        end
        function value=get.substrate_indices(obj)
            labels=propertyStrings(obj.site_properties.interface_label);
            value=find(contains(labels,"substrate"));
        end
        function value=get.film_indices(obj)
            labels=propertyStrings(obj.site_properties.interface_label);
            value=find(contains(labels,"film"));
        end
        function value=get.substrate_sites(obj)
            value=obj.sites(obj.substrate_indices);
        end
        function value=get.film_sites(obj)
            value=obj.sites(obj.film_indices);
        end
        function value=get.substrate(obj)
            value=kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                obj.substrate_sites);
        end
        function value=get.film(obj)
            value=kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                obj.film_sites);
        end
        function value=get.film_termination(obj)
            value=kssolv.analysis.matgenlab.core.label_termination(obj.film);
        end
        function value=get.substrate_termination(obj)
            value=kssolv.analysis.matgenlab.core.label_termination( ...
                obj.substrate);
        end
        function value=get.film_layers(obj)
            filmStructure=obj.film;
            value=kssolv.analysis.matgenlab.core.count_layers( ...
                filmStructure,mostAbundantElement(filmStructure));
        end
        function value=get.substrate_layers(obj)
            substrateStructure=obj.substrate;
            value=kssolv.analysis.matgenlab.core.count_layers( ...
                substrateStructure,mostAbundantElement(substrateStructure));
        end
        function result=copy(obj)
            result=kssolv.analysis.matgenlab.core.Interface.from_dict( ...
                obj.as_dict());
        end
        function result=get_sorted_structure(obj,key,reverse)
            if nargin<2,key=[];end
            if nargin<3,reverse=false;end
            result=get_sorted_structure@ ...
                kssolv.analysis.matgenlab.core.IStructure(obj,key,reverse);
        end
        function shifts=get_shifts_based_on_adsorbate_sites(obj,tolerance)
            if nargin<2,tolerance=.1;end
            sub=adsorptionSites(obj.substrate);sub=sub(:,1:2);
            filmCoordinates=adsorptionSites(obj.film);
            filmCoordinates=filmCoordinates(:,1:2);
            shifts=zeros(size(sub,1)*size(filmCoordinates,1),2);position=0;
            for i=1:size(filmCoordinates,1)
                for j=1:size(sub,1)
                    position=position+1;
                    shifts(position,:)=sub(j,:)-filmCoordinates(i,:);
                end
            end
            base=[tolerance/obj.lattice.lengths(1), ...
                tolerance/obj.lattice.lengths(2)];
            shifts=round(shifts./base).*base;
            shifts=unique(shifts,"rows");
        end
        function value=as_dict(obj,varargin)
            value=as_dict@kssolv.analysis.matgenlab.core.IStructure( ...
                obj,varargin{:});
            value.x_module="pymatgen.core.interface";
            value.x_class="Interface";
            value.in_plane_offset=obj.in_plane_offset;value.gap=obj.gap;
            value.vacuum_over_film=obj.vacuum_over_film;
            value.interface_properties=obj.interface_properties;
        end
    end
    methods (Access=private)
        function obj=updateC(obj,newC)
            if newC<=0,error("KSSOLV:Matgenlab:Interface:C", ...
                    "New c length must be positive.");end
            cartesian=obj.cart_coords;matrix=obj.lattice.matrix;
            normal=cross(matrix(1,:),matrix(2,:));
            normal=normal/norm(normal);
            matrix(3,:)=normal*newC;
            obj.lattice=kssolv.analysis.matgenlab.core.Lattice(matrix);
            for index=1:obj.num_sites
                site=obj.sites_{index};site.lattice=obj.lattice;
                site.coords=cartesian(index,:);obj.sites_{index}=site;
            end
        end
    end
    methods (Static)
        function obj=from_dict(value)
            base=kssolv.analysis.matgenlab.core.Structure.from_dict(value);
            optional=struct("in_plane_offset",[0,0],"gap",0, ...
                "vacuum_over_film",0,"interface_properties",struct());
            names=fieldnames(optional);
            for index=1:numel(names)
                if isfield(value,names{index})
                    optional.(names{index})=value.(names{index});
                end
            end
            obj=kssolv.analysis.matgenlab.core.Interface(base.lattice, ...
                base.species_and_occu,base.frac_coords, ...
                base.site_properties,in_plane_offset=optional.in_plane_offset, ...
                gap=optional.gap,vacuum_over_film= ...
                optional.vacuum_over_film,interface_properties= ...
                optional.interface_properties);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.core.Interface.from_dict(value);
        end
        function obj=from_slabs(substrateSlab,filmSlab,varargin)
            options=struct("in_plane_offset",[0,0],"gap",1.6, ...
                "vacuum_over_film",0,"interface_properties",struct(), ...
                "center_slab",true);
            options=parseOptions(options,varargin{:});
            if isa(substrateSlab,"kssolv.analysis.matgenlab.core.Slab")
                substrateSlab=substrateSlab.get_orthogonal_c_slab();
            end
            if isa(filmSlab,"kssolv.analysis.matgenlab.core.Slab")
                filmSlab=filmSlab.get_orthogonal_c_slab();
            end
            if abs(filmSlab.lattice.angles(1)-90)>9|| ...
                    abs(filmSlab.lattice.angles(2)-90)>9
                error("KSSOLV:Matgenlab:Interface:FilmAngles", ...
                    "Film lattice alpha and beta must be approximately 90 degrees.");
            end
            if abs(substrateSlab.lattice.angles(1)-90)>9|| ...
                    abs(substrateSlab.lattice.angles(2)-90)>9
                error("KSSOLV:Matgenlab:Interface:SubstrateAngles", ...
                    "Substrate lattice alpha and beta must be approximately 90 degrees.");
            end
            substrateMatrix=substrateSlab.lattice.matrix;
            if dot(cross(substrateMatrix(1,:),substrateMatrix(2,:)), ...
                    substrateMatrix(3,:))<0
                substrateMatrix(3,:)=-substrateMatrix(3,:);
                substrateSlab.lattice= ...
                    kssolv.analysis.matgenlab.core.Lattice(substrateMatrix);
            end
            sub=substrateSlab.frac_coords;film=filmSlab.frac_coords;
            subHeight=(max(sub(:,3))-min(sub(:,3)))* ...
                substrateSlab.lattice.lengths(3);
            filmHeight=(max(film(:,3))-min(film(:,3)))* ...
                filmSlab.lattice.lengths(3);
            c=subHeight+filmHeight+options.gap+options.vacuum_over_film;
            lengths=substrateSlab.lattice.lengths;
            angles=substrateSlab.lattice.angles;
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(lengths(1),lengths(2),c, ...
                angles(1),angles(2),angles(3));
            sub(:,3)=(sub(:,3)-min(sub(:,3)))* ...
                substrateSlab.lattice.lengths(3)/c;
            film(:,3)=-film(:,3)*filmSlab.lattice.lengths(3)/c;
            film(:,3)=film(:,3)-min(film(:,3))+ ...
                max(sub(:,3))+options.gap/c;
            coordinates=[sub;film];
            coordinates(:,1:2)=coordinates(:,1:2)+ ...
                [zeros(size(sub,1),2);repmat(options.in_plane_offset, ...
                size(film,1),1)];
            if options.center_slab
                coordinates(:,3)=coordinates(:,3)+.5-mean(coordinates(:,3));
            end
            species=[substrateSlab.species_and_occu, ...
                filmSlab.species_and_occu];
            labels=[repmat({"substrate"},1,substrateSlab.num_sites), ...
                repmat({"film"},1,filmSlab.num_sites)];
            properties=struct("interface_label",{labels});
            both=intersect(fieldnames(substrateSlab.site_properties), ...
                fieldnames(filmSlab.site_properties));
            for index=1:numel(both)
                name=both{index};
                properties.(name)=[substrateSlab.site_properties.(name), ...
                    filmSlab.site_properties.(name)];
            end
            obj=kssolv.analysis.matgenlab.core.Interface(lattice,species, ...
                coordinates,properties,in_plane_offset= ...
                options.in_plane_offset,gap=options.gap, ...
                vacuum_over_film=options.vacuum_over_film, ...
                interface_properties=options.interface_properties);
        end
    end
end
function values=propertyStrings(input)
if ~iscell(input),values=string(input);return,end
values=strings(size(input));
for index=1:numel(input)
    item=input{index};
    while iscell(item)&&isscalar(item),item=item{1};end
    if isempty(item),values(index)=missing;
    else,values(index)=string(item);end
end
end
function symbol=mostAbundantElement(structure)
composition=structure.composition.element_composition;
[elements,amounts]=composition.items();
[~,selected]=max(amounts);symbol=elements{selected}.symbol;
end
function sites=adsorptionSites(structure)
normal=cross(structure.lattice.matrix(1,:),structure.lattice.matrix(2,:));
normal=normal/norm(normal);
cartesian=structure.cart_coords;
heights=cartesian*normal.';
surfaceIndices=find(heights>=max(heights)-.9);
[~,heightOrder]=sort(heights(surfaceIndices),"descend");
surfaceIndices=surfaceIndices(heightOrder);
surfaceFractional=zeros(0,3);surfaceCartesian=zeros(0,3);
for index=reshape(surfaceIndices,1,[])
    candidate=structure(index).frac_coords;
    if any(periodicDistances(surfaceFractional(:,1:2), ...
            candidate(1:2))<1e-8),continue,end
    surfaceFractional(end+1,:)=candidate; %#ok<AGROW>
    surfaceCartesian(end+1,:)=structure(index).coords; %#ok<AGROW>
end

mesh=zeros(25*size(surfaceCartesian,1),3);position=0;
for first=0:4
    for second=0:4
        translation=first*structure.lattice.matrix(1,:)+ ...
            second*structure.lattice.matrix(2,:);
        count=size(surfaceCartesian,1);
        mesh(position+(1:count),:)=surfaceCartesian+translation;
        position=position+count;
    end
end
mesh=mesh(1:position,:);
[basis1,basis2]=planeBasis(normal);
points=[mesh*basis1.',mesh*basis2.'];
[points,uniqueIndices]=unique(round(points,12),"rows","stable");
mesh=mesh(uniqueIndices,:);
triangles=delaunay(points(:,1),points(:,2));
bridge=zeros(0,3);hollow=zeros(0,3);
opposites=[2,3;1,3;1,2];
for triangleIndex=1:size(triangles,1)
    vertices=triangles(triangleIndex,:);
    dots=zeros(1,3);
    for corner=1:3
        vectors=mesh(vertices(opposites(corner,:)),:)- ...
            mesh(vertices(corner),:);
        vectors=vectors./vecnorm(vectors,2,2);
        dots(corner)=dot(vectors(1,:),vectors(2,:));
        bridge(end+1,:)=mean(mesh(vertices( ...
            opposites(corner,:)),:),1); %#ok<AGROW>
    end
    if all(dots>=1e-5)
        hollow(end+1,:)=mean(mesh(vertices,:),1); %#ok<AGROW>
    end
end
bridge=filterInterior(structure,bridge);
hollow=filterInterior(structure,hollow);
groups={surfaceCartesian,bridge,hollow};
sites=zeros(0,3);
for groupIndex=1:numel(groups)
    group=nearReduce(structure,groups{groupIndex},.01);
    group=mod(group/structure.lattice.matrix,1);
    group=symmetryReduce(structure,group,.01);
    sites=[sites;group]; %#ok<AGROW>
end
% Upstream chains the three position lists and the duplicate "all" list.
sites=[sites;sites];
end
function distances=periodicDistances(points,point)
if isempty(points),distances=Inf;return,end
delta=mod(points-point+.5,1)-.5;
distances=vecnorm(delta,2,2);
end
function [first,second]=planeBasis(normal)
reference=[1,0,0];
if abs(dot(reference,normal))>.9,reference=[0,1,0];end
first=cross(normal,reference);first=first/norm(first);
second=cross(normal,first);second=second/norm(second);
end
function values=filterInterior(structure,cartesian)
fractional=cartesian/structure.lattice.matrix;
keep=fractional(:,1)>1&fractional(:,1)<4& ...
    fractional(:,2)>1&fractional(:,2)<4;
values=cartesian(keep,:);
end
function values=nearReduce(structure,cartesian,tolerance)
fractional=cartesian/structure.lattice.matrix;keep=true(size(fractional,1),1);
accepted=zeros(0,3);
for index=1:size(fractional,1)
    delta=mod(accepted-fractional(index,:)+.5,1)-.5;
    distances=vecnorm(delta*structure.lattice.matrix,2,2);
    if any(distances<tolerance)
        keep(index)=false;
    else
        accepted(end+1,:)=fractional(index,:); %#ok<AGROW>
    end
end
values=cartesian(keep,:);
end
function values=symmetryReduce(structure,fractional,tolerance)
try
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure,.1);
    operations=analyzer.get_symmetry_operations();
catch
    operations={};
end
values=zeros(0,3);
for index=1:size(fractional,1)
    equivalent=any(periodicDistances(values,fractional(index,:))<tolerance);
    for operationIndex=1:numel(operations)
        if equivalent,break,end
        transformed=operations{operationIndex}.operate(fractional(index,:));
        equivalent=any(periodicDistances(values,transformed)<tolerance);
    end
    if ~equivalent
        values(end+1,:)=mod(fractional(index,:),1); %#ok<AGROW>
    end
end
end
function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end
