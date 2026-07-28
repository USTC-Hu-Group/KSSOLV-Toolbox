classdef SlabGenerator
    %SLABGENERATOR Generate surface slabs for a specified Miller plane.
    properties
        oriented_unit_cell
        parent
        lll_reduce (1,1) logical
        center_slab (1,1) logical
        slab_scale_factor
        miller_index
        min_vac_size (1,1) double
        min_slab_size (1,1) double
        in_unit_planes (1,1) logical
        primitive (1,1) logical
        max_normal_search
        reorient_lattice (1,1) logical
    end
    properties (SetAccess=private)
        normal_
        proj_height_
    end
    methods
        function obj=SlabGenerator(initialStructure,millerIndex, ...
                minSlabSize,minVacuumSize,varargin)
            options=struct("lll_reduce",false,"center_slab",false, ...
                "in_unit_planes",false,"primitive",true, ...
                "max_normal_search",[],"reorient_lattice",true);
            options=parseOptions(options,varargin{:});
            properties=initialStructure.site_properties;
            if ~isfield(properties,"bulk_wyckoff")|| ...
                    ~isfield(properties,"bulk_equivalent")
                dataset=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(initialStructure). ...
                    get_symmetry_dataset();
                initialStructure=initialStructure.add_site_property( ...
                    "bulk_wyckoff",cellstr(dataset.wyckoffs));
                initialStructure=initialStructure.add_site_property( ...
                    "bulk_equivalent",dataset.equivalent_atoms);
            end
            hkl=reduceVector(millerIndex);
            [scale,normal]=scalingFactor(initialStructure.lattice, ...
                hkl,options.max_normal_search);
            oriented=initialStructure*scale;
            obj.oriented_unit_cell=kssolv.analysis.matgenlab.core. ...
                Structure(oriented.lattice,oriented.species_and_occu, ...
                mod(oriented.frac_coords,1), ...
                site_properties=oriented.site_properties);
            obj.parent=initialStructure;obj.miller_index=hkl;
            obj.slab_scale_factor=scale;
            obj.min_slab_size=minSlabSize;obj.min_vac_size=minVacuumSize;
            obj.lll_reduce=logical(options.lll_reduce);
            obj.center_slab=logical(options.center_slab);
            obj.in_unit_planes=logical(options.in_unit_planes);
            obj.primitive=logical(options.primitive);
            obj.max_normal_search=options.max_normal_search;
            obj.reorient_lattice=logical(options.reorient_lattice);
            obj.normal_=normal;
            obj.proj_height_=abs(dot(normal, ...
                obj.oriented_unit_cell.lattice.matrix(3,:)));
        end
        function slab=get_slab(obj,shift,tol,energy)
            if nargin<2||isempty(shift),shift=0;end
            if nargin<3||isempty(tol),tol=.1;end
            if nargin<4,energy=[];end
            height=obj.proj_height_;
            spacing=obj.parent.lattice.d_hkl(obj.miller_index);
            heightPerLayer=round(height/spacing,8);
            if obj.in_unit_planes
                slabLayers=max(1,ceil(obj.min_slab_size/heightPerLayer));
                vacuumLayers=max(0,ceil(obj.min_vac_size/heightPerLayer));
            else
                slabLayers=max(1,ceil(obj.min_slab_size/height));
                vacuumLayers=max(0,ceil(obj.min_vac_size/height));
            end
            totalLayers=slabLayers+vacuumLayers;
            matrix=obj.oriented_unit_cell.lattice.matrix;
            matrix(3,:)=matrix(3,:)*totalLayers;
            base=mod(obj.oriented_unit_cell.frac_coords-[0,0,shift],1);
            base(:,3)=base(:,3)/totalLayers;
            coordinates=zeros(obj.oriented_unit_cell.num_sites*slabLayers,3);
            species=cell(1,size(coordinates,1));
            baseSpecies=obj.oriented_unit_cell.species_and_occu;
            for layer=0:slabLayers-1
                range=layer*obj.oriented_unit_cell.num_sites+ ...
                    (1:obj.oriented_unit_cell.num_sites);
                coordinates(range,:)=base;
                coordinates(range,3)=coordinates(range,3)+layer/totalLayers;
                species(range)=baseSpecies;
            end
            properties=repeatProperties( ...
                obj.oriented_unit_cell.site_properties,slabLayers);
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix), ...
                species,coordinates,site_properties=properties);
            oriented=obj.oriented_unit_cell;
            if obj.center_slab
                structure=kssolv.analysis.matgenlab.core.center_slab(structure);
            end
            if obj.primitive
                originalVolume=structure.volume;
                structure=obj.reduceSurfaceCell( ...
                    structure,matrix,obj.normal_,tol);
                reducedOriented=obj.reduceSurfaceCell(oriented, ...
                    oriented.lattice.matrix,obj.normal_,tol);
                reducedOriented=obj.reduceNormalPeriod( ...
                    reducedOriented,tol);
                if abs(structure.lattice.a-reducedOriented.lattice.a)<tol && ...
                        abs(structure.lattice.b-reducedOriented.lattice.b)<tol
                    oriented=reducedOriented;
                end
                if ~isempty(energy)
                    energy=energy*structure.volume/originalVolume;
                end
            end
            if obj.lll_reduce
                structure=structure.get_reduced_structure("LLL");
            end
            slab=kssolv.analysis.matgenlab.core.Slab( ...
                structure.lattice,structure.species_and_occu, ...
                structure.frac_coords,obj.miller_index, ...
                oriented,shift,obj.slab_scale_factor, ...
                reorient_lattice=obj.reorient_lattice, ...
                site_properties=structure.site_properties,energy=energy);
        end
        function slabs=get_slabs(obj,varargin)
            options=struct("bonds",[],"ftol",.1,"tol",.1, ...
                "max_broken_bonds",0,"symmetrize",false, ...
                "repair",false,"ztol",0,"filter_out_sym_slabs",true);
            options=parseOptions(options,varargin{:});
            shifts=terminationShifts( ...
                obj.oriented_unit_cell.frac_coords(:,3), ...
                obj.proj_height_,options.ftol);
            bondDefinitions=normalizeBonds(options.bonds);
            ranges=bondRanges(obj.oriented_unit_cell, ...
                bondDefinitions,options.ztol);
            slabs=cell(1,0);
            for index=1:numel(shifts)
                broken=sum(ranges(:,1)<=shifts(index)& ...
                    shifts(index)<=ranges(:,2));
                slab=obj.get_slab(shifts(index),options.tol,broken);
                if broken<=options.max_broken_bonds
                    slabs{end+1}=slab; %#ok<AGROW>
                elseif options.repair&&~isempty(bondDefinitions)
                    slabs{end+1}=obj.repair_broken_bonds( ...
                        slab,bondDefinitions); %#ok<AGROW>
                end
            end
            if options.filter_out_sym_slabs&&~isempty(slabs)
                invariantTolerance=max(options.tol*1e-3,1e-8);
                grouped=kssolv.analysis.matgenlab.core. ...
                    group_surface_structures(slabs,invariantTolerance);
                uniqueSlabs=cellfun(@(group)group{1},grouped, ...
                    "UniformOutput",false);
                if options.symmetrize
                    output={};
                    for index=1:numel(uniqueSlabs)
                        output=[output, ...
                            obj.nonstoichiometric_symmetrized_slab( ...
                            uniqueSlabs{index})]; %#ok<AGROW>
                    end
                    if ~isempty(output)
                        grouped=kssolv.analysis.matgenlab.core. ...
                            group_surface_structures( ...
                            output,invariantTolerance);
                        slabs=cellfun(@(group)group{1},grouped, ...
                            "UniformOutput",false);
                    else
                        slabs={};
                    end
                else
                    slabs=uniqueSlabs;
                end
            elseif options.symmetrize
                output={};
                for index=1:numel(slabs)
                    output=[output, ...
                        obj.nonstoichiometric_symmetrized_slab( ...
                        slabs{index})]; %#ok<AGROW>
                end
                slabs=output;
            end
            if ~isempty(slabs)
                [~,order]=sort(cellfun(@(slab)slab.energy,slabs));
                slabs=slabs(order);
            end
        end
        function slab=repair_broken_bonds(obj,slab,bonds)
            definitions=normalizeBonds(bonds);
            for pair=1:numel(definitions)
                first=definitions(pair).species1;
                second=definitions(pair).species2;
                distance=definitions(pair).distance;
                firstCn=referenceCoordination( ...
                    obj.oriented_unit_cell,first,second,distance);
                secondCn=referenceCoordination( ...
                    obj.oriented_unit_cell,second,first,distance);
                if max(firstCn)>max(secondCn)
                    reference=first;other=second;allowed=firstCn;
                else
                    reference=second;other=first;allowed=secondCn;
                end
                index=1;
                while index<=slab.num_sites
                    if speciesMatches(slab.sites{index},reference)
                        neighbors=slab.get_neighbors( ...
                            slab.sites{index},distance);
                        coordination=sum(cellfun(@(item) ...
                            speciesMatches(item,other),neighbors));
                        if ~any(allowed==coordination)
                            slab=obj.move_to_other_side(slab,index);
                            neighbors=slab.get_neighbors( ...
                                slab.sites{index},distance);
                            move=cellfun(@(item)item.index, ...
                                neighbors(cellfun(@(item) ...
                                speciesMatches(item,other),neighbors)));
                            slab=obj.move_to_other_side( ...
                                slab,unique([move,index]));
                        end
                    end
                    index=index+1;
                end
            end
        end
        function slab=move_to_other_side(obj,slab,indices)
            height=obj.proj_height_;
            if obj.in_unit_planes
                height=height/obj.parent.lattice.d_hkl(obj.miller_index);
            end
            slabLayers=ceil(obj.min_slab_size/height);
            vacuumLayers=ceil(obj.min_vac_size/height);
            fraction=slabLayers/(slabLayers+vacuumLayers);
            coordinates=slab.frac_coords;center=slab.center_of_mass(3);
            indices=reshape(indices,1,[]);
            top=indices(coordinates(indices,3)>=center);
            bottom=setdiff(indices,top,"stable");
            coordinates(top,3)=coordinates(top,3)-fraction;
            coordinates(bottom,3)=coordinates(bottom,3)+fraction;
            slab=kssolv.analysis.matgenlab.core.Slab(slab.lattice, ...
                slab.species_and_occu,coordinates,slab.miller_index, ...
                slab.oriented_unit_cell,slab.shift,slab.scale_factor, ...
                reorient_lattice=slab.reorient_lattice, ...
                site_properties=slab.site_properties,energy=slab.energy);
        end
        function slabs=nonstoichiometric_symmetrized_slab(obj,slab,varargin)
            if slab.is_symmetric(),slabs={slab};return,end
            slabs={};
            for surface=["top","bottom"]
                trial=slab.copy();trial.energy=slab.energy;
                while ~trial.is_symmetric()
                    z=trial.frac_coords(:,3);
                    if surface=="top",[~,remove]=max(z);
                    else,[~,remove]=min(z);end
                    trial=trial.remove_sites(remove);
                    if trial.num_sites<=obj.parent.num_sites
                        warning("KSSOLV:Matgenlab:Surface:Symmetrize", ...
                            "Too many sites removed; use a larger slab.");
                        break
                    end
                end
                if trial.is_symmetric(),slabs{end+1}=trial;end %#ok<AGROW>
            end
        end
    end
    methods (Access=private)
        function reduced=reduceSurfaceCell(obj,structure,slabMatrix,normal,tolerance)
            candidates=[slabMatrix(1,:),norm(slabMatrix(1,:)); ...
                slabMatrix(2,:),norm(slabMatrix(2,:))];
            fractional=structure.frac_coords;
            for first=1:structure.num_sites-1
                for second=first+1:structure.num_sites
                    if ~structure(first).species.almost_equals( ...
                            structure(second).species),continue,end
                    delta=fractional(second,:)-fractional(first,:);
                    delta=delta-round(delta);vector=delta*slabMatrix;
                    if norm(vector)>tolerance&& ...
                            abs(dot(vector,normal))<tolerance&& ...
                            obj.isTranslation(structure,delta,tolerance)
                        candidates(end+1,:)=[vector,norm(vector)]; %#ok<AGROW>
                    end
                end
            end
            [~,order]=sort(candidates(:,4));candidates=candidates(order,:);
            firstVector=candidates(1,1:3);secondVector=[];
            for index=2:size(candidates,1)
                if norm(cross(firstVector,candidates(index,1:3)))>tolerance
                    secondVector=candidates(index,1:3);break
                end
            end
            if isempty(secondVector),reduced=structure;return,end
            matrix=[firstVector;secondVector;slabMatrix(3,:)];
            if dot(matrix(1,:),matrix(2,:))<0
                matrix(2,:)=-matrix(2,:);
            end
            if abs(det(matrix))>=abs(det(slabMatrix))-1e-8
                reduced=structure;return
            end
            if dot(matrix(1,:),matrix(3,:))>0,matrix(1,:)=-matrix(1,:);end
            if dot(matrix(2,:),matrix(3,:))>0,matrix(2,:)=-matrix(2,:);end
            transformed=mod(structure.cart_coords/matrix,1);
            keep=true(1,structure.num_sites);
            for index=1:structure.num_sites
                if ~keep(index),continue,end
                for later=index+1:structure.num_sites
                    if ~keep(later)||~structure.sites{index}.species. ...
                            almost_equals(structure.sites{later}.species)
                        continue
                    end
                    delta=transformed(index,:)-transformed(later,:);
                    delta=delta-round(delta);
                    if norm(delta*matrix)<tolerance,keep(later)=false;end
                end
            end
            properties=structure.site_properties;names=fieldnames(properties);
            for index=1:numel(names)
                values=properties.(names{index});
                if iscell(values),properties.(names{index})=values(keep); %#ok<ALIGN>
                elseif size(values,1)==structure.num_sites
                    properties.(names{index})=values(keep,:);
                else,properties.(names{index})=values(:,keep);end
            end
            species=structure.species_and_occu;
            reduced=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix), ...
                species(keep),transformed(keep,:), ...
                site_properties=properties);
        end
        function reduced=reduceNormalPeriod(obj,structure,tolerance)
            period=1;
            for divisor=structure.num_sites:-1:2
                candidate=1/divisor;
                if obj.isTranslation( ...
                        structure,[0,0,candidate],tolerance)
                    period=candidate;
                    break
                end
            end
            if period==1,reduced=structure;return,end
            matrix=structure.lattice.matrix;
            matrix(3,:)=matrix(3,:)*period;
            transformed=structure.frac_coords;
            transformed(:,3)=mod(transformed(:,3)/period,1);
            keep=true(1,structure.num_sites);
            for index=1:structure.num_sites
                if ~keep(index),continue,end
                for later=index+1:structure.num_sites
                    if ~keep(later)||~structure.sites{index}.species. ...
                            almost_equals(structure.sites{later}.species)
                        continue
                    end
                    delta=transformed(index,:)-transformed(later,:);
                    delta=delta-round(delta);
                    if norm(delta*matrix)<tolerance
                        keep(later)=false;
                    end
                end
            end
            properties=structure.site_properties;
            names=fieldnames(properties);
            for index=1:numel(names)
                values=properties.(names{index});
                if iscell(values)
                    properties.(names{index})=values(keep);
                elseif size(values,1)==structure.num_sites
                    properties.(names{index})=values(keep,:);
                else
                    properties.(names{index})=values(:,keep);
                end
            end
            species=structure.species_and_occu;
            reduced=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix), ...
                species(keep),transformed(keep,:), ...
                site_properties=properties);
        end
        function value=isTranslation(~,structure,delta,tolerance)
            fractional=structure.frac_coords;value=true;
            for index=1:structure.num_sites
                target=mod(fractional(index,:)+delta,1);found=false;
                for candidate=1:structure.num_sites
                    if ~structure.sites{index}.species.almost_equals( ...
                            structure.sites{candidate}.species),continue,end
                    difference=target-fractional(candidate,:);
                    difference=difference-round(difference);
                    if norm(difference*structure.lattice.matrix)<tolerance
                        found=true;break
                    end
                end
                if ~found,value=false;return,end
            end
        end
    end
