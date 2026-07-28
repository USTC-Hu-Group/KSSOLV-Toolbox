classdef ReconstructionGenerator
    %RECONSTRUCTIONGENERATOR Build reconstructed surface supercells.
    properties
        initial_structure
        min_slab_size
        min_vacuum_size
        reconstruction_name
        reconstruction_json
        reconstruction
        slabgen_params
        trans_matrix
        name
    end
    methods
        function obj=ReconstructionGenerator(initialStructure,minSlabSize, ...
                minVacuumSize,reconstructionName,varargin)
            obj.initial_structure=initialStructure;
            obj.min_slab_size=minSlabSize;obj.min_vacuum_size=minVacuumSize;
            obj.reconstruction_name=string(reconstructionName);
            obj.name=obj.reconstruction_name;
            obj.reconstruction_json=[];
            if ~isempty(varargin)
                archive=varargin{1};
            else
                path=fullfile(fileparts(mfilename("fullpath")),"+data", ...
                    "reconstructions_archive.json");
                archive=jsondecode(fileread(path));
            end
            key=matlab.lang.makeValidName(char(obj.reconstruction_name));
            if ~isstruct(archive)||~isfield(archive,key)
                error("KSSOLV:Matgenlab:Surface:Reconstruction", ...
                    "Unknown reconstruction '%s'.",obj.reconstruction_name);
            end
            obj.reconstruction=archive.(key);
            if isfield(obj.reconstruction,"base_reconstruction")
                baseKey=matlab.lang.makeValidName(char( ...
                    obj.reconstruction.base_reconstruction));
                base=archive.(baseKey);
                if isfield(obj.reconstruction,"points_to_add") %#ok<ALIGN>
                    base.points_to_add=obj.reconstruction.points_to_add;
                elseif isfield(base,"points_to_add"),base=rmfield(base,"points_to_add");end
                if isfield(obj.reconstruction,"points_to_remove")
                    base.points_to_remove=obj.reconstruction.points_to_remove;
                elseif isfield(base,"points_to_remove")
                    base=rmfield(base,"points_to_remove");
                end
                obj.reconstruction=base;
            end
            obj.reconstruction_json=obj.reconstruction;
            obj.trans_matrix=obj.reconstruction.transformation_matrix;
            hkl=[1,0,0];
            if isfield(obj.reconstruction,"miller_index")
                hkl=obj.reconstruction.miller_index;
            end
            obj.slabgen_params=struct("initial_structure",initialStructure, ...
                "miller_index",hkl,"min_slab_size",minSlabSize, ...
                "min_vacuum_size",minVacuumSize);
        end
        function slabs=get_unreconstructed_slabs(obj)
            parameters=struct("center_slab",false, ...
                "max_normal_search",[]);
            if isfield(obj.reconstruction,"SlabGenerator_parameters")
                source=obj.reconstruction.SlabGenerator_parameters;
                names=fieldnames(source);
                for index=1:numel(names)
                    if isfield(parameters,names{index})
                        parameters.(names{index})=source.(names{index});
                    end
                end
            end
            generator=kssolv.analysis.matgenlab.core.SlabGenerator( ...
                obj.initial_structure,obj.slabgen_params.miller_index, ...
                obj.min_slab_size,obj.min_vacuum_size, ...
                center_slab=parameters.center_slab, ...
                max_normal_search=parameters.max_normal_search);
            slabs=generator.get_slabs();
            for index=1:numel(slabs)
                slabs{index}=slabs{index}.make_supercell(obj.trans_matrix);
            end
        end
        function slabs=build_slabs(obj)
            slabs=obj.get_unreconstructed_slabs();
            for index=1:numel(slabs)
                slab=slabs{index};spacing= ...
                    kssolv.analysis.matgenlab.core.get_d(slab);
                [~,topIndex]=max(slab.frac_coords(:,3));
                topCartesian=slab.sites{topIndex}.coords;
                if isfield(obj.reconstruction,"points_to_remove")
                    points=obj.reconstruction.points_to_remove;
                    for pointIndex=1:size(points,1)
                        point=points(pointIndex,:);
                        cart=[topCartesian(1:2), ...
                            topCartesian(3)+point(3)*spacing];
                        fractional=slab.lattice.get_fractional_coords(cart);
                        point(3)=fractional(3);
                        target=slab.lattice.get_cartesian_coords(point);
                        distances=zeros(slab.num_sites,1);
                        for siteIndex=1:slab.num_sites
                            distances(siteIndex)= ...
                                slab(siteIndex).distance_from_point(target);
                        end
                        [~,nearest]=min(distances);
                        slab=slab.symmetrically_remove_atoms(nearest);
                    end
                end
                if isfield(obj.reconstruction,"points_to_add")
                    points=obj.reconstruction.points_to_add;
                    for pointIndex=1:size(points,1)
                        point=points(pointIndex,:);
                        cart=[topCartesian(1:2), ...
                            topCartesian(3)+point(3)*spacing];
                        fractional=slab.lattice.get_fractional_coords(cart);
                        point(3)=fractional(3);
                        slab=slab.symmetrically_add_atom( ...
                            slab.sites{1}.species,point);
                    end
                end
                slab.reconstruction=obj.reconstruction_name;
                slab.oriented_unit_cell= ...
                    slab.oriented_unit_cell.make_supercell( ...
                    obj.trans_matrix);
                slabs{index}=slab;
            end
        end
    end
end
