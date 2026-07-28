classdef MoleculeStructureComparatorTest < matlab.unittest.TestCase
    methods (Test)
        function connectivityComparison(testCase)
            comparator = kssolv.analysis.matgenlab.core. ...
                MoleculeStructureComparator();
            water1 = kssolv.analysis.matgenlab.core.Molecule( ...
                {"O", "H", "H"}, [0, 0, 0; 0.96, 0, 0; -0.24, 0.93, 0]);
            water2 = kssolv.analysis.matgenlab.core.Molecule( ...
                {"O", "H", "H"}, [2, 1, 0; 2.96, 1, 0; 1.76, 1.93, 0]);
            broken = kssolv.analysis.matgenlab.core.Molecule( ...
                {"O", "H", "H"}, [0, 0, 0; 4, 0, 0; -0.24, 0.93, 0]);
            testCase.verifyTrue(comparator.are_equal(water1, water2));
            testCase.verifyFalse(comparator.are_equal(water1, broken));
        end

        function oneThreeBondsUseZeroBasedIndices(testCase)
            result = kssolv.analysis.matgenlab.core. ...
                MoleculeStructureComparator.get_13_bonds([0, 1; 1, 2]);
            testCase.verifyEqual(result, [0, 2]);
        end

        function msonRoundTrip(testCase)
            comparator = kssolv.analysis.matgenlab.core. ...
                MoleculeStructureComparator(0.2, [], [0, 1], 0.7);
            restored = kssolv.analysis.matgenlab.core. ...
                MoleculeStructureComparator.from_dict(comparator.as_dict());
            testCase.verifyEqual(restored.bond_length_cap, 0.2);
            testCase.verifyEqual(restored.priority_bonds, [0, 1]);
            testCase.verifyEqual(restored.priority_cap, 0.7);
        end
    end
end
