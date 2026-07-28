classdef ShengbteInventoryTest < matlab.unittest.TestCase
    properties
        fixture
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.fixture = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+io", "+fixtures", ...
                "+shengbte", "CONTROL-CSLD_Si");
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", ...
                "shengbte_2026.7.24.json")));
        end
    end

    methods (Test)
        function officialControlParsesAndWritesExactly(testCase)
            control = kssolv.analysis.matgenlab.io.shengbte. ...
                Control.from_file(testCase.fixture);
            testCase.verifyEqual(control("nelements"), 1);
            testCase.verifyEqual(control("natoms"), 2);
            testCase.verifyEqual(control("ngrid"), [25, 25, 25]);
            testCase.verifyEqual(control("lattvec"), ...
                [0, 2.734363999, 2.734363999; ...
                2.734363999, 0, 2.734363999; ...
                2.734363999, 2.734363999, 0], AbsTol = 1e-14);
            testCase.verifyEqual(control("positions"), ...
                [0, 0, 0; .25, .25, .25], AbsTol = 1e-14);
            testCase.verifyEqual(string(control("elements")), "Si");
            testCase.verifyEqual(control("types"), [1, 1]);
            testCase.verifyFalse(control("isotopes"));
            filename = string(tempname);
            cleanup = onCleanup(@() deleteIfExists(filename));
            control.to_file(filename);
            testCase.verifyEqual(fileread(filename), ...
                fileread(testCase.fixture));
            clear cleanup
        end

        function dictionariesRoundTripAndMutate(testCase)
            control = kssolv.analysis.matgenlab.io.shengbte. ...
                Control.from_file(testCase.fixture);
            restored = kssolv.analysis.matgenlab.io.shengbte. ...
                Control.from_dict(control.as_dict());
            testCase.verifyTrue(restored == control);
            restored("t") = 600;
            testCase.verifyEqual(restored("t"), 600);
            testCase.verifyTrue(restored.isKey("scell"));
            testCase.verifyTrue(any(restored.keys() == "lfactor"));
            testCase.verifyEqual(restored.count(), 16);
            ranged = kssolv.analysis.matgenlab.io.shengbte.Control( ...
                [9, 11, 13], struct("min", 100, ...
                "max", 500, "step", 50));
            expected = testCase.oracle.temperature_range;
            testCase.verifyEqual(ranged("ngrid"), ...
                reshape(expected.ngrid, 1, []));
            testCase.verifyEqual(ranged("t_min"), expected.t_min);
            testCase.verifyEqual(ranged("t_max"), expected.t_max);
            testCase.verifyEqual(ranged("t_step"), expected.t_step);
        end

        function structureConversionMatchesFrozenOracle(testCase)
            lattice = [0, 2.734363999, 2.734363999; ...
                2.734363999, 0, 2.734363999; ...
                2.734363999, 2.734363999, 0];
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, {"Si", "Si"}, [0, 0, 0; .25, .25, .25]);
            control = kssolv.analysis.matgenlab.io.shengbte. ...
                Control.from_structure(structure, 50000, ...
                "scell", [5, 5, 5]);
            expected = testCase.oracle.from_structure;
            testCase.verifyEqual(control("ngrid"), ...
                reshape(expected.ngrid, 1, []));
            testCase.verifyEqual(control("nelements"), ...
                expected.nelements);
            testCase.verifyEqual(control("natoms"), expected.natoms);
            testCase.verifyEqual(control("types"), ...
                reshape(expected.types, 1, []));
            testCase.verifyEqual(string(control("elements")), ...
                reshape(string(expected.elements), 1, []));
            restored = control.get_structure();
            testCase.verifyEqual(restored.lattice.matrix, ...
                testCase.oracle.restored_lattice, AbsTol = 1e-14);
            testCase.verifyEqual(restored.frac_coords, ...
                testCase.oracle.restored_frac_coords, AbsTol = 1e-14);
        end

        function missingRequiredSettingsAreReported(testCase)
            incomplete = kssolv.analysis.matgenlab.io.shengbte.Control();
            testCase.verifyWarning(@() writeTemporary(incomplete), ...
                "KSSOLV:Matgenlab:ShengBTE:RequiredParameter");
            testCase.verifyError(@() incomplete.get_structure(), ...
                "KSSOLV:Matgenlab:ShengBTE:StructureParameters");
        end

        function invalidTemperatureIsRejected(testCase)
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.shengbte.Control( ...
                [1, 1, 1], "hot"), ...
                "KSSOLV:Matgenlab:ShengBTE:Temperature");
        end
    end
end

function writeTemporary(control)
filename = string(tempname);
cleanup = onCleanup(@() deleteIfExists(filename));
control.to_file(filename);
clear cleanup
end

function deleteIfExists(filename)
if isfile(filename), delete(filename); end
end
