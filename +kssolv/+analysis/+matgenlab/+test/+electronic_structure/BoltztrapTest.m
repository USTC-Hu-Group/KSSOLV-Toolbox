classdef BoltztrapTest < matlab.unittest.TestCase
    methods (Test)
        function officialTransportFixture(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            root = fullfile(electronicFixtureRoot(), "boltztrap", "transp");
            testCase.assumeTrue(isfolder(root));
            analyzer = BoltztrapAnalyzer.from_files(root);
            testCase.verifyEqual(analyzer.gap, ...
                1.6644932121620404, AbsTol=1e-4);
            testCase.verifyEqual(analyzer.vol, ...
                612.97557323964838, AbsTol=1e-4);
            conductivity = analyzer.cond(300);
            testCase.verifyEqual(conductivity(1, 1, 103) / 1e19, ...
                7.5756518, AbsTol=1e-4);
            testCase.verifyEqual(conductivity(1, 3, 103), -11.14679, ...
                AbsTol=1e-6);
            seebeck = analyzer.get_seebeck();
            nType = seebeck.n(800);
            testCase.verifyEqual(nType(4, :), ...
                [-768.99079, -724.4392, -686.84683], AbsTol=1e-5);
            average = analyzer.get_seebeck("output", "average");
            pType = average.p(800);
            testCase.verifyEqual(pType(4), 697.608936667, AbsTol=1e-6);
            concentration = analyzer.get_carrier_concentration();
            values = concentration(300);
            testCase.verifyEqual(values(40) / 1e22, ...
                6.4805156617179151, AbsTol=1e-4);
            hall = analyzer.get_hall_carrier_concentration();
            values = hall(600);
            testCase.verifyEqual(values(121) / 1e21, ...
                6.773394626767555, AbsTol=1e-4);
            restored = BoltztrapAnalyzer.from_dict(analyzer.as_dict());
            testCase.verifyEqual(restored.gap, analyzer.gap);
        end

        function dosBandsAndFermiFixtures(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            root = fullfile(electronicFixtureRoot(), "boltztrap");
            testCase.assumeTrue(isfolder(root));
            up = BoltztrapAnalyzer.from_files(fullfile(root, "dos_up"), 1);
            down = BoltztrapAnalyzer.from_files(fullfile(root, "dos_dw"), -1);
            testCase.verifyEqual(up.dos.densities.up(401), ...
                1.6793445, AbsTol=1e-7);
            testCase.verifyEqual(up.dos_partial.x0.pz(2563), ...
                0.023862958, AbsTol=1e-9);
            testCase.verifyEqual(down.dos_partial.x1.px(3121), ...
                5.0192891, AbsTol=1e-7);
            bands = BoltztrapAnalyzer.from_files(fullfile(root, "bands"));
            testCase.verifySize(bands.bz_bands, [1316, 20]);
            testCase.verifySize(bands.bz_kpoints, [1316, 3]);
            fermi = BoltztrapAnalyzer.from_files(fullfile(root, "fermi"));
            testCase.verifySize(fermi.fermi_surface_data, [121, 121, 65]);
            testCase.verifyEqual(fermi.fermi_surface_data(22, 80, 20), ...
                -1.8831911809439161, AbsTol=1e-5);
        end

        function runnerWritesAndHasExplicitBoundary(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            fixture = fullfile(electronicFixtureRoot(), ...
                "bandstructure", "Cu2O_361_bandstructure.json");
            testCase.assumeTrue(isfile(fixture));
            band = BandStructure.from_dict(jsondecode(fileread(fixture)));
            runner = BoltztrapRunner(band, 1, "symprec", [], ...
                "executable", "__missing_x_trans_for_test__");
            directory = tempname;
            mkdir(directory);
            cleanup = onCleanup(@() rmdir(directory, "s"));
            runner.write_input(directory);
            testCase.verifyTrue(isfile(fullfile(directory, ...
                "boltztrap.energy")));
            testCase.verifyTrue(isfile(fullfile(directory, ...
                "boltztrap.struct")));
            testCase.verifyTrue(isfile(fullfile(directory, ...
                "boltztrap.intrans")));
            testCase.verifyError(@() runner.run(directory, ...
                "write_input", false, "convergence", false), ...
                "KSSOLV:Matgenlab:Boltztrap:Runner");
            clear cleanup
        end

        function parabolicBandFunctions(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            seebeck = seebeck_spb(1, 0.5);
            eta = eta_from_seebeck(seebeck, 0.5);
            testCase.verifyEqual(eta, 1, AbsTol=2e-5);
            mass = seebeck_eff_mass_from_carr(eta, 1e19, 300, 0.5);
            testCase.verifyGreaterThan(mass, 0);
            testCase.verifyEqual( ...
                seebeck_eff_mass_from_seebeck_carr( ...
                seebeck, 1e19, 300, 0.5), mass, RelTol=2e-5);
        end
    end
end

function root = electronicFixtureRoot()
base = string(getenv("MATGENLAB_PYMATGEN_CORE"));
if base == "", base = "/tmp/matgenlab-pymatgen-core-v2026.7.24"; end
root = fullfile(base, "test-files", "electronic_structure");
end
