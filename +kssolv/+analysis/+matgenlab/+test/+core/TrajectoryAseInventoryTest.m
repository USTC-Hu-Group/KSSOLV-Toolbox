classdef TrajectoryAseInventoryTest < matlab.unittest.TestCase
    methods (TestMethodTeardown)
        function clearTransport(~)
            kssolv.analysis.matgenlab.core.Trajectory. ...
                set_ase_transport([]);
        end
    end

    methods (Test)
        function periodicNeutralAseRoundTripPreservesProperties(testCase)
            atoms1 = aseFrame([0, 0, 0; 1, 0, 0], eye(3) * 3, ...
                1.25, [1, 2], 300);
            atoms2 = aseFrame([0.1, 0, 0; 1.1, 0, 0], eye(3) * 3, ...
                1.5, [3, 4], 350);
            trajectory = kssolv.analysis.matgenlab.core.Trajectory. ...
                from_ase({atoms1, atoms2});
            testCase.verifyEqual(length(trajectory), 2);
            testCase.verifyTrue(trajectory.constant_lattice);
            testCase.verifyEqual(trajectory.frame_properties{1}.energy, 1.25);
            testCase.verifyEqual(trajectory.frame_properties{2}.forces, [3, 4]);
            testCase.verifyEqual(trajectory.frame_properties{2}.temperature, 350);
            velocityCells = trajectory.site_properties{1}.velocities;
            testCase.verifyEqual(vertcat(velocityCells{:}), ...
                repmat([1, 2, 3], 2, 1));
            restored = trajectory.to_ase();
            testCase.verifyEqual(numel(restored), 2);
            testCase.verifyEqual(restored{1}.calc.results.energy, 1.25);
            testCase.verifyEqual(restored{2}.positions, atoms2.positions, ...
                AbsTol = 1e-14);
        end

        function latticeVariationIsDetected(testCase)
            first = aseFrame([0, 0, 0], eye(3), 1, 2, 100);
            second = aseFrame([0, 0, 0], eye(3) * 2, 2, 3, 200);
            trajectory = kssolv.analysis.matgenlab.core.Trajectory. ...
                from_ase({first, second});
            testCase.verifyFalse(trajectory.constant_lattice);
            testCase.verifyEqual(size(trajectory.lattice), [2, 3, 3]);
        end

        function fileBoundaryRequiresOrUsesExplicitTransport(testCase)
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.Trajectory. ...
                from_ase("input.traj"), ...
                "KSSOLV:Matgenlab:Trajectory:AseRequired");
            trajectory = kssolv.analysis.matgenlab.core.Trajectory. ...
                from_ase({aseFrame([0, 0, 0], eye(3), 1, 2, 100)});
            testCase.verifyError(@() trajectory.to_ase([], "output.traj"), ...
                "KSSOLV:Matgenlab:Trajectory:AseRequired");
            kssolv.analysis.matgenlab.core.Trajectory. ...
                set_ase_transport(@transport);
            loaded = kssolv.analysis.matgenlab.core.Trajectory. ...
                from_ase("input.traj");
            testCase.verifyEqual(length(loaded), 1);
            written = trajectory.to_ase([], "output.traj");
            testCase.verifyEqual(numel(written), 1);
        end
    end
end

function atoms = aseFrame(positions, cellMatrix, energy, forces, temperature)
atoms = struct("symbols", {repmat({"H"}, 1, size(positions, 1))}, ...
    "positions", positions, "cell", cellMatrix, ...
    "pbc", [true, true, true], ...
    "arrays", struct(), ...
    "velocities", repmat([1, 2, 3], size(positions, 1), 1), ...
    "info", struct("temperature", temperature), ...
    "calc", struct("results", struct("energy", energy, ...
    "forces", forces, "stress", zeros(1, 6))));
end

function output = transport(action, filename, payload)
if action == "read"
    output = {aseFrame([0, 0, 0], eye(3), 1, 2, 100)};
elseif action == "write"
    assert(filename == "output.traj");
    assert(iscell(payload));
    output = [];
else
    error("unexpected action");
end
end
