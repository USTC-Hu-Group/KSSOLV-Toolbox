classdef Spglib
    %SPGLIB An interface of spglib library.

    methods(Static)
        function version = getVersion(option)
            arguments
                option (1,1) string {mustBeMember(option, ["full", "major", "minor", "micro", "default"])} = "default"
            end

            switch option
                case "full"
                    version = kssolv.analysis.spglib.symspg('spg_get_version_full');
                case "major"
                    version = kssolv.analysis.spglib.symspg('spg_get_major_version');
                case "minor"
                    version = kssolv.analysis.spglib.symspg('spg_get_minor_version');
                case "micro"
                    version = kssolv.analysis.spglib.symspg('spg_get_micro_version');
                otherwise
                    version = kssolv.analysis.spglib.symspg('spg_get_version');
            end
        end

        function commit = getCommit()
            commit = kssolv.analysis.spglib.symspg('spg_get_commit');
        end

        function error_code = getErrorCode()
            error_code = kssolv.analysis.spglib.symspg('spg_get_error_code');
            error_code = kssolv.analysis.spglib.SpglibError(error_code);
        end

        function error_message = getErrorMessage(error_code)
            arguments
                error_code kssolv.analysis.spglib.SpglibError = 0
            end

            error_message = kssolv.analysis.spglib.symspg('spg_get_error_message', double(error_code));
        end
        
        function dataset = getDataset(lattice, position, types, num_atom, symprec, angle_tolerance)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) double
                num_atom (1, 1) uint16
                symprec (1, 1) double
                angle_tolerance double = []
            end

            if isempty(angle_tolerance)
                dataset = kssolv.analysis.spglib.symspg('spg_get_dataset', lattice', position, types, num_atom, symprec);
            else
                dataset = kssolv.analysis.spglib.symspg('spgat_get_dataset', lattice', position, types, num_atom, symprec, angle_tolerance);
            end
            dataset = kssolv.analysis.spglib.Spglib.normalizeDatasetLattices(dataset);
        end

        function dataset = getMagneticDataset(lattice, position, types, tensors, tensor_rank, num_atom, is_axial, symprec, angle_tolerance, mag_symprec)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) double
                tensors double
                tensor_rank (1, 1) uint16
                num_atom (1, 1) uint16
                is_axial (1, 1) logical
                symprec (1, 1) double
                angle_tolerance double = []
                mag_symprec double = []
            end

            tensors = reshape(tensors.', [], 1);
            if isempty(angle_tolerance)
                dataset = kssolv.analysis.spglib.symspg('spg_get_magnetic_dataset', lattice', position, types, tensors, tensor_rank, num_atom, is_axial, symprec);
            else
                if isempty(mag_symprec)
                    error('Spglib:getMagneticDataset', "'mag_symprec' must be used together with 'angle_tolerance'");
                else
                    dataset = kssolv.analysis.spglib.symspg('spgms_get_magnetic_dataset', lattice', position, types, tensors, tensor_rank, num_atom, is_axial, symprec, angle_tolerance, mag_symprec);
                end
            end
            dataset = kssolv.analysis.spglib.Spglib.normalizeDatasetLattices(dataset);
        end

        function dataset = getDatasetWithHallNumber(lattice, position, types, num_atom, hall_number, symprec, angle_tolerance)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) double
                num_atom (1, 1) uint16
                hall_number (1,1) int16 {mustBeGreaterThanOrEqual(hall_number, 1), mustBeLessThanOrEqual(hall_number, 530)}
                symprec (1, 1) double
                angle_tolerance double = []
            end

            if isempty(angle_tolerance)
                dataset = kssolv.analysis.spglib.symspg('spg_get_dataset_with_hall_number', lattice', position, types, num_atom, hall_number, symprec);
            else
                dataset = kssolv.analysis.spglib.symspg('spgat_get_dataset_with_hall_number', lattice', position, types, num_atom, hall_number, symprec, angle_tolerance);
            end
            dataset = kssolv.analysis.spglib.Spglib.normalizeDatasetLattices(dataset);
        end

        function [rotations, translations, equivalent_atoms, num_operations] = getSymmetryWithCollinearSpin(max_size, lattice, position, types, spins, num_atom, symprec, angle_tolerance, mag_symprec)
            arguments
                max_size (1, 1) uint16
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) double
                spins double
                num_atom (1, 1) uint16
                symprec (1, 1) double
                angle_tolerance double = []
                mag_symprec double = []
            end

            if isempty(angle_tolerance)
                [rotations, translations, equivalent_atoms, num_operations] = kssolv.analysis.spglib.symspg('spg_get_symmetry_with_collinear_spin', max_size, lattice', position, types, spins, num_atom, symprec);
            else
                if isempty(mag_symprec)
                    [rotations, translations, equivalent_atoms, num_operations] = kssolv.analysis.spglib.symspg('spgat_get_symmetry_with_collinear_spin', max_size, lattice', position, types, spins, num_atom, symprec, angle_tolerance);
                else
                    [rotations, translations, equivalent_atoms, num_operations] = kssolv.analysis.spglib.symspg('spgms_get_symmetry_with_collinear_spin', max_size, lattice', position, types, spins, num_atom, symprec, angle_tolerance, mag_symprec);
                end
            end
        end

        function [rotations, translations, equivalent_atoms, primitive_lattice, spin_flips, num_operations] = getSymmetryWithSiteTensors(max_size, lattice, position, types, tensors, tensor_rank, num_atom, with_time_reversal, is_axial, symprec, angle_tolerance, mag_symprec)
            arguments
                max_size (1, 1) uint16
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) double
                tensors (:, :) double
                tensor_rank (1, 1) uint16
                num_atom (1, 1) uint16
                with_time_reversal (1, 1) logical
                is_axial (1, 1) logical
                symprec (1, 1) double
                angle_tolerance double = []
                mag_symprec double = []
            end

            tensors = reshape(tensors.', [], 1);
            if isempty(angle_tolerance)
                [rotations, translations, equivalent_atoms, primitive_lattice, spin_flips, num_operations] = kssolv.analysis.spglib.symspg('spg_get_symmetry_with_site_tensors', max_size, lattice', position, types, tensors, tensor_rank, num_atom, with_time_reversal, is_axial, symprec);
            else
                if isempty(mag_symprec)
                    [rotations, translations, equivalent_atoms, primitive_lattice, spin_flips, num_operations] = kssolv.analysis.spglib.symspg('spgat_get_symmetry_with_site_tensors', max_size, lattice', position, types, tensors, tensor_rank, num_atom, with_time_reversal, is_axial, symprec, angle_tolerance);
                else
                    [rotations, translations, equivalent_atoms, primitive_lattice, spin_flips, num_operations] = kssolv.analysis.spglib.symspg('spgms_get_symmetry_with_site_tensors', max_size, lattice', position, types, tensors, tensor_rank, num_atom, with_time_reversal, is_axial, symprec, angle_tolerance, mag_symprec);
                end
            end
            primitive_lattice = primitive_lattice';
        end

        function spacegroup_type = getSpacegroupTypeFromSymmetry(rotation, translation, num_operations, lattice, symprec)
            arguments
                rotation (:, 3, 3) int32
                translation (:, 3) double
                num_operations (1, 1) int32
                lattice (3, 3) double
                symprec (1, 1) double
            end

            spacegroup_type = kssolv.analysis.spglib.symspg('spg_get_spacegroup_type_from_symmetry', rotation, translation, num_operations, lattice', symprec);
        end

        function magnetic_spacegroup_type = getMagneticSpacegroupTypeFromSymmetry(rotation, translation, time_reversals, num_operations, lattice, symprec)
            arguments
                rotation (:, 3, 3) int32
                translation (:, 3) double
                time_reversals (:, 1) int32
                num_operations (1, 1) int32
                lattice (3, 3) double
                symprec (1, 1) double
            end

            magnetic_spacegroup_type = kssolv.analysis.spglib.symspg('spg_get_magnetic_spacegroup_type_from_symmetry', rotation, translation, time_reversals, num_operations, lattice', symprec);
        end

        function [symbol, trans_mat, result] = getPointgroup(rotations, num_rotations)
            arguments
                rotations (:, 3, 3) int32
                num_rotations (1, 1) int32
            end

            [symbol, trans_mat, result] = kssolv.analysis.spglib.symspg('spg_get_pointgroup', rotations, num_rotations);
        end

        function [rotations, translations] = getSymmetryFromDatabase(hall_number)
            arguments
                hall_number (1, 1) int32 {mustBeGreaterThanOrEqual(hall_number, 1), mustBeLessThanOrEqual(hall_number, 530)}
            end

            [rotations, translations] = kssolv.analysis.spglib.symspg('spg_get_symmetry_from_database', hall_number);
        end

        function [rotations, translations, time_reversals] = getMagneticSymmetryFromDatabase(uni_number, hall_number)
            arguments
                uni_number (1, 1) int32 {mustBeGreaterThanOrEqual(uni_number, 1), mustBeLessThanOrEqual(uni_number, 1651)}
                hall_number (1, 1) int32 {mustBeGreaterThanOrEqual(hall_number, 1), mustBeLessThanOrEqual(hall_number, 530)}
            end

            [rotations, translations, time_reversals] = kssolv.analysis.spglib.symspg('spg_get_magnetic_symmetry_from_database', uni_number, hall_number);
        end

        function spacegroup = getSpacegroupType(hall_number)
            arguments
                hall_number (1, 1) int32 {mustBeGreaterThanOrEqual(hall_number, 1), mustBeLessThanOrEqual(hall_number, 530)}
            end

            spacegroup = kssolv.analysis.spglib.symspg('spg_get_spacegroup_type', hall_number);
        end

        function spacegroup = getMagneticSpacegroupType(uni_number)
            arguments
                uni_number (1, 1) int32 {mustBeGreaterThanOrEqual(uni_number, 1), mustBeLessThanOrEqual(uni_number, 1651)}
            end

            spacegroup = kssolv.analysis.spglib.symspg('spg_get_magnetic_spacegroup_type', uni_number);
        end

        function [lattice, position, types, num_primitive_atom] = standardizeCell(lattice, position, types, num_atom, to_primitive, no_idealize, symprec, angle_tolerance)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) int32
                num_atom (1, 1) int32 {mustBePositive}
                to_primitive (1, 1) logical
                no_idealize (1, 1) logical
                symprec (1, 1) double {mustBePositive}
                angle_tolerance double = []
            end

            if isempty(angle_tolerance)
                [lattice, position, types, num_primitive_atom] = kssolv.analysis.spglib.symspg('spg_standardize_cell', lattice', position, types, num_atom, to_primitive, no_idealize, symprec);
            else
                [lattice, position, types, num_primitive_atom] = kssolv.analysis.spglib.symspg('spgat_standardize_cell', lattice', position, types, num_atom, to_primitive, no_idealize, symprec, angle_tolerance);
            end
            lattice = lattice';
        end
    
        function [lattice, position, types, num_primitive_atom] = findPrimitive(lattice, position, types, num_atom, symprec, angle_tolerance)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) int32
                num_atom (1, 1) int32 {mustBePositive}
                symprec (1, 1) double {mustBePositive}
                angle_tolerance double = []
            end

            if isempty(angle_tolerance)
                [lattice, position, types, num_primitive_atom] = kssolv.analysis.spglib.symspg('spg_find_primitive', lattice', position, types, num_atom, symprec);
            else
                [lattice, position, types, num_primitive_atom] = kssolv.analysis.spglib.symspg('spgat_find_primitive', lattice', position, types, num_atom, symprec, angle_tolerance);
            end
            lattice = lattice';
        end
    
        function [lattice, position, types, num_atom_bravais] = refineCell(lattice, position, types, num_atom, symprec, angle_tolerance)
            arguments
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) int32
                num_atom (1, 1) int32 {mustBePositive}
                symprec (1, 1) double {mustBePositive}
                angle_tolerance double = []
            end

            if isempty(angle_tolerance)
                [lattice, position, types, num_atom_bravais] = kssolv.analysis.spglib.symspg('spg_refine_cell', lattice', position, types, num_atom, symprec);
            else
                [lattice, position, types, num_atom_bravais] = kssolv.analysis.spglib.symspg('spgat_refine_cell', lattice', position, types, num_atom, symprec, angle_tolerance);
            end
            lattice = lattice';
        end
    
        function [lattice, result] = delaunayReduce(lattice, symprec)
            arguments
                lattice (3, 3) double
                symprec (1, 1) double {mustBePositive}
            end

            [lattice, result] = kssolv.analysis.spglib.symspg('spg_delaunay_reduce', lattice', symprec);
            lattice = lattice';
        end
    
        function grid_point_index = getGridPointFromAddress(grid_address, mesh)
            arguments
                grid_address (1, 3) int32
                mesh (1, 3) int32 {mustBePositive}
            end

            grid_point_index = kssolv.analysis.spglib.symspg('spg_get_grid_point_from_address', grid_address, mesh);
        end
    
        function dense_grid_point_index = getDenseGridPointFromAddress(grid_address, mesh)
            arguments
                grid_address (1, 3) int32
                mesh (1, 3) int32 {mustBePositive}
            end

            dense_grid_point_index = kssolv.analysis.spglib.symspg('spg_get_dense_grid_point_from_address', grid_address, mesh);
        end
    
        function [grid_address, ir_mapping_table, num_ir_kpoints] = getIrReciprocalMesh(mesh, is_shift, is_time_reversal, lattice, position, types, num_atom, symprec)
            arguments
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0,1])}
                is_time_reversal (1, 1) logical
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) int32
                num_atom (1, 1) int32 {mustBePositive}
                symprec (1, 1) double {mustBePositive}
            end

            [grid_address, ir_mapping_table, num_ir_kpoints] = kssolv.analysis.spglib.symspg('spg_get_ir_reciprocal_mesh', mesh, is_shift, is_time_reversal, lattice', position, types, num_atom, symprec);
        end

        function [grid_address, ir_mapping_table, num_ir_kpoints] = getDenseIrReciprocalMesh(mesh, is_shift, is_time_reversal, lattice, position, types, num_atom, symprec)
            arguments
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0,1])}
                is_time_reversal (1, 1) logical
                lattice (3, 3) double
                position (:, 3) double
                types (:, 1) int32
                num_atom (1, 1) int32 {mustBePositive}
                symprec (1, 1) double {mustBePositive}
            end

            [grid_address, ir_mapping_table, num_ir_kpoints] = kssolv.analysis.spglib.symspg('spg_get_dense_ir_reciprocal_mesh', mesh, is_shift, is_time_reversal, lattice', position, types, num_atom, symprec);
        end
    
        function [grid_address, ir_mapping_table, num_ir_kpoints] = getStabilizedReciprocalMesh(mesh, is_shift, is_time_reversal, num_rotations, rotations, num_qpoints, qpoints)
            arguments
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
                is_time_reversal (1, 1) logical
                num_rotations (1, 1) int32 {mustBePositive}
                rotations (:, 3, 3) int32
                num_qpoints (1, 1) int32 {mustBePositive}
                qpoints (:, 3) double
            end

            assert(size(rotations, 1) == num_rotations, 'The size of rotations does not match num_rot.');
            assert(size(qpoints, 1) == num_qpoints, 'The size of qpoints does not match num_q.');

            [grid_address, ir_mapping_table, num_ir_kpoints] = kssolv.analysis.spglib.symspg('spg_get_stabilized_reciprocal_mesh', mesh, is_shift, is_time_reversal, num_rotations, rotations, num_qpoints, qpoints);
        end

        function [grid_address, ir_mapping_table, num_ir_kpoints] = getDenseStabilizedReciprocalMesh(mesh, is_shift, is_time_reversal, num_rotations, rotations, num_qpoints, qpoints)
            arguments
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
                is_time_reversal (1, 1) logical
                num_rotations (1, 1) int32 {mustBePositive}
                rotations (:, 3, 3) int32
                num_qpoints (1, 1) int32 {mustBePositive}
                qpoints (:, 3) double
            end

            assert(size(rotations, 1) == num_rotations, 'The size of rotations does not match num_rot.');
            assert(size(qpoints, 1) == num_qpoints, 'The size of qpoints does not match num_q.');

            [grid_address, ir_mapping_table, num_ir_kpoints] = kssolv.analysis.spglib.symspg('spg_get_dense_stabilized_reciprocal_mesh', mesh, is_shift, is_time_reversal, num_rotations, rotations, num_qpoints, qpoints);
        end
    
        function grid_points = getDenseGridPointsByRotations(address_orig, num_rot, rot_reciprocal, mesh, is_shift)
            arguments
                address_orig (1, 3) int32
                num_rot (1, 1) int32 {mustBePositive}
                rot_reciprocal (:, 3, 3) int32
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
            end

            assert(size(rot_reciprocal, 1) == num_rot, 'The size of rot_reciprocal does not match num_rot.');

            grid_points = kssolv.analysis.spglib.symspg('spg_get_dense_grid_points_by_rotations', address_orig, num_rot, rot_reciprocal, mesh, is_shift);
        end

        function rot_grid_points = getDenseBZGridPointsByRotations(address_orig, num_rot, rot_reciprocal, mesh, is_shift, bz_map)
            arguments
                address_orig (1, 3) int32
                num_rot (1, 1) int32 {mustBePositive}
                rot_reciprocal (:, 3, 3) int32
                mesh (1, 3) int32 {mustBePositive}
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
                bz_map (:, 1) uint64
            end

            assert(size(rot_reciprocal, 1) == num_rot, 'The size of rot_reciprocal does not match num_rot.');
            assert(numel(bz_map) == prod(mesh * 2), 'The size of bz_map does not match prod(mesh * 2).');

            rot_grid_points = kssolv.analysis.spglib.symspg('spg_get_dense_BZ_grid_points_by_rotations', address_orig, num_rot, rot_reciprocal, mesh, is_shift, bz_map);
        end
    
        function [bz_grid_address, bz_map, num_ir_grid_points] = relocateBZGridAddress(grid_address, mesh, rec_lattice, is_shift)
            arguments
                grid_address (:, 3) int32
                mesh (1, 3) int32 {mustBePositive}
                rec_lattice (3, 3) double
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
            end

            assert(size(grid_address, 1) == prod(mesh), 'The size of grid_address does not match the number of grid points defined by mesh.');

            [bz_grid_address, bz_map, num_ir_grid_points] = kssolv.analysis.spglib.symspg('spg_relocate_BZ_grid_address', grid_address, mesh, rec_lattice', is_shift);
        end

        function [bz_grid_address, bz_map, num_ir_grid_points] = relocateDenseBZGridAddress(grid_address, mesh, rec_lattice, is_shift)
            arguments
                grid_address (:, 3) int32
                mesh (1, 3) int32 {mustBePositive}
                rec_lattice (3, 3) double
                is_shift (1, 3) int32 {mustBeMember(is_shift, [0, 1])}
            end

            assert(size(grid_address, 1) == prod(mesh), 'The size of grid_address does not match the number of grid points defined by mesh.');

            [bz_grid_address, bz_map, num_ir_grid_points] = kssolv.analysis.spglib.symspg('spg_relocate_dense_BZ_grid_address', grid_address, mesh, rec_lattice', is_shift);
        end

        function [lattice, result] = niggliReduce(lattice, symprec)
            arguments
                lattice (3, 3) double
                symprec (1, 1) double {mustBePositive}
            end

            [lattice, result] = kssolv.analysis.spglib.symspg('spg_niggli_reduce', lattice', symprec);
            lattice = lattice';
        end
    end

    methods(Static, Access=private)
        function dataset = normalizeDatasetLattices(dataset)
            dataset.std_lattice = dataset.std_lattice';
            dataset.primitive_lattice = dataset.primitive_lattice';
        end
    end
end
