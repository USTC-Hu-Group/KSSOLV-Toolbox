classdef AdsorbateSiteFinder
    %ADSORBATESITEFINDER Enumerate surface adsorption configurations.
    %
    % Native MATLAB implementation of pymatgen-core v2026.7.24
    % pymatgen.core.adsorption.AdsorbateSiteFinder.

    properties
        slab
        mvec (1,3) double
    end

    properties (Dependent,SetAccess=private)
        surface_sites
    end

    methods
        function obj=AdsorbateSiteFinder(slab,selectiveDynamics, ...
                height,miVec)
            if nargin<2,selectiveDynamics=false;end
            if nargin<3,height=.9;end
            if nargin<4,miVec=[];end
            obj.requireStructure(slab);
            if isempty(miVec)
                obj.mvec=kssolv.analysis.matgenlab.core.get_mi_vec(slab);
            else
                miVec=reshape(double(miVec),1,[]);
                if numel(miVec)~=3||any(~isfinite(miVec))||norm(miVec)==0
                    error("KSSOLV:Matgenlab:Adsorption:MillerVector", ...
                        "mi_vec must be a finite nonzero three-vector.");
                end
                obj.mvec=miVec;
            end
            slab=obj.assign_site_properties(slab,height);
            if logical(selectiveDynamics)
                slab=obj.assign_selective_dynamics(slab);
            end
            obj.slab=slab;
        end

        function sites=find_surface_sites_by_height(obj,slab,height,xyTol)
            if nargin<3,height=.9;end
            if nargin<4,xyTol=.05;end
            obj.requireStructure(slab);
            if ~isscalar(height)||~isfinite(height)||height<0
                error("KSSOLV:Matgenlab:Adsorption:Height", ...
                    "height must be a finite nonnegative scalar.");
            end
            projections=slab.cart_coords*obj.mvec.';
            selected=find(projections-max(projections)>=-height);
            if isempty(xyTol)||xyTol==0
                sites=slab.sites(selected);
                return
            end
            if ~isscalar(xyTol)||~isfinite(xyTol)||xyTol<0
                error("KSSOLV:Matgenlab:Adsorption:XyTolerance", ...
                    "xy_tol must be a finite nonnegative scalar.");
            end
            selected=fliplr(reshape(selected,1,[]));
            sites=cell(1,0);
            perpendicularFracs=zeros(0,3);
            for index=selected
                site=slab.sites{index};
                perpendicular=site.coords-dot(site.coords,obj.mvec);
                fractional=slab.lattice. ...
                    get_fractional_coords(perpendicular);
                if ~kssolv.analysis.matgenlab.util.in_coord_list_pbc( ...
                        perpendicularFracs,fractional)
                    sites{end+1}=site; %#ok<AGROW>
                    perpendicularFracs(end+1,:)=fractional; %#ok<AGROW>
                end
            end
        end

        function slab=assign_site_properties(obj,slab,height)
            if nargin<3,height=.9;end
            obj.requireStructure(slab);
            properties=slab.site_properties;
            if isfield(properties,"surface_properties")
                return
            end
            surface=obj.find_surface_sites_by_height(slab,height);
            values=repmat({"subsurface"},1,slab.num_sites);
            for index=1:slab.num_sites
                if any(cellfun(@(site)site==slab.sites{index},surface))
                    values{index}="surface";
                end
            end
            slab=slab.add_site_property("surface_properties",values);
        end

        function mesh=get_extended_surface_mesh(obj,repeat)
            if nargin<2,repeat=[5,5,1];end
            repeat=obj.validateRepeat(repeat);
            if isempty(obj.surface_sites)
                error("KSSOLV:Matgenlab:Adsorption:NoSurfaceSites", ...
                    "No surface sites are available for mesh construction.");
            end
            mesh=kssolv.analysis.matgenlab.core.Structure. ...
                from_sites(obj.surface_sites);
            mesh=mesh.make_supercell(repeat,true,true);
        end

        function value=get.surface_sites(obj)
            value=cell(1,0);
            for index=1:obj.slab.num_sites
                site=obj.slab.sites{index};
                if isfield(site.site_properties,"surface_properties")&& ...
                        string(site.site_properties.surface_properties)== ...
                        "surface"
                    value{end+1}=site; %#ok<AGROW>
                end
            end
        end

        function value=subsurface_sites(obj)
            value=cell(1,0);
            for index=1:obj.slab.num_sites
                site=obj.slab.sites{index};
                if isfield(site.site_properties,"surface_properties")&& ...
                        string(site.site_properties.surface_properties)== ...
                        "subsurface"
                    value{end+1}=site; %#ok<AGROW>
                end
            end
        end

        function sites=find_adsorption_sites(obj,distance,putInside, ...
                symmReduce,nearReduce,positions,noObtuseHollow)
            if nargin<2,distance=2;end
            if nargin<3,putInside=true;end
            if nargin<4,symmReduce=1e-2;end
            if nargin<5,nearReduce=1e-2;end
            if nargin<6,positions=["ontop","bridge","hollow"];end
            if nargin<7,noObtuseHollow=true;end
            obj.validateFindArguments(distance,symmReduce,nearReduce);
            positions=obj.normalizePositions(positions);
            sites=struct();
            for position=positions
                sites.(char(position))=zeros(0,3);
            end
            if any(positions=="ontop")
                sites.ontop=cell2mat(cellfun(@(site)site.coords, ...
                    obj.surface_sites,"UniformOutput",false).');
            end
            if any(positions=="subsurface")
                subsurface=obj.subsurface_sites();
                if isempty(subsurface)
                    sites.subsurface=zeros(0,3);
                else
                    [~,highest]=max(obj.slab.cart_coords(:,3));
                    reference=obj.slab.sites{highest}.coords;
                    coordinates=zeros(numel(subsurface),3);
                    for index=1:numel(subsurface)
                        site=subsurface{index};
                        coordinates(index,:)=site.coords+obj.mvec* ...
                            dot(reference-site.coords,obj.mvec);
                    end
                    sites.subsurface=coordinates;
                end
            end
            if any(positions=="bridge")||any(positions=="hollow")
                mesh=obj.get_extended_surface_mesh();
                operation=kssolv.analysis.matgenlab.core.get_rot(obj.slab);
                planar=operation.operate(mesh.cart_coords);
                try
                    triangles=delaunay(planar(:,1),planar(:,2));
                catch exception
                    wrapped=MException( ...
                        "KSSOLV:Matgenlab:Adsorption:Delaunay", ...
                        "Surface-site Delaunay triangulation failed.");
                    throw(addCause(wrapped,exception));
                end
                bridge=zeros(3*size(triangles,1),3);
                hollow=zeros(size(triangles,1),3);
                bridgeCount=0;hollowCount=0;
                opposite=[2,3;1,3;1,2];
                for triangleIndex=1:size(triangles,1)
                    vertices=triangles(triangleIndex,:);
                    dots=zeros(1,3);
                    for corner=1:3
                        others=vertices(opposite(corner,:));
                        vectors=mesh.cart_coords(others,:)- ...
                            mesh.cart_coords(vertices(corner),:);
                        vectors=vectors./vecnorm(vectors,2,2);
                        dots(corner)=dot(vectors(1,:),vectors(2,:));
                        if any(positions=="bridge")
                            bridgeCount=bridgeCount+1;
                            bridge(bridgeCount,:)= ...
                                obj.ensemble_center(mesh,others);
                        end
                    end
                    obtuse=logical(noObtuseHollow)&&any(dots<1e-5);
                    if any(positions=="hollow")&&~obtuse
                        hollowCount=hollowCount+1;
                        hollow(hollowCount,:)= ...
                            obj.ensemble_center(mesh,vertices);
                    end
                end
                bridge=bridge(1:bridgeCount,:);
                hollow=hollow(1:hollowCount,:);
                if any(positions=="bridge"),sites.bridge=bridge;end
                if any(positions=="hollow"),sites.hollow=hollow;end
            end
            for position=positions
                name=char(position);
                coordinates=sites.(name);
                if any(position==["bridge","hollow"])&& ...
                        ~isempty(coordinates)
                    fractional=obj.slab.lattice. ...
                        get_fractional_coords(coordinates);
                    keep=fractional(:,1)>1&fractional(:,1)<4& ...
                        fractional(:,2)>1&fractional(:,2)<4;
                    coordinates=obj.slab.lattice. ...
                        get_cartesian_coords(fractional(keep,:));
                end
                if nearReduce~=0
                    coordinates=obj.near_reduce(coordinates,nearReduce);
                end
                if logical(putInside)
                    coordinates=kssolv.analysis.matgenlab.core. ...
                        put_coord_inside(obj.slab.lattice,coordinates);
                end
                if symmReduce~=0
                    coordinates=obj.symm_reduce(coordinates,symmReduce);
                end
                sites.(name)=coordinates+distance*obj.mvec;
            end
            combined=zeros(0,3);
            for position=positions
                combined=[combined;sites.(char(position))]; %#ok<AGROW>
            end
            sites.all=combined;
        end

        function coordinates=symm_reduce(obj,coordsSet,threshold)
            if nargin<3,threshold=1e-6;end
            coordinates=obj.coordsMatrix(coordsSet);
            obj.validateThreshold(threshold,"symmetry threshold");
            if isempty(coordinates),return,end
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.slab,.1);
            operations=analyzer.get_symmetry_operations();
            fractional=obj.slab.lattice. ...
                get_fractional_coords(coordinates);
            uniqueFractional=zeros(size(fractional));
            uniqueCount=0;
            for coordinateIndex=1:size(fractional,1)
                duplicate=false;
                for operationIndex=1:numel(operations)
                    transformed=operations{operationIndex}. ...
                        operate(fractional(coordinateIndex,:));
                    if kssolv.analysis.matgenlab.util. ...
                            in_coord_list_pbc( ...
                            uniqueFractional(1:uniqueCount,:), ...
                            transformed,threshold)
                        duplicate=true;
                        break
                    end
                end
                if ~duplicate
                    uniqueCount=uniqueCount+1;
                    uniqueFractional(uniqueCount,:)= ...
                        fractional(coordinateIndex,:);
                end
            end
            uniqueFractional=uniqueFractional(1:uniqueCount,:);
            coordinates=obj.slab.lattice. ...
                get_cartesian_coords(uniqueFractional);
        end

        function coordinates=near_reduce(obj,coordsSet,threshold)
            if nargin<3,threshold=1e-4;end
            coordinates=obj.coordsMatrix(coordsSet);
            obj.validateThreshold(threshold,"near threshold");
            if isempty(coordinates),return,end
            fractional=obj.slab.lattice. ...
                get_fractional_coords(coordinates);
            uniqueFractional=zeros(0,3);
            for index=1:size(fractional,1)
                if ~kssolv.analysis.matgenlab.util.in_coord_list_pbc( ...
                        uniqueFractional,fractional(index,:),threshold)
                    uniqueFractional(end+1,:)=fractional(index,:); ...
                        %#ok<AGROW>
                end
            end
            coordinates=obj.slab.lattice. ...
                get_cartesian_coords(uniqueFractional);
        end

        function structure=add_adsorbate(obj,molecule,adsCoord,repeat, ...
                translate,reorient)
            if nargin<4,repeat=[];end
            if nargin<5,translate=true;end
            if nargin<6,reorient=true;end
            if ~isa(molecule,"kssolv.analysis.matgenlab.core.Molecule")
                error("KSSOLV:Matgenlab:Adsorption:Molecule", ...
                    "molecule must be a Molecule.");
            end
            adsCoord=reshape(double(adsCoord),1,[]);
            if numel(adsCoord)~=3||any(~isfinite(adsCoord))
                error("KSSOLV:Matgenlab:Adsorption:Coordinate", ...
                    "ads_coord must be a finite three-vector.");
            end
            molecule=molecule.copy();
            if logical(translate)
                coordinates=molecule.cart_coords;
                front=find(coordinates(:,3)==min(coordinates(:,3)));
                masses=zeros(numel(front),1);
                for index=1:numel(front)
                    masses(index)=molecule.sites{front(index)}.species.weight;
                end
                center=sum(coordinates(front,:).*masses,1)/sum(masses);
                molecule=molecule.translate_sites( ...
                    1:molecule.num_sites,-center);
            end
            if logical(reorient)
                operation=kssolv.analysis.matgenlab.core.get_rot(obj.slab);
                molecule=molecule.apply_operation(operation.inverse);
            end
            structure=obj.slab.copy();
            if ~isempty(repeat)
                structure=structure.make_supercell( ...
                    obj.validateRepeat(repeat),true,true);
            end
            properties=structure.site_properties;
            if isfield(properties,"surface_properties")
                molecule=molecule.add_site_property( ...
                    "surface_properties", ...
                    repmat({"adsorbate"},1,molecule.num_sites));
            end
            if isfield(properties,"selective_dynamics")
                molecule=molecule.add_site_property( ...
                    "selective_dynamics", ...
                    repmat({[true,true,true]},1,molecule.num_sites));
            end
            for index=1:molecule.num_sites
                site=molecule.sites{index};
                structure=structure.append(site.specie, ...
                    adsCoord+site.coords,coords_are_cartesian=true, ...
                    properties=site.site_properties);
            end
        end

        function structures=generate_adsorption_structures(obj,molecule, ...
                repeat,minLw,translate,reorient,findArgs)
            if nargin<3,repeat=[];end
            if nargin<4,minLw=5;end
            if nargin<5,translate=true;end
            if nargin<6,reorient=true;end
            if nargin<7,findArgs=struct();end
            if isempty(repeat)
                lengths=obj.slab.lattice.lengths;
                repeat=[ceil(minLw/lengths(1)), ...
                    ceil(minLw/lengths(2)),1];
            else
                repeat=obj.validateRepeat(repeat);
            end
            adsorption=obj.findWithStruct(findArgs);
            structures=cell(1,size(adsorption.all,1));
            for index=1:size(adsorption.all,1)
                structures{index}=obj.add_adsorbate(molecule, ...
                    adsorption.all(index,:),repeat,translate,reorient);
            end
        end

        function structures=adsorb_both_surfaces(obj,molecule,repeat, ...
                minLw,translate,reorient,findArgs)
            if nargin<3,repeat=[];end
            if nargin<4,minLw=5;end
            if nargin<5,translate=true;end
            if nargin<6,reorient=true;end
            if nargin<7,findArgs=struct();end
            oneSide=obj.generate_adsorption_structures(molecule,repeat, ...
                minLw,translate,reorient,findArgs);
            structures=cell(size(oneSide));
            for structureIndex=1:numel(oneSide)
                adsorbed=oneSide{structureIndex};
                adsorbates=cell(1,0);indices=zeros(1,0);
                for index=1:adsorbed.num_sites
                    site=adsorbed.sites{index};
                    if isfield(site.site_properties, ...
                            "surface_properties")&& ...
                            string(site.site_properties. ...
                            surface_properties)=="adsorbate"
                        adsorbates{end+1}=site; %#ok<AGROW>
                        indices(end+1)=index; %#ok<AGROW>
                    end
                end
                clean=adsorbed.remove_sites(indices);
                resultSlab=clean.copy();
                for index=1:numel(adsorbates)
                    adsorbate=adsorbates{index};
                    opposite=obj.symmetricOpposite(clean, ...
                        adsorbate.frac_coords);
                    resultSlab=resultSlab.append( ...
                        adsorbate.specie,opposite, ...
                        properties=struct( ...
                        "surface_properties","adsorbate"));
                    resultSlab=resultSlab.append(adsorbate.specie, ...
                        adsorbate.frac_coords,properties=struct( ...
                        "surface_properties","adsorbate"));
                end
                structures{structureIndex}=resultSlab;
            end
        end

        function structures=generate_substitution_structures(obj,atom, ...
                targetSpecies,subBothSides,rangeTol,distFromSurf)
            if nargin<3,targetSpecies=[];end
            if nargin<4,subBothSides=false;end
            if nargin<5,rangeTol=.01;end
            if nargin<6,distFromSurf=0;end
            obj.validateThreshold(rangeTol,"range tolerance");
            targets=reshape(string(targetSpecies),1,[]);
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.slab);
            symmetric=analyzer.get_symmetrized_structure();
            [~,order]=sort(symmetric.frac_coords(:,3));
            first=symmetric.sites{order(1)};
            if string(first.site_properties.surface_properties)=="surface"
                distance=first.frac_coords(3)+distFromSurf;
            else
                distance=symmetric.frac_coords(order(end),3)-distFromSurf;
            end
            candidates=cell(1,0);
            for index=1:symmetric.num_sites
                site=symmetric.sites{index};
                if ~(distance-rangeTol<site.frac_coords(3)&& ...
                        site.frac_coords(3)<distance+rangeTol)
                    continue
                end
                if ~isempty(targets)&& ...
                        ~any(targets==site.species_string)
                    continue
                end
                substituted=obj.slab.copy();
                properties=substituted.site_properties.surface_properties;
                if logical(subBothSides)
                    group=find(cellfun(@(members) ...
                        any(members==index), ...
                        symmetric.equivalent_indices),1);
                    equivalents=symmetric.equivalent_indices{group};
                    other=equivalents(find(abs( ...
                        symmetric.frac_coords(equivalents,3)- ...
                        site.frac_coords(3))>5e-7,1));
                    if ~isempty(other)
                        properties{other}="substitute";
                        substituted=substituted.replace(other,atom);
                    end
                end
                properties{index}="substitute";
                substituted=substituted.replace(index,atom);
                substituted=substituted.add_site_property( ...
                    "surface_properties",properties);
                candidates{end+1}=substituted; %#ok<AGROW>
            end
            if isempty(candidates)
                structures=cell(1,0);
                return
            end
            matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
            groups=matcher.group_structures(candidates);
            structures=cellfun(@(group)group{1},groups, ...
                "UniformOutput",false);
        end
    end

    methods (Static)
        function obj=from_bulk_and_miller(structure,millerIndex, ...
                minSlabSize,minVacuumSize,maxNormalSearch,centerSlab, ...
                selectiveDynamics,undercoordThreshold)
            if nargin<3,minSlabSize=8;end
            if nargin<4,minVacuumSize=10;end
            if nargin<5,maxNormalSearch=[];end
            if nargin<6,centerSlab=true;end
            if nargin<7,selectiveDynamics=false;end
            if nargin<8,undercoordThreshold=.09;end
            kssolv.analysis.matgenlab.core.AdsorbateSiteFinder. ...
                requireStructure(structure);
            millerIndex=reshape(double(millerIndex),1,[]);
            if numel(millerIndex)~=3||any(millerIndex~=fix(millerIndex))
                error("KSSOLV:Matgenlab:Adsorption:MillerIndex", ...
                    "miller_index must contain three integers.");
            end
            bulkFinder=kssolv.analysis.matgenlab.core. ...
                VoronoiNN("tol",.05);
            coordinations=zeros(1,structure.num_sites);
            for index=1:structure.num_sites
                coordinations(index)=numel( ...
                    bulkFinder.get_nn(structure,index));
            end
            bulk=structure.copy(struct( ...
                "bulk_coordinations",coordinations));
            slabs=kssolv.analysis.matgenlab.core.generate_all_slabs( ...
                bulk,max(millerIndex),minSlabSize,minVacuumSize, ...
                "max_normal_search",maxNormalSearch, ...
                "center_slab",logical(centerSlab));
            selected=[];
            for index=1:numel(slabs)
                if isequal(slabs{index}.miller_index,millerIndex)
                    selected=slabs{index};
                    break
                end
            end
            if isempty(selected)
                error("KSSOLV:Matgenlab:Adsorption:MillerNotFound", ...
                    "Miller index not in slab dict.");
            end
            surfaceFinder=kssolv.analysis.matgenlab.core. ...
                VoronoiNN("tol",.05,"allow_pathological",true);
            normal=kssolv.analysis.matgenlab.core.get_mi_vec(selected);
            projections=selected.cart_coords*normal.';
            average=mean(projections);
            labels=repmat({"subsurface"},1,selected.num_sites);
            undercoords=zeros(1,selected.num_sites);
            bulkValues=selected.site_properties.bulk_coordinations;
            for index=1:selected.num_sites
                bulkCoord=double(bulkValues{index});
                slabCoord=numel(surfaceFinder.get_nn(selected,index));
                undercoords(index)=(bulkCoord-slabCoord)/bulkCoord;
                if undercoords(index)>undercoordThreshold&& ...
                        projections(index)>average
                    labels{index}="surface";
                end
            end
            selected=selected.add_site_property( ...
                "surface_properties",labels);
            selected=selected.add_site_property( ...
                "undercoords",undercoords);
            obj=kssolv.analysis.matgenlab.core. ...
                AdsorbateSiteFinder(selected,selectiveDynamics);
        end

        function center=ensemble_center(siteList,indices,cartesian)
            if nargin<3,cartesian=true;end
            indices=reshape(double(indices),1,[]);
            if isempty(indices)||any(indices<1)||any(indices~=fix(indices))
                error("KSSOLV:Matgenlab:Adsorption:SiteIndices", ...
                    "indices must contain positive one-based MATLAB indices.");
            end
            coordinates=zeros(numel(indices),3);
            for index=1:numel(indices)
                if iscell(siteList)
                    site=siteList{indices(index)};
                else
                    site=siteList(indices(index));
                end
                if logical(cartesian)
                    coordinates(index,:)=site.coords;
                else
                    coordinates(index,:)=site.frac_coords;
                end
            end
            center=mean(coordinates,1);
        end

        function result=assign_selective_dynamics(inputSlab)
            kssolv.analysis.matgenlab.core.AdsorbateSiteFinder. ...
                requireStructure(inputSlab);
            properties=inputSlab.site_properties;
            if ~isfield(properties,"surface_properties")
                error("KSSOLV:Matgenlab:Adsorption:SurfaceProperties", ...
                    "surface_properties must be assigned first.");
            end
            values=cell(1,inputSlab.num_sites);
            for index=1:inputSlab.num_sites
                if string(properties.surface_properties{index})== ...
                        "subsurface"
                    values{index}=[false,false,false];
                else
                    values{index}=[true,true,true];
                end
            end
            result=inputSlab.add_site_property( ...
                "selective_dynamics",values);
        end
    end

    methods (Access=private)
        function sites=findWithStruct(obj,values)
            if isempty(values),values=struct();end
            if ~isstruct(values)||~isscalar(values)
                error("KSSOLV:Matgenlab:Adsorption:FindArguments", ...
                    "find_args must be a scalar struct.");
            end
            allowed=["distance","put_inside","symm_reduce", ...
                "near_reduce","positions","no_obtuse_hollow"];
            names=string(fieldnames(values));
            unknown=setdiff(names,allowed);
            if ~isempty(unknown)
                error("KSSOLV:Matgenlab:Adsorption:FindArguments", ...
                    "Unknown find_adsorption_sites option '%s'.", ...
                    unknown(1));
            end
            distance=obj.fieldOr(values,"distance",2);
            putInside=obj.fieldOr(values,"put_inside",true);
            symmReduce=obj.fieldOr(values,"symm_reduce",1e-2);
            nearReduce=obj.fieldOr(values,"near_reduce",1e-2);
            positions=obj.fieldOr(values,"positions", ...
                ["ontop","bridge","hollow"]);
            noObtuse=obj.fieldOr(values,"no_obtuse_hollow",true);
            sites=obj.find_adsorption_sites(distance,putInside, ...
                symmReduce,nearReduce,positions,noObtuse);
        end

        function point=symmetricOpposite(~,structure,point)
            if ismethod(structure,"get_symmetric_site")
                point=structure.get_symmetric_site(point,false);
                return
            end
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(structure);
            operations=analyzer.get_symmetry_operations();
            candidates=zeros(numel(operations),3);
            for index=1:numel(operations)
                candidates(index,:)=mod( ...
                    operations{index}.operate(point),1);
            end
            [difference,index]=max(abs(candidates(:,3)-point(3)));
            if difference<=1e-6
                error("KSSOLV:Matgenlab:Adsorption:SymmetricSite", ...
                    "Failed to get a symmetric site on the opposite surface.");
            end
            point=candidates(index,:);
        end
    end

    methods (Static,Access=private)
        function requireStructure(value)
            if ~isa(value,"kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:Adsorption:Structure", ...
                    "Expected a Structure or Slab.");
            end
        end

        function repeat=validateRepeat(repeat)
            repeat=reshape(double(repeat),1,[]);
            if numel(repeat)~=3||any(~isfinite(repeat))|| ...
                    any(repeat~=fix(repeat))||any(repeat<1)
                error("KSSOLV:Matgenlab:Adsorption:Repeat", ...
                    "repeat must contain three positive integers.");
            end
        end

        function validateFindArguments(distance,symmReduce,nearReduce)
            if ~isscalar(distance)||~isfinite(distance)
                error("KSSOLV:Matgenlab:Adsorption:Distance", ...
                    "distance must be a finite scalar.");
            end
            kssolv.analysis.matgenlab.core.AdsorbateSiteFinder. ...
                validateThreshold( ...
                symmReduce,"symmetry threshold");
            kssolv.analysis.matgenlab.core.AdsorbateSiteFinder. ...
                validateThreshold( ...
                nearReduce,"near threshold");
        end

        function validateThreshold(value,name)
            if ~isscalar(value)||~isfinite(value)||value<0
                error("KSSOLV:Matgenlab:Adsorption:Threshold", ...
                    "%s must be a finite nonnegative scalar.",name);
            end
        end

        function positions=normalizePositions(values)
            positions=reshape(string(values),1,[]);
            allowed=["ontop","bridge","hollow","subsurface"];
            if isempty(positions)||numel(unique(positions))~= ...
                    numel(positions)||any(~ismember(positions,allowed))
                error("KSSOLV:Matgenlab:Adsorption:Positions", ...
                    "positions must be unique values from ontop, bridge, " + ...
                    "hollow, and subsurface.");
            end
        end

        function coordinates=coordsMatrix(values)
            if isempty(values),coordinates=zeros(0,3);return,end
            if iscell(values)
                coordinates=cell2mat(cellfun(@(value) ...
                    reshape(double(value),1,3),values, ...
                    "UniformOutput",false).');
            else
                coordinates=double(values);
                if isvector(coordinates)
                    coordinates=reshape(coordinates,1,[]);
                end
            end
            if size(coordinates,2)~=3||any(~isfinite(coordinates),"all")
                error("KSSOLV:Matgenlab:Adsorption:Coordinates", ...
                    "Coordinate sets must be finite N-by-3 arrays.");
            end
        end

        function value=fieldOr(structure,name,default)
            if isfield(structure,name),value=structure.(name);
            else,value=default;end
        end
    end
end
