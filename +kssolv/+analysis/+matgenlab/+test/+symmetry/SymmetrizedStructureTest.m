classdef SymmetrizedStructureTest < matlab.unittest.TestCase
    methods (Test)
        function groupingLookupAndSerialization(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), ...
                ["Fe", "Fe"], [0, 0, 0; 0.5, 0.5, 0.5]);
            value = SpacegroupAnalyzer(structure).get_symmetrized_structure();
            testCase.verifyEqual(numel(value.equivalent_indices), 1);
            testCase.verifyEqual(value.equivalent_indices{1}, [1, 2]);
            testCase.verifyEqual(value.wyckoff_symbols, "2a");
            testCase.verifyEqual(numel(value.find_equivalent_sites( ...
                value.sites{1})), 2);
            restored = kssolv.analysis.matgenlab.symmetry.structure. ...
                SymmetrizedStructure.from_dict(value.as_dict());
            testCase.verifyEqual(restored.frac_coords, value.frac_coords);
            testCase.verifyEqual(restored.wyckoff_symbols, "2a");
            copied = value.copy();
            testCase.verifyEqual(copied.frac_coords, value.frac_coords);
            testCase.verifyTrue(contains(value.to("", "json"), ...
                '"@class":"Structure"'));
            testCase.verifyTrue(contains(string(value), "Reduced Formula: Fe"));
        end
    end
end
