classdef LobsterIOTest < matlab.unittest.TestCase
    %LOBSTERIOTEST Frozen official-fixture coverage for native LOBSTER I/O.
    methods (Test)
        function inputRoundTripAndBasisEnumeration(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.*
            fixture = fullfile(lobsterFixtureRoot(), "lobsterin.1");
            value = LobsterIn.from_file(fixture);
            testCase.verifyEqual(value.get("cohpstartenergy"), -15);
            testCase.verifyEqual(numel(value.get("basisfunctions")), 2);
            restored = LobsterIn.from_dict(value.as_dict());
            testCase.verifyEqual(restored.data, value.data);
            combinations = get_all_possible_basis_combinations( ...
                {"Si 3s 3p"}, {"Si 3s 3p 3d"});
            testCase.verifyEqual(numel(combinations), 2);
        end

        function populationFixtures(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            root = lobsterFixtureRoot();
            charge = CHARGE(fullfile(root, "CHARGE.lobster.MnO"));
            testCase.verifyEqual(charge.centers, {'O1', 'Mn2'});
            testCase.verifyEqual(charge.mulliken, [-1.3, 1.3], AbsTol=1e-12);
            gross = GROSSPOP(fullfile(root, "GROSSPOP.lobster"));
            testCase.verifyEqual(numel(fieldnames(gross.populations)), 9);
            testCase.verifyEqual(gross.populations.Si1.x3s.up.mulliken, ...
                0.52, AbsTol=1e-12);
        end

        function integratedInteractionsAndFiltering(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            root = lobsterFixtureRoot();
            value = ICOHPLIST(fullfile(root, "ICOHPLIST.lobster"));
            testCase.verifyEqual(size(value.data), [2, 2]);
            testCase.verifyEqual(value.data(2, :), ...
                [-0.28485, -0.58279], AbsTol=1e-12);
            indices = value.get_interaction_indices_by_properties( ...
                centers = {"Fe9"});
            testCase.verifyEqual(indices, 1);
            selected = value.get_data_by_properties(indices = 2);
            testCase.verifyEqual(selected, value.data(2, :));
            nc = NcICOBILIST(fullfile(root, "NcICOBILIST.lobster.nospin"));
            testCase.verifyEqual(size(nc.data), [24, 1]);
        end

        function resolvedCohpFixture(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            value = COHPCAR(fullfile(lobsterFixtureRoot(), ...
                "COHPCAR.lobster.gz"));
            testCase.verifyEqual(value.num_bonds, 3);
            testCase.verifyEqual(value.num_data, 301);
            testCase.verifySize(value.data, [301, 13]);
            testCase.verifyEqual(value.efermi_value, ...
                9.75576, AbsTol=1e-5);
            testCase.verifyEqual(value.energies(1), -10.03344, AbsTol=1e-12);
            mapping = value.interaction_indices_to_data_indices_mapping( ...
                0, {"up", "down"}, "coxx");
            testCase.verifyEqual(mapping, [1, 7]);
        end

        function dosAndMiscFixtures(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            root = lobsterFixtureRoot();
            dos = DOSCAR(fullfile(root, "DOSCAR.lobster.nonspin"));
            testCase.verifyEqual(dos.efermi, -2.87474583, AbsTol=1e-10);
            testCase.verifyEqual(numel(dos.energies), 6);
            testCase.verifyEqual(sort(string(fieldnames(dos.projected_dos))), ...
                ["F1"; "K1"]);
            bwdf = BWDF(fullfile(root, "BWDF.lobster.AlN.gz"));
            testCase.verifySize(bwdf.data, [201, 3]);
            testCase.verifyEqual(bwdf.data(1, :), ...
                [1.91173, 0.81161, 0.81175], AbsTol=1e-12);
            polarization = POLARIZATION( ...
                fullfile(root, "POLARIZATION.lobster.AlN.gz"));
            testCase.verifyEqual(polarization.rel_mulliken_pol_vector.z, ...
                56.14, AbsTol=1e-12);
            site = SitePotentials( ...
                fullfile(root, "SitePotentials.lobster.perovskite"));
            testCase.verifyEqual(site.madelung_energies_mulliken, ...
                -40.02, AbsTol=1e-12);
            madelung = MadelungEnergies( ...
                fullfile(root, "MadelungEnergies.lobster.perovskite"));
            testCase.verifyEqual(madelung.ewald_splitting, 3.14, AbsTol=1e-12);
        end

        function bandFatbandAndMatrixFixtures(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            root = lobsterFixtureRoot();
            overlaps = BandOverlaps( ...
                fullfile(root, "bandOverlaps.lobster.new.1"));
            testCase.verifyFalse(overlaps.has_good_quality_max_deviation());
            fatband = Fatband(fullfile(root, "FATBAND_si1_3s.lobster"));
            testCase.verifyEqual(fatband.nbands, 36);
            testCase.verifySize(fatband.fatband.energies.up, [71, 36]);
            matrices = LobsterMatrices( ...
                fullfile(root, "Na_hamiltonMatrices.lobster.gz"), ...
                "hamilton", 0);
            testCase.verifyEqual(matrices.get_onsite_values("Na1", "3s"), ...
                -2.20795, AbsTol=1e-5);
            dictionary = matrices.as_dict();
            testCase.verifyTrue(isfield(dictionary.matrices.k1.up, "real"));
        end

        function lobsteroutAndLegacyAdapters(testCase)
            import kssolv.analysis.matgenlab.io.lobster.future.outputs.*
            root = lobsterFixtureRoot();
            output = LobsterOut(fullfile(root, "lobsterout.normal"));
            testCase.verifyEqual(output.lobster_version, "3.1.0");
            testCase.verifyEqual(output.number_of_threads, 8);
            testCase.verifyEqual(output.charge_spilling, 0.0268, AbsTol=1e-12);
            legacy = kssolv.analysis.matgenlab.io.lobster.Icohplist( ...
                false, false, false, fullfile(root, "ICOHPLIST.lobster"));
            testCase.verifyEqual(legacy.data, ...
                [-0.10218, -0.19701; -0.28485, -0.58279], AbsTol=1e-12);
            charge = kssolv.analysis.matgenlab.io.lobster.Charge( ...
                fullfile(root, "CHARGE.lobster.MnO"));
            testCase.verifyEqual(charge.Loewdin, [-1.25, 1.25]);
        end

        function explicitRunnerBoundaryAndPlotting(testCase)
            import kssolv.analysis.matgenlab.io.lobster.*
            testCase.verifyError(@() LobsterRunner.run("/usr/bin/true"), ...
                "KSSOLV:Matgenlab:Lobster:ExternalBoundary");
            result = LobsterRunner.run("/usr/bin/true", ...
                allow_external = true);
            testCase.verifyEqual(result.status, 0);
            reader = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                BWDF(fullfile(lobsterFixtureRoot(), "BWDF.lobster.AlN.gz"));
            figureValue = figure("Visible", "off");
            cleanup = onCleanup(@() close(figureValue));
            handles = LobsterPlotter.plot_bwdf(reader, axes = axes(figureValue));
            testCase.verifyNotEmpty(handles);
        end
    end
end

function root = lobsterFixtureRoot()
root = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", "+analysis", ...
    "+matgenlab", "+test", "+io", "+fixtures", "+lobster");
end
