classdef BondDissociationInventoryTest < matlab.unittest.TestCase
    properties
        oracle
        fixtures
    end

    methods (TestClassSetup)
        function loadFrozenData(testCase)
            testCase.oracle = jsondecode(fileread(fullfile(pwd, ...
                "dev", "matgenlab", "oracles", ...
                "bond_dissociation_2026.5.4.json")));
            testCase.fixtures = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+analysis", "+fixtures", ...
                "+bond_dissociation");
        end
    end

    methods (Test)
        function officialAnionsMatchFrozenPymatgen(testCase)
            [principle, fragments] = loadCase( ...
                testCase.fixtures, "neg_EC_40");
            value = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments);
            verifyCase(testCase, value, testCase.oracle.neg_EC_40);

            [principle, fragments] = loadCase( ...
                testCase.fixtures, "neg_TFSI");
            value = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments);
            verifyCase(testCase, value, testCase.oracle.neg_TFSI);
        end

        function ringOpeningAndChargeSeparationMatchOracle(testCase)
            [principle, fragments] = loadCase( ...
                testCase.fixtures, "PC_65");
            value = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments);
            verifyCase(testCase, value, testCase.oracle.PC_65);
            testCase.verifyEqual(size(value.ring_bonds, 1), 5);
            testCase.verifyEqual(numel(value.done_RO_frags), 5);

            additional = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments, ...
                "allow_additional_charge_separation", true);
            verifyCase(testCase, additional, ...
                testCase.oracle.PC_65_additional_charge);
            testCase.verifyEqual(additional.expected_charges, -2:2);
        end

        function multipleRingCutsAndMsonRoundTrip(testCase)
            [principle, fragments] = loadCase( ...
                testCase.fixtures, "PC_65");
            value = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments, ...
                "multibreak", true);
            verifyCase(testCase, value, ...
                testCase.oracle.PC_65_multibreak);
            testCase.verifyEqual(numel(value.bond_pairs), 10);
            testCase.verifyEqual(pairKeys(value.bond_pairs, true), ...
                pairKeys(testCase.oracle.PC_65_multibreak.bond_pairs, ...
                false));

            [principle, fragments] = loadCase( ...
                testCase.fixtures, "neg_EC_40");
            original = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments);
            encoded = original.as_dict();
            testCase.verifyEqual(encoded.x_module, ...
                "pymatgen.analysis.bond_dissociation");
            testCase.verifyEqual(encoded.x_class, ...
                "BondDissociationEnergies");
            restored = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies.from_dict(encoded);
            verifyCase(testCase, restored, testCase.oracle.neg_EC_40);
            testCase.verifyNotEmpty(original.toJSON());
        end

        function filteringSearchAndValidationAreFaithful(testCase)
            [principle, fragments] = loadCase( ...
                testCase.fixtures, "neg_EC_40");
            baseline = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, fragments);
            duplicate = fragments(1);
            duplicate.final_energy = duplicate.final_energy + 1;
            mixed = [fragments; duplicate];
            baseline.filter_fragment_entries(mixed);
            testCase.verifyEqual(numel(baseline.filtered_entries), ...
                testCase.oracle.neg_EC_40.filtered_count);
            matches = baseline.search_fragment_entries( ...
                baseline.filtered_entries{1}.initial_molgraph);
            testCase.verifyGreaterThanOrEqual( ...
                sum(cellfun(@numel, matches)), 1);

            changed = fragments;
            changed(1).pcm_dielectric = 99;
            testCase.verifyError(@() kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(principle, changed), ...
                "KSSOLV:Matgenlab:BondDissociation:PCM");
        end
    end
end

function [principle, fragments] = loadCase(directory, stem)
principle = jsondecode(fileread(fullfile( ...
    directory, stem + "_principle.json")));
fragments = jsondecode(fileread(fullfile( ...
    directory, stem + "_fragments.json")));
end

function verifyCase(testCase, value, expected)
testCase.verifyEqual(numel(value.filtered_entries), ...
    expected.filtered_count);
testCase.verifyEqual(value.expected_charges, ...
    reshape(expected.expected_charges, 1, []));
actualRings = reshape(value.ring_bonds - 1, [], 2);
wantedRings = reshape(expected.ring_bonds, [], 2);
testCase.verifyEqual(sortrows(actualRings), sortrows(wantedRings));
actual = value.bond_dissociation_energies;
wanted = reshape(expected.records, 1, []);
actualEnergies = cellfun(@(record) record{1}, actual);
wantedEnergies = cellfun(@(record) record{1}, wanted);
[~, actualOrder] = sort(actualEnergies);
[~, wantedOrder] = sort(wantedEnergies);
testCase.verifyEqual(numel(actual), numel(wanted));
for index = 1:numel(actual)
    first = reshape(actual{actualOrder(index)}, 1, []);
    second = reshape(wanted{wantedOrder(index)}, 1, []);
    testCase.verifyEqual(numel(first), numel(second));
    testCase.verifyEqual(first{1}, second{1}, AbsTol = 2e-12);
    testCase.verifyEqual(size(first{2}, 1), size(second{2}, 1));
    for field = 3:numel(first)
        if isnumeric(second{field})
            testCase.verifyEqual(first{field}, second{field}, ...
                AbsTol = 2e-12);
        else
            testCase.verifyEqual(string(first{field}), ...
                string(second{field}));
        end
    end
end
end

function keys = pairKeys(pairs, matlabPairs)
if matlabPairs
    values = zeros(numel(pairs), 2, 2);
    for index = 1:numel(pairs)
        pair = pairs{index};
        values(index, 1, :) = pair{1} - 1;
        values(index, 2, :) = pair{2} - 1;
    end
else
    values = pairs;
end
keys = strings(size(values, 1), 1);
for index = 1:size(values, 1)
    edges = squeeze(values(index, :, :));
    edges = sortrows(sort(edges, 2));
    keys(index) = sprintf("%d-%d|%d-%d", ...
        edges(1, 1), edges(1, 2), edges(2, 1), edges(2, 2));
end
keys = sort(keys);
end
