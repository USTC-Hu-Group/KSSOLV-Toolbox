classdef GroupsTest < matlab.unittest.TestCase
    % Frozen against pymatgen-core v2026.7.24 test_groups.py.

    methods (Test)
        function pointGroupOrdersAndOrbits(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.PointGroup
            testCase.verifyEqual(length(PointGroup("mmm")), 8);
            testCase.verifyEqual(length(PointGroup("432")), 24);
            testCase.verifyEqual(length(PointGroup("-6m2")), 12);
            group = PointGroup("mmm");
            testCase.verifyEqual(size(group.get_orbit([0.1, 0.1, 0.1]), 1), 8);
            testCase.verifyEqual(size(group.get_orbit([0, 0, 0.1]), 1), 2);
        end

        function pointGroupSettingsAndChains(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.PointGroup
            testCase.verifyEqual(PointGroup("2/m 2/m 2/m").symbol, "mmm");
            testCase.verifyEqual(PointGroup("31m").symbol, "3m");
            testCase.verifyTrue( ...
                PointGroup("mm2").is_subgroup(PointGroup("mmm")));
            testCase.verifyTrue( ...
                PointGroup("-3m").is_subgroup(PointGroup("6/mmm")));
            testCase.verifyFalse( ...
                PointGroup("m-3m").is_supergroup(PointGroup("6/mmm")));
        end

        function pointGroupFromSpaceGroup(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.PointGroup
            testCase.verifyEqual(PointGroup.from_space_group( ...
                "P 2_1/n2_1/m2_1/a").symbol, "mmm");
            testCase.verifyEqual(PointGroup.from_space_group("I -4").symbol, "-4");
            testCase.verifyEqual(PointGroup.from_space_group( ...
                "F4_1/d-32/m").symbol, "m-3m");
        end

        function spaceGroupAttributesAndAliases(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup
            group = SpaceGroup("Fm-3m");
            testCase.verifyEqual(group.int_number, 225);
            testCase.verifyEqual(group.full_symbol, "F4/m-32/m");
            testCase.verifyEqual(group.point_group, "m-3m");
            testCase.verifyEqual(group.order, 192);
            testCase.verifyEqual(SpaceGroup("P2/c").int_number, 13);
            testCase.verifyEqual(SpaceGroup("R-3mH").int_number, 166);
            testCase.verifyEqual(SpaceGroup("P41").int_number, 76);
            testCase.verifyEqual(SpaceGroup("P21ma").int_number, 26);
            testCase.verifyEqual(SpaceGroup("P2/m2/m2/m").symbol, "Pmmm");
        end

        function canonicalNumbersAndSettings(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup
            testCase.verifyEqual(SpaceGroup.from_int_number(64).symbol, "Cmce");
            expected = sort(["Pmmn", "Pmmn:1", "Pmmn:2", ...
                "Pmnm", "Pmnm:1", "Pmnm:2", ...
                "Pnmm", "Pnmm:1", "Pnmm:2"]);
            testCase.verifyEqual(sort(SpaceGroup.get_settings("Pmmn")), expected);
            expected = sort(["Pnmb", "Pman", "Pncm", ...
                "Pmna", "Pcnm", "Pbmn"]);
            testCase.verifyEqual(sort(SpaceGroup.get_settings("Pmna")), expected);
        end

        function subgroupGraphRegressions(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup
            testCase.verifyTrue( ...
                SpaceGroup("Pma2").is_subgroup(SpaceGroup("Pccm")));
            testCase.verifyTrue( ...
                SpaceGroup("Fm-3m").is_subgroup(SpaceGroup("Pm-3m")));
            testCase.verifyTrue( ...
                SpaceGroup("P3").is_subgroup(SpaceGroup("P3")));
            testCase.verifyFalse(SpaceGroup.from_int_number(229). ...
                is_subgroup(SpaceGroup.from_int_number(230)));
        end

        function compatibilityAndStrings(testCase)
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup
            testCase.verifyTrue(SpaceGroup("Fm-3m"). ...
                is_compatible(Lattice.cubic(1)));
            testCase.verifyFalse(SpaceGroup("Fm-3m"). ...
                is_compatible(Lattice.hexagonal(1, 2)));
            testCase.verifyTrue(SpaceGroup("R-3m:H"). ...
                is_compatible(Lattice.hexagonal(1, 2)));
            testCase.verifyEqual(SpaceGroup("R-3c").to_latex_string(), ...
                "R$\overline{3}$c");
            testCase.verifyEqual(SpaceGroup("P4_1").to_unicode_string(), "P4₁");
        end

        function orbitGeneratorsMapReferencePoint(testCase)
            import kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup
            point = [0.13, 0.27, 0.39];
            [orbit, generators] = ...
                SpaceGroup("Fm-3m").get_orbit_and_generators(point);
            testCase.verifyLessThanOrEqual(size(orbit, 1), 192);
            testCase.verifyEqual(generators{1}.operate(orbit(1, :)), ...
                point, AbsTol = 1e-12);
        end

        function frozenOracleAttributes(testCase)
            testCase.assumeTrue(kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            request = struct( ...
                "module", "pymatgen.symmetry.groups", ...
                "symbol", "SpaceGroup", ...
                "construct", struct("args", {{"Fm-3m"}}), ...
                "operations", {{ ...
                    struct("kind", "get", "name", "symbol"), ...
                    struct("kind", "get", "name", "int_number"), ...
                    struct("kind", "get", "name", "full_symbol"), ...
                    struct("kind", "get", "name", "point_group"), ...
                    struct("kind", "get", "name", "order") ...
                    }});
            reference = kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.execute(request);
            actual = kssolv.analysis.matgenlab.symmetry.groups. ...
                SpaceGroup("Fm-3m");
            testCase.verifyEqual(actual.symbol, string(reference.results{1}));
            testCase.verifyEqual(actual.int_number, reference.results{2});
            testCase.verifyEqual(actual.full_symbol, ...
                string(reference.results{3}));
            testCase.verifyEqual(actual.point_group, ...
                string(reference.results{4}));
            testCase.verifyEqual(actual.order, reference.results{5});
        end
    end
end