end

function vector=reduceVector(vector)
vector=reshape(round(double(vector)),1,3);
divisor=gcd(gcd(abs(vector(1)),abs(vector(2))),abs(vector(3)));
if divisor==0
    error("KSSOLV:Matgenlab:Surface:Miller","Miller index cannot be zero.");
end
vector=vector/divisor;
end
function [scale,normal]=scalingFactor(lattice,hkl,maxSearch)
matrix=lattice.matrix;normal=hkl/matrix;normal=normal/norm(normal);
basis=eye(3);inPlane={};nonOrth=[];
for index=1:3
    if hkl(index)==0,inPlane{end+1}=basis(index,:); %#ok<AGROW>
    else
        nonOrth(end+1,:)=[index,abs(dot(normal,matrix(index,:)))/ ...
            norm(matrix(index,:))]; %#ok<AGROW>
    end
end
[~,which]=max(nonOrth(:,2));cIndex=nonOrth(which,1);
if size(nonOrth,1)>1
    multiple=1;
    for index=1:size(nonOrth,1)
        multiple=lcm(multiple,abs(hkl(nonOrth(index,1))));
    end
    pairs=nchoosek(1:size(nonOrth,1),2);
    for pair=1:size(pairs,1)
        vector=zeros(1,3);
        first=nonOrth(pairs(pair,1),1);second=nonOrth(pairs(pair,2),1);
        vector(first)=-round(multiple/hkl(first));
        vector(second)=round(multiple/hkl(second));
        inPlane{end+1}=vector; %#ok<AGROW>
        if numel(inPlane)==2,break,end
    end
