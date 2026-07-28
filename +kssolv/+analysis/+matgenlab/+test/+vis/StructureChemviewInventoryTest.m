classdef StructureChemviewInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function viewerContainsBondsSpheresAndCell(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(4);
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, {"C", "H", "H"}, ...
                [0, 0, 0; .25, 0, 0; .75, 0, 0]);
            viewer = kssolv.analysis.matgenlab.vis.structure_chemview. ...
                quick_view(structure);
            testCase.verifyEqual(viewer.coordinates, ...
                structure.cart_coords, AbsTol = 1e-14);
            testCase.verifyEqual(viewer.topology.atom_types, ...
                ["C", "H", "H"]);
            testCase.verifyEqual(viewer.topology.bonds, [0, 1]);
            testCase.verifyEqual(numel(viewer.representations), 5);
            testCase.verifyEqual(viewer.representations{1}.type, ...
                "ball_and_sticks");
            testCase.verifyEqual(viewer.representations{5}.type, "lines");
            testCase.verifyEqual(size(viewer.representations{5}. ...
                options.startCoords), [12, 3]);
        end

        function optionsDisableBondsAndBox(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 5, {"He"}, [0, 0, 0]);
            viewer = kssolv.analysis.matgenlab.vis.structure_chemview. ...
                quick_view(structure, false, false, [], false);
            testCase.verifyEmpty(viewer.topology.bonds);
            testCase.verifyEqual(numel(viewer.representations), 1);
            testCase.verifyEqual(viewer.representations{1}.type, "spheres");
        end

        function supercellTransformIsApplied(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 3, {"Li"}, [0, 0, 0]);
            viewer = kssolv.analysis.matgenlab.vis.structure_chemview. ...
                quick_view(structure, false, false, [2, 1, 1], false);
            testCase.verifyEqual(size(viewer.coordinates, 1), 2);
            testCase.verifyEqual(viewer.topology.atom_types, ["Li", "Li"]);
        end
    end
end
