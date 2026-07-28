classdef Slab < kssolv.analysis.matgenlab.core.Structure
    %SLAB Periodic surface structure with pymatgen-compatible metadata.
    properties
        miller_index
        oriented_unit_cell
        shift (1,1) double = 0
        scale_factor
        reconstruction = []
        energy = []
        reorient_lattice (1,1) logical = true
    end
    properties (Dependent)
        center_of_mass
        dipole
        normal
        surface_area
    end
    methods
        function obj=Slab(lattice,species,coords,millerIndex, ...
                orientedUnitCell,shift,scaleFactor,varargin)
            options=struct("reorient_lattice",true, ...
                "validate_proximity",false,"to_unit_cell",false, ...
                "reconstruction",[],"coords_are_cartesian",false, ...
                "site_properties",struct(),"energy",[]);
            options=parseOptions(options,varargin{:});
            if ~isa(lattice,"kssolv.analysis.matgenlab.core.Lattice")
                lattice=kssolv.analysis.matgenlab.core.Lattice(lattice);
            end
            if logical(options.reorient_lattice)
                if options.coords_are_cartesian
                    coords=lattice.get_fractional_coords(coords);
                    options.coords_are_cartesian=false;
                end
                lengths=lattice.lengths;angles=lattice.angles;
                lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                    from_parameters(lengths(1),lengths(2),lengths(3), ...
                    angles(1),angles(2),angles(3));
                ol=orientedUnitCell.lattice;
                lengths=ol.lengths;angles=ol.angles;
                ol=kssolv.analysis.matgenlab.core.Lattice. ...
                    from_parameters(lengths(1),lengths(2),lengths(3), ...
                    angles(1),angles(2),angles(3));
                orientedUnitCell=kssolv.analysis.matgenlab.core.Structure( ...
                    ol,orientedUnitCell.species_and_occu, ...
                    orientedUnitCell.frac_coords, ...
                    site_properties=orientedUnitCell.site_properties);
            end
            obj@kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coords, ...
                validate_proximity=logical(options.validate_proximity), ...
                to_unit_cell=logical(options.to_unit_cell), ...
                coords_are_cartesian=logical(options.coords_are_cartesian), ...
                site_properties=options.site_properties);
            obj.miller_index=reshape(double(millerIndex),1,[]);
            obj.shift=shift;obj.scale_factor=double(scaleFactor);
            obj.reconstruction=options.reconstruction;
            obj.energy=options.energy;
            obj.reorient_lattice=logical(options.reorient_lattice);
            obj.oriented_unit_cell=orientedUnitCell;
        end
        function value=get.center_of_mass(obj)
            weights=zeros(obj.num_sites,1);
            for index=1:obj.num_sites
                weights(index)=obj.sites_{index}.species.weight;
            end
            value=sum(obj.frac_coords.*weights,1)/sum(weights);
        end
        function value=get.normal(obj)
            value=cross(obj.lattice.matrix(1,:),obj.lattice.matrix(2,:));
            value=value/norm(value);
        end
        function value=get.surface_area(obj)
            value=norm(cross(obj.lattice.matrix(1,:), ...
                obj.lattice.matrix(2,:)));
        end
        function value=get.dipole(obj)
            centroid=mean(obj.cart_coords,1);value=zeros(1,3);
            for index=1:obj.num_sites
                composition=obj.sites_{index}.species;
                [species,amounts]=composition.items();
                charge=0;
                for speciesIndex=1:numel(species)
                    sp=species{speciesIndex};
                    if isa(sp,"kssolv.analysis.matgenlab.core.Species") && ...
                            ~isnan(sp.oxi_state)
                        charge=charge+sp.oxi_state*amounts(speciesIndex);
                    end
                end
                value=value+charge*dot(obj.sites_{index}.coords-centroid, ...
                    obj.normal)*obj.normal;
            end
        end
        function tf=is_polar(obj,tolerance)
            if nargin<2,tolerance=1e-3;end
            tf=norm(obj.dipole/obj.surface_area)>tolerance;
        end
        function tf=is_symmetric(obj,symprec)
            if nargin<2,symprec=.1;end
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj,symprec);
            tf=analyzer.is_laue();
            if tf,return,end
            operations=analyzer.get_point_group_operations();
            for index=1:numel(operations)
                operation=operations{index};
                if abs(operation.translation_vector(3))>1e-12 || ...
                        all(abs(operation.rotation_matrix(3,:)- ...
                        [0,0,-1])<1e-12)
                    tf=true;
                    return
                end
            end
            tf=false;
        end
        function result=copy(obj,siteProperties)
            if nargin<2||isempty(siteProperties)
                siteProperties=obj.site_properties;
            end
            result=kssolv.analysis.matgenlab.core.Slab( ...
                obj.lattice,obj.species_and_occu,obj.frac_coords, ...
                obj.miller_index,obj.oriented_unit_cell,obj.shift, ...
                obj.scale_factor,reorient_lattice=obj.reorient_lattice, ...
                reconstruction=obj.reconstruction,energy=obj.energy, ...
                site_properties=siteProperties);
        end
        function result=make_supercell(obj,scalingMatrix, ...
                toUnitCell,inPlace) %#ok<INUSD>
            if nargin<3,toUnitCell=true;end
            base=kssolv.analysis.matgenlab.core.Structure( ...
                obj.lattice,obj.species_and_occu,obj.frac_coords, ...
                site_properties=obj.site_properties);
            base=base.make_supercell(scalingMatrix,toUnitCell,true);
            result=kssolv.analysis.matgenlab.core.Slab( ...
                base.lattice,base.species_and_occu,base.frac_coords, ...
                obj.miller_index,obj.oriented_unit_cell,obj.shift, ...
                obj.scale_factor,reorient_lattice=obj.reorient_lattice, ...
                reconstruction=obj.reconstruction,energy=obj.energy, ...
                site_properties=base.site_properties);
        end
        function result=get_sorted_structure(obj,key,reverse)
            if nargin<2,key=[];end
            if nargin<3,reverse=false;end
            sorted=get_sorted_structure@ ...
                kssolv.analysis.matgenlab.core.IStructure(obj,key,reverse);
            result=kssolv.analysis.matgenlab.core.Slab( ...
                sorted.lattice,sorted.species_and_occu, ...
                sorted.frac_coords,obj.miller_index, ...
                obj.oriented_unit_cell,obj.shift,obj.scale_factor, ...
                reorient_lattice=obj.reorient_lattice, ...
                site_properties=sorted.site_properties,energy=obj.energy);
        end
        function result=get_orthogonal_c_slab(obj)
            matrix=obj.lattice.matrix;
            unitNormal=cross(matrix(1,:),matrix(2,:));
            unitNormal=unitNormal/norm(unitNormal);
            matrix(3,:)=dot(matrix(3,:),unitNormal)*unitNormal;
            result=kssolv.analysis.matgenlab.core.Slab( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix), ...
                obj.species_and_occu,obj.cart_coords,obj.miller_index, ...
                obj.oriented_unit_cell,obj.shift,obj.scale_factor, ...
                coords_are_cartesian=true, ...
                reorient_lattice=obj.reorient_lattice, ...
                site_properties=obj.site_properties,energy=obj.energy);
        end
        function obj=add_adsorbate_atom(obj,indices,species,distance,varargin)
            options=struct("specie",[]);
            options=parseOptions(options,varargin{:});
            if ~isempty(options.specie),species=options.specie;end
            indices=reshape(indices,1,[]);
            center=mean(obj.cart_coords(indices,:),1);
            obj=obj.append(species,center+obj.normal*distance, ...
                coords_are_cartesian=true);
        end
        function point=get_symmetric_site(obj,point,cartesian)
            if nargin<3,cartesian=false;end
            point=reshape(double(point),1,3);
            if ~cartesian,point=mod(point,1);end
            operations=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj).get_symmetry_operations(cartesian);
            found=false;
            for index=1:numel(operations)
                candidate=operations{index}.operate(point);
                if ~cartesian,candidate=mod(candidate,1);end
                if abs(candidate(3)-point(3))<=1e-6,continue,end
                trial=obj.copy();
                trial=trial.append("O",point, ...
                    coords_are_cartesian=cartesian);
                trial=trial.append("O",candidate, ...
                    coords_are_cartesian=cartesian);
                try
                    symmetric=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                        SpacegroupAnalyzer(trial).is_laue();
                catch
                    symmetric=false;
                end
                if symmetric
                    point=candidate;found=true;break
                end
            end
            if ~found
                error("KSSOLV:Matgenlab:Slab:SymmetricSite", ...
                    "Failed to get symmetric site.");
            end
        end
        function obj=symmetrically_add_atom(obj,species,point,varargin)
            options=struct("specie",[],"coords_are_cartesian",false);
            options=parseOptions(options,varargin{:});
            if ~isempty(options.specie),species=options.specie;end
            other=obj.get_symmetric_site(point, ...
                logical(options.coords_are_cartesian));
            obj=obj.append(species,point, ...
                coords_are_cartesian=logical(options.coords_are_cartesian));
            obj=obj.append(species,other, ...
                coords_are_cartesian=logical(options.coords_are_cartesian));
        end
        function obj=symmetrically_remove_atoms(obj,indices)
            indices=reshape(double(indices),1,[]);
            equivalent=zeros(size(indices));
            symmetric=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.copy()).get_symmetrized_structure();
            for position=1:numel(indices)
                original=indices(position);
                group=find(cellfun(@(members)any(members==original), ...
                    symmetric.equivalent_indices),1);
                if isempty(group)
                    warning("KSSOLV:Matgenlab:Slab:EquivalentSite", ...
                        "Equivalent sites could not be found; surface unchanged.");
                    return
                end
                candidates=setdiff( ...
                    symmetric.equivalent_indices{group},original,"stable");
                candidates=candidates(abs(obj.frac_coords(candidates,3)- ...
                    obj.frac_coords(original,3))>1e-10);
                for candidate=candidates
                    trial=obj.remove_sites([original,candidate]);
                    if trial.is_symmetric()
                        equivalent(position)=candidate;
                        break
                    end
                end
                if equivalent(position)==0
                    warning("KSSOLV:Matgenlab:Slab:EquivalentSite", ...
                        "Equivalent sites could not be found; surface unchanged.");
                    return
                end
            end
            obj=obj.remove_sites(unique([indices,equivalent]));
        end
        function [sites,obj]=get_surface_sites(obj,tag)
            if nargin<2,tag=false;end
            sites=struct("top",{{}},"bottom",{{}});
            unitCell=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.oriented_unit_cell). ...
                get_symmetrized_structure();
            neighborFinder=kssolv.analysis.matgenlab.core.VoronoiNN();
            reference=struct();
            for group=1:numel(unitCell.equivalent_indices)
                index=unitCell.equivalent_indices{group}(1);
                key=matlab.lang.makeValidName(char( ...
                    unitCell.sites{index}.species_string));
                coordination=round(neighborFinder.get_cn( ...
                    unitCell,index,"use_weights",true),5);
                if ~isfield(reference,key)
                    reference.(key)=coordination;
                elseif ~any(reference.(key)==coordination)
                    reference.(key)(end+1)=coordination;
                end
            end
            properties=false(1,obj.num_sites);
            for index=1:obj.num_sites
                key=matlab.lang.makeValidName(char( ...
                    obj.sites_{index}.species_string));
                try
                    coordination=round(neighborFinder.get_cn( ...
                        obj,index,"use_weights",true),5);
                    isSurface=~isfield(reference,key)|| ...
                        coordination<min(reference.(key));
                catch
                    isSurface=true;
                end
                if isSurface
                    properties(index)=true;
                    if obj.frac_coords(index,3)>obj.center_of_mass(3)
                        sites.top{end+1}={obj.sites_{index},index};
                    else
                        sites.bottom{end+1}={obj.sites_{index},index};
                    end
                end
            end
            if tag
                obj=obj.add_site_property("is_surf_site",properties);
            end
        end
        function slabs=get_tasker2_slabs(obj,varargin)
            options=struct("tol",.01,"same_species_only",true);
            options=parseOptions(options,varargin{:});
            coordinates=obj.frac_coords;
            [~,order]=sort(coordinates(:,3));
            totalLayers=round(obj.lattice.lengths(3)/ ...
                obj.oriented_unit_cell.lattice.lengths(3));
            slabLayers=round((coordinates(order(end),3)- ...
                coordinates(order(1),3))*totalLayers);
            slabRatio=slabLayers/totalLayers;
            symmetric=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj).get_symmetrized_structure();
            slabs={};
            surfaces=[order(1),slabRatio;order(end),-slabRatio];
            for side=1:2
                surfaceIndex=surfaces(side,1);
                surfaceZ=coordinates(surfaceIndex,3);
                toMove=[];
                for index=1:obj.num_sites
                    sameSpecies=obj.sites_{index}.species.almost_equals( ...
                        obj.sites_{surfaceIndex}.species);
                    if abs(coordinates(index,3)-surfaceZ)<=options.tol && ...
                            (~options.same_species_only||sameSpecies)
                        toMove(end+1)=index; %#ok<AGROW>
                    end
                end
                groups=cell(1,0);
                for index=toMove
                    group=find(cellfun(@(members)any(members==index), ...
                        symmetric.equivalent_indices),1);
                    existing=find(cellfun(@(item)item.id==group,groups),1);
                    if isempty(existing)
                        groups{end+1}=struct( ...
                            "id",group,"members",index); %#ok<AGROW>
                    else
                        groups{existing}.members(end+1)=index;
                    end
                end
                if isempty(toMove)||any(cellfun(@(item) ...
                        mod(numel(item.members),2)~=0,groups))
                    warning("KSSOLV:Matgenlab:Slab:TaskerOdd", ...
                        "Odd number of sites to divide; enlarge the surface cell.");
                    continue
                end
                choices=cell(1,numel(groups));
                for group=1:numel(groups)
                    members=groups{group}.members;
                    choices{group}=num2cell(nchoosek( ...
                        members,numel(members)/2),2);
                end
                selections=cartesianSelections(choices);
                for selection=1:numel(selections)
                    selected=selections{selection};
                    moved=setdiff(toMove,selected,"stable");
                    trialCoordinates=coordinates;
                    trialCoordinates(moved,3)=trialCoordinates(moved,3)+ ...
                        surfaces(side,2);
                    slabs{end+1}=kssolv.analysis.matgenlab.core.Slab( ...
                        obj.lattice,obj.species_and_occu,trialCoordinates, ...
                        obj.miller_index,obj.oriented_unit_cell,obj.shift, ...
                        obj.scale_factor,energy=obj.energy, ...
                        reorient_lattice=obj.reorient_lattice); %#ok<AGROW>
                end
            end
            if isempty(slabs),return,end
            grouped=kssolv.analysis.matgenlab.core. ...
                group_surface_structures(slabs,1e-6);
            slabs=cellfun(@(group)group{1},grouped, ...
                "UniformOutput",false);
        end
        function value=as_dict(obj,varargin)
            value=as_dict@kssolv.analysis.matgenlab.core.IStructure( ...
                obj,varargin{:});
            value.x_module="pymatgen.core.surface";value.x_class="Slab";
            value.oriented_unit_cell=obj.oriented_unit_cell.as_dict();
            value.miller_index=obj.miller_index;value.shift=obj.shift;
            value.scale_factor=obj.scale_factor;
            value.reconstruction=obj.reconstruction;value.energy=obj.energy;
        end
    end
    methods (Static)
        function obj=from_dict(value)
            if isa(value.lattice,"kssolv.analysis.matgenlab.core.Lattice")
                lattice=value.lattice;
            else
                lattice=kssolv.analysis.matgenlab.core.Lattice.from_dict( ...
                    value.lattice);
            end
            base=kssolv.analysis.matgenlab.core.Structure.from_dict(value);
            if isa(value.oriented_unit_cell, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                oriented=value.oriented_unit_cell;
            else
                oriented=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                    value.oriented_unit_cell);
            end
            reconstruction=[];energy=[];
            if isfield(value,"reconstruction"),reconstruction=value.reconstruction;end
            if isfield(value,"energy"),energy=value.energy;end
            obj=kssolv.analysis.matgenlab.core.Slab(lattice, ...
                base.species_and_occu,base.frac_coords, ...
                value.miller_index,oriented,value.shift, ...
                value.scale_factor,site_properties=base.site_properties, ...
                reconstruction=reconstruction,energy=energy);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.core.Slab.from_dict(value);
        end
    end
end

function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end

function selections=cartesianSelections(choices)
selections={zeros(1,0)};
for group=1:numel(choices)
    next=cell(1,0);
    for prefix=1:numel(selections)
        for option=1:numel(choices{group})
            next{end+1}=[selections{prefix}, ...
                reshape(choices{group}{option},1,[])]; %#ok<AGROW>
        end
    end
    selections=next;
end
end