end
if isempty(maxSearch),cVector=basis(cIndex,:);
else
    best=[-Inf,Inf];cVector=basis(cIndex,:);
    for a=-maxSearch:maxSearch
        for b=-maxSearch:maxSearch
            for c=-maxSearch:maxSearch
                candidate=[a,b,c];
                if ~any(candidate)|| ...
                        abs(det([inPlane{1};inPlane{2};candidate]))<1e-8
                    continue
                end
                cart=candidate*matrix;
                score=[abs(dot(cart,normal))/norm(cart),-norm(cart)];
                if score(1)>best(1)+1e-12|| ...
                        (abs(score(1)-best(1))<1e-12&&score(2)>best(2))
                    best=score;cVector=candidate;
                end
            end
        end
    end
end
scale=round([inPlane{1};inPlane{2};cVector]);
if det(scale)<0,scale=-scale;end
for index=1:3
    divisor=gcd(gcd(abs(scale(index,1)),abs(scale(index,2))), ...
        abs(scale(index,3)));
    if divisor>1,scale(index,:)=scale(index,:)/divisor;end
end
end
function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end
function properties=repeatProperties(properties,repetitions)
names=fieldnames(properties);
for index=1:numel(names)
    values=properties.(names{index});
    if iscell(values),properties.(names{index})=repmat(values,1,repetitions); %#ok<ALIGN>
    elseif size(values,1)>1
        properties.(names{index})=repmat(values,repetitions,1);
    else,properties.(names{index})=repmat(values,1,repetitions);end
