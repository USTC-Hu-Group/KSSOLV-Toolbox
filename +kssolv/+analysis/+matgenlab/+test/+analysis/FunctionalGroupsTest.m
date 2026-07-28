classdef FunctionalGroupsTest < matlab.unittest.TestCase
    methods (Test)
        function constructorsAndOptimizationAreNative(testCase)
            className = "kssolv.analysis.matgenlab.analysis." + ...
                "functional_groups.FunctionalGroupExtractor";
            fromFile = feval(className, ...
                functionalFixture("func_group_test.mol"));
            fromMolecule = feval(className, fromFile.molecule);
            fromGraph = feval(className, fromFile.molgraph);
            testCase.verifyEqual(fromFile.species, fromMolecule.species);
            testCase.verifyEqual(fromFile.species, fromGraph.species);
            testCase.verifyEqual( ...
                fromFile.molgraph.graph.adjacency(), ...
                fromGraph.molgraph.graph.adjacency());
            optimized = feval(className, ...
                functionalFixture("func_group_test_no_h.mol"), true);
            testCase.verifyEqual(optimized.molecule.num_sites, ...
                fromFile.molecule.num_sites);
            testCase.verifyEqual(optimized.species, fromFile.species);
        end

        function heteroatomsAndSpecialCarbonsMatchOracle(testCase)
            extractor = officialExtractor();
            hetero = extractor.get_heteroatoms();
            testCase.verifyEqual(numel(hetero), 3);
            testCase.verifyEqual(sort(extractor.species(hetero)), ...
                ["N", "O", "O"]);
            testCase.verifyEqual(numel( ...
                extractor.get_heteroatoms("N")), 1);
            testCase.verifyEqual(numel( ...
                extractor.get_special_carbon()), 4);
            testCase.verifyEqual(numel( ...
                extractor.get_special_carbon("N")), 2);
        end

        function linkedAndBasicGroupsMatchOracle(testCase)
            extractor = officialExtractor();
            marked = union(extractor.get_heteroatoms(), ...
                extractor.get_special_carbon());
            linked = extractor.link_marked_atoms(marked);
            testCase.verifyEqual(numel(linked), 1);
            testCase.verifyEqual(numel(linked{1}), 9);
            markedN = union(extractor.get_heteroatoms("N"), ...
                extractor.get_special_carbon("N"));
            linkedN = extractor.link_marked_atoms(markedN);
            testCase.verifyEqual(numel(linkedN), 2);
            basics = extractor.get_basic_functional_groups();
            testCase.verifyEqual(numel(basics), 1);
            testCase.verifyEqual(numel(basics{1}), 4);
            testCase.verifyEmpty( ...
                extractor.get_basic_functional_groups("phenyl"));
        end

        function allAndCategorizedGroupsMatchOracle(testCase)
            extractor = officialExtractor();
            groups = extractor.get_all_functional_groups();
            testCase.verifyEqual(numel(groups), 2);
            categories = ...
                extractor.categorize_functional_groups(groups);
            testCase.verifyTrue(isKey(categories, ...
                "O=C1C=CC(=O)[N]1"));
            testCase.verifyTrue(isKey(categories, "[CH3]"));
            counts = cellfun(@(key) categories(key).count, ...
                categories.keys);
            testCase.verifyEqual(sum(counts), 2);
        end
    end
end

function extractor = officialExtractor()
extractor = ...
    kssolv.analysis.matgenlab.analysis.functional_groups. ...
    FunctionalGroupExtractor(functionalFixture("func_group_test.mol"));
end

function path = functionalFixture(name)
path = fullfile(fileparts(mfilename("fullpath")), ...
    "+fixtures", "+functional_groups", name);
end
