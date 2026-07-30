classdef CommonIOTest < matlab.unittest.TestCase
    methods (Test)
        function volumetricAlgorithmsMatchFrozenOracle(testCase)
            structure = sampleStructure();
            total = reshape(1:24, [2, 3, 4]);
            difference = reshape(linspace(-1, 1, 24), [2, 3, 4]);
            volume = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData( ...
                    structure, struct("total", total, ...
                    "diff", difference));
            testCase.verifyEqual(volume.get_axis_grid(1), [0, 2]);
            testCase.verifyEqual(volume.spin_data.up, ...
                0.5 * (total + difference), AbsTol = 1e-14);
            testCase.verifyEqual(volume.get_average_along_axis(1), ...
                reshape(mean(mean(total, 2), 3), 1, []));
            testCase.verifyEqual(volume.value_at(0.5, 0.5, 0.5), ...
                12.5, AbsTol = 1e-14);
            slice = volume.linear_slice([0, 0, 0], [1, 1, 1], 3);
            testCase.verifyEqual(slice, [1; 12.5; 24], AbsTol = 1e-14);
            scaled = volume.copy();
            scaled = scaled.scale(2);
            combined = volume.linear_add(scaled, -0.5);
            testCase.verifyEqual(combined.data.total, zeros(2, 3, 4));
        end

        function hdf5RoundTripUsesUpstreamSchema(testCase)
            structure = sampleStructure();
            total = reshape(1:24, [2, 3, 4]);
            difference = -total;
            volume = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData( ...
                    structure, struct("total", total, ...
                    "diff", difference), ...
                    data_aug = struct("total", total / 10));
            volume.name = "oracle-grid";
            path = string(tempname) + ".h5";
            cleanup = onCleanup(@() deleteIfPresent(path));
            volume.to_hdf5(path);
            info = h5info(path);
            testCase.verifyTrue(any(string({info.Groups.Name}) == "/vdata"));
            restored = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData. ...
                from_hdf5(path);
            testCase.verifyEqual(restored.structure.lattice.matrix, ...
                structure.lattice.matrix, AbsTol = 1e-14);
            testCase.verifyEqual(restored.structure.frac_coords, ...
                structure.frac_coords, AbsTol = 1e-14);
            testCase.verifyEqual(restored.data.total, total);
            testCase.verifyEqual(restored.data.diff, difference);
            testCase.verifyEqual(restored.data_aug.total, total / 10);
            testCase.verifyEqual(restored.name, "oracle-grid");
            clear cleanup
        end

        function officialCubeFixturesMatchFrozenOracle(testCase)
            small = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData. ...
                from_cube(commonFixture("cube-gh-2817.xyz"));
            testCase.verifyEqual(small.structure.num_sites, 3);
            testCase.verifyEqual(small.structure.volume, ...
                0.02700002317874615, AbsTol = 1e-13);
            testCase.verifyEqual(size(small.data.total), [2, 2, 2]);
            testCase.verifyEqual(sum(small.data.total, "all"), ...
                2.91539e-5, AbsTol = 1e-15);
            path = string(tempname) + ".cube.gz";
            cleanup = onCleanup(@() deleteIfPresent(path));
            small.to_cube(path, "round trip");
            restored = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData. ...
                from_cube(path);
            testCase.verifyEqual(restored.structure.lattice.matrix, ...
                small.structure.lattice.matrix, AbsTol = 1e-6);
            testCase.verifyEqual(restored.structure.cart_coords, ...
                small.structure.cart_coords, AbsTol = 1e-12);
            testCase.verifyEqual(restored.data.total, ...
                small.data.total, AbsTol = 1e-12);
            clear cleanup

            shifted = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData. ...
                from_cube(commonFixture("boltztrap_BZ.cube"));
            testCase.verifyEqual(shifted.structure.num_sites, 96);
            testCase.verifyEqual(shifted.structure(1).specie.symbol, "Fe");
            % KSSOLV preserves the Cube grid origin explicitly and keeps
            % atom coordinates in the source Cartesian frame. Translating
            % both into pymatgen's origin-zero frame must reproduce the
            % upstream frozen fractional-coordinate oracle.
            translated = shifted.structure.cart_coords(1, :) - ...
                shifted.grid_origin;
            upstreamFractional = ...
                shifted.structure.lattice.get_fractional_coords( ...
                translated);
            testCase.verifyEqual(upstreamFractional, ...
                [0.165289534258174, 0.661155899945970, ...
                0.246153905630835], AbsTol = 1e-6);
        end

        function pmgDirectoryIsRecursiveAndLazy(testCase)
            folder = string(tempname);
            mkdir(folder);
            mkdir(fullfile(folder, "nested"));
            cleanup = onCleanup(@() removeFolder(folder));
            structure = sampleStructure();
            kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                structure).write_file(fullfile(folder, "nested", "POSCAR"));
            fid = fopen(fullfile(folder, "notes.txt"), "w", "n", "UTF-8");
            fprintf(fid, "hello\n");
            fclose(fid);
            directory = ...
                kssolv.analysis.matgenlab.io.common.PMGDir(folder);
            testCase.verifyEqual(length(directory), 2);
            testCase.verifyTrue(directory.contains("nested/POSCAR"));
            parsed = directory("nested/POSCAR");
            testCase.verifyClass(parsed, ...
                "kssolv.analysis.matgenlab.io.vasp.Poscar");
            testCase.verifyWarning(@() directory("notes.txt"), ...
                "KSSOLV:Matgenlab:PMGDir:NoParser");
            testCase.verifyEqual(strtrim(directory("notes.txt")), "hello");
            matched = directory.get_files_by_name("POSCAR");
            testCase.verifyEqual(double(matched.Count), 1);
            directory.reset();
            testCase.verifyEqual(length(directory), 2);
            clear cleanup
        end
    end
end

function structure = sampleStructure()
structure = kssolv.analysis.matgenlab.core.Structure( ...
    kssolv.analysis.matgenlab.core.Lattice.orthorhombic(4, 5, 6), ...
    {"Si", "O"}, [0, 0, 0; 0.25, 0.5, 0.75]);
end

function path = commonFixture(name)
path = fullfile(fileparts(mfilename("fullpath")), ...
    "+fixtures", "+common", name);
end

function deleteIfPresent(path)
if isfile(path), delete(path); end
end

function removeFolder(path)
if isfolder(path), rmdir(path, "s"); end
end