end
end

function shifts=terminationShifts(z,projectedHeight,tolerance)
z=mod(reshape(double(z),[],1),1);
count=numel(z);
if count==1
    shifts=mod(z+.5,1);
    return
end
parent=1:count;
for first=1:count-1
    for second=first+1:count
        distance=abs(z(first)-z(second));
        distance=min(distance,1-distance)*projectedHeight;
        if distance<=tolerance
            rootFirst=findRoot(first);
            rootSecond=findRoot(second);
            parent(rootSecond)=rootFirst;
        end
    end
end
roots=zeros(count,1);
for index=1:count,roots(index)=findRoot(index);end
uniqueRoots=unique(roots,"stable");
locations=zeros(1,numel(uniqueRoots));
for group=1:numel(uniqueRoots)
    locations(group)=z(find(roots==uniqueRoots(group),1,"last"));
end
locations=sort(locations);
shifts=mod((locations+[locations(2:end),locations(1)+1])/2,1);
shifts=sort(shifts);
    function root=findRoot(index)
        root=index;
        while parent(root)~=root,root=parent(root);end
        while parent(index)~=index
            next=parent(index);parent(index)=root;index=next;
        end
    end
end

function definitions=normalizeBonds(bonds)
definitions=struct("species1",{},"species2",{},"distance",{});
if isempty(bonds),return,end
if isstruct(bonds)&&all(isfield(bonds, ...
        ["species1","species2","distance"]))
    definitions=bonds;
    return
