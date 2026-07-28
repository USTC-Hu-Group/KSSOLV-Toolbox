classdef TrajectoryTest < matlab.unittest.TestCase
    methods (Test)
        function structureFramesAndDisplacements(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(3);
            structures = {
                kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, ["Si", "Si"], [0,0,0; 0.5,0.5,0.5])
                kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, ["Si", "Si"], [0.1,0.1,0.1; 0.6,0.6,0.6])
                };
            trajectory = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_structures( ...
                    structures);
            testCase.verifyEqual(length(trajectory), 2);
            testCase.verifyTrue(trajectory(2) == structures{2});
            trajectory = trajectory.to_displacements();
            testCase.verifyTrue(trajectory.coords_are_displacement);
            trajectory = trajectory.to_positions();
            testCase.verifyTrue(trajectory(2) == structures{2});
        end

        function moleculeSliceAndExtend(testCase)
            molecules = {
                kssolv.analysis.matgenlab.core.Molecule( ...
                    ["C", "O"], [0,0,0; 1.2,0,0])
                kssolv.analysis.matgenlab.core.Molecule( ...
                    ["C", "O"], [0.1,0,0; 1.3,0,0])
                };
            trajectory = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_molecules( ...
                    molecules, time_step = 1);
            sliced = trajectory([1, 2]);
            testCase.verifyEqual(length(sliced), 2);
            extended = trajectory.extend(trajectory);
            testCase.verifyEqual(length(extended), 4);
        end

        function serializationRoundTrip(testCase)
            coords = zeros(2, 1, 3);
            coords(2, 1, :) = [0.1, 0.2, 0.3];
            original = kssolv.analysis.matgenlab.core.Trajectory( ...
                {"He"}, coords, charge = 0);
            restored = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_dict( ...
                    original.as_dict());
            testCase.verifyEqual(restored.coords, original.coords);
            testCase.verifyEqual(restored.get_molecule(2).cart_coords, ...
                [0.1, 0.2, 0.3]);
        end

        function xdatcarRoundTrip(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(3);
            structures = {
                kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, ["Si", "O"], [0, 0, 0; 0.5, 0.5, 0.5])
                kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, ["Si", "O"], [0.1, 0, 0; 0.6, 0.5, 0.5])
                };
            original = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_structures( ...
                    structures);
            filename = string(tempname) + ".XDATCAR";
            cleanup = onCleanup(@() deleteIfPresent(filename));
            original.write_Xdatcar(filename, "SiO2", 8);
            restored = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_file(filename);
            testCase.verifyEqual(restored.coords, original.coords, ...
                "AbsTol", 1e-8);
            testCase.verifyEqual(string(restored.species), ...
                string(original.species));
            clear cleanup

            function deleteIfPresent(path)
                if isfile(path), delete(path); end
            end
        end
    end
end