end
if isa(bonds,"containers.Map")
    names=keys(bonds);
    for index=1:numel(names)
        pieces=regexp(string(names{index}),'[|,;/]','split');
        if numel(pieces)~=2
            error("KSSOLV:Matgenlab:Surface:Bonds", ...
                "Bond keys must be formatted as 'species1|species2'.");
        end
        definitions(end+1)=struct( ...
            "species1",string(pieces{1}), ...
            "species2",string(pieces{2}), ...
            "distance",double(bonds(names{index}))); %#ok<AGROW>
    end
    return
end
if isstruct(bonds)
    names=fieldnames(bonds);
    for index=1:numel(names)
        pieces=split(string(names{index}),"_");
        if numel(pieces)~=2
            error("KSSOLV:Matgenlab:Surface:Bonds", ...
                "Bond fields must be formatted as species1_species2.");
        end
        definitions(end+1)=struct( ...
            "species1",pieces(1),"species2",pieces(2), ...
            "distance",double(bonds.(names{index}))); %#ok<AGROW>
    end
    return
end
error("KSSOLV:Matgenlab:Surface:Bonds", ...
    "Bonds must be a containers.Map or a bond-definition struct.");
end

function ranges=bondRanges(structure,definitions,tolerance)
ranges=zeros(0,2);
for pair=1:numel(definitions)
    for index=1:structure.num_sites
        if ~speciesMatches(structure.sites{index}, ...
                definitions(pair).species1),continue,end
        neighbors=structure.get_neighbors( ...
            structure.sites{index},definitions(pair).distance);
        for neighbor=1:numel(neighbors)
            item=neighbors{neighbor};
            if ~speciesMatches(item,definitions(pair).species2),continue,end
            range=sort([structure.frac_coords(index,3), ...
                item.frac_coords(3)]);
            if range(2)>1
                ranges=[ranges;range(1),1;0,range(2)-1]; %#ok<AGROW>
            elseif range(1)<0
                ranges=[ranges;0,range(2);range(1)+1,1]; %#ok<AGROW>
            elseif abs(range(2)-range(1))>tolerance
                ranges(end+1,:)=range; %#ok<AGROW>
            end
        end
    end
end
end

function counts=referenceCoordination(structure,reference,other,distance)
counts=zeros(1,structure.num_sites);
for index=1:structure.num_sites
    if ~speciesMatches(structure.sites{index},reference),continue,end
    neighbors=structure.get_neighbors(structure.sites{index},distance);
    counts(index)=sum(cellfun(@(item) ...
        speciesMatches(item,other),neighbors));
end
end

function matched=speciesMatches(site,species)
label=string(site.species_string);
symbol=regexp(char(label),'[A-Z][a-z]?','match','once');
target=regexp(char(string(species)),'[A-Z][a-z]?','match','once');
matched=strcmp(symbol,target);
end
