classdef Boltztrap2Test < matlab.unittest.TestCase
    methods (Test)
        function officialVasprunLoaders(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            root = fullfile(electronicFixtureRoot(), "boltztrap2");
            fixture = fullfile(root, "vasprun.xml");
            testCase.assumeTrue(isfile(fixture));
            loader = VasprunBSLoader.from_file(fixture);
            testCase.verifyFalse(loader.is_spin_polarized);
            testCase.verifyEqual(loader.fermi, ...
                0.185266535678, AbsTol=1e-5);
            testCase.verifyEqual(loader.nelect_all, 20);
            testCase.verifySize(loader.ebands_all, [20, 120]);
            testCase.verifyEqual(loader.ebands_all(11, 101), ...
                0.2708057, AbsTol=1e-5);
            testCase.verifySize(loader.proj_all.up, [120, 20, 2, 9]);
            testCase.verifyEqual(loader.get_volume(), ...
                477.6256714925874, AbsTol=1e-5);
            legacy = VasprunLoader.from_file(fixture);
            testCase.verifySize(legacy.ebands, [20, 120]);
            accepted = loader.bandana(-inf, inf);
            testCase.verifyEqual(sum(accepted), 20);
        end

        function interpolationDosTransportAndPlots(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            fixture = fullfile(electronicFixtureRoot(), ...
                "boltztrap2", "vasprun.xml");
            testCase.assumeTrue(isfile(fixture));
            loader = VasprunBSLoader.from_file(fixture);
            interpolator = BztInterpolator(loader, "lpfac", 2);
            testCase.verifySize(interpolator.eband, [6, 29791]);
            testCase.verifySize(interpolator.vvband, [6, 3, 3, 29791]);
            testCase.verifySize(interpolator.cband, ...
                [6, 3, 3, 3, 29791]);
            dos = interpolator.get_dos("T", 200, "npts_mu", 100);
            testCase.verifyNumElements(dos.energies, 100);
            testCase.verifyTrue(all(dos.densities.up >= 0));
            transport = BztTransportProperties(interpolator, ...
                "temp_r", [300, 500], "npts_mu", 100, ...
                "doping", [1e20, 1e21]);
            conductivitySize = size(transport.Conductivity_mu);
            testCase.verifyEqual(conductivitySize([1, 3, 4]), [2, 3, 3]);
            testCase.verifyGreaterThan(conductivitySize(2), 80);
            testCase.verifySize(transport.Conductivity_doping.n, ...
                [2, 2, 3, 3]);
            testCase.verifyTrue(all(isfinite( ...
                transport.Carrier_conc_mu), "all"));
            plotter = BztPlotter(transport, interpolator);
            figureHandle = plotter.plot_props("S", "mu", "temp", ...
                "temps", [300, 500]);
            testCase.verifyTrue(isgraphics(figureHandle, "figure"));
            close(figureHandle);
            bandPlotter = plotter.plot_bands( ...
                {{"L", "K"}}, containers.Map({'L', 'K'}, ...
                {[0.5,0.5,0.5], [0.375,0.375,0.75]}), 8);
            testCase.verifyClass(bandPlotter, ...
                "kssolv.analysis.matgenlab.electronic_structure.BSPlotter");
            dosPlotter = plotter.plot_dos("npoints", 50);
            axesHandle = dosPlotter.get_plot();
            testCase.verifyTrue(isgraphics(axesHandle, "axes"));
            close(ancestor(axesHandle, "figure"));
        end

        function serializationRoundTrips(testCase)
            import kssolv.analysis.matgenlab.electronic_structure.*
            fixture = fullfile(electronicFixtureRoot(), ...
                "boltztrap2", "vasprun.xml");
            testCase.assumeTrue(isfile(fixture));
            loader = VasprunBSLoader.from_file(fixture);
            interpolator = BztInterpolator(loader, "lpfac", 0.1);
            filename = string(tempname) + ".json.gz";
            cleanup = onCleanup(@() deleteIfPresent(filename));
            interpolator.save(filename, true);
            restored = BztInterpolator(loader, ...
                "load_bztInterp", true, "fname", filename);
            testCase.verifyEqual(restored.eband, interpolator.eband, ...
                AbsTol=1e-12);
            transport = BztTransportProperties(interpolator, ...
                "temp_r", 300, "npts_mu", 50);
            transportFile = string(tempname) + ".json.gz";
            cleanup2 = onCleanup(@() deleteIfPresent(transportFile));
            transport.save(transportFile);
            restoredTransport = BztTransportProperties(interpolator, ...
                "load_bztTranspProps", true, "fname", transportFile);
            testCase.verifyEqual(restoredTransport.Conductivity_mu, ...
                transport.Conductivity_mu, RelTol=1e-12);
            officialFile = fullfile(electronicFixtureRoot(), ...
                "boltztrap2", "bztTranspProps.json.gz");
            official = BztTransportProperties(interpolator, ...
                "load_bztTranspProps", true, "fname", officialFile);
            testCase.verifySize(official.Conductivity_mu, ...
                [3, 3252, 3, 3]);
            testCase.verifySize(official.Carrier_conc_mu, [3, 3252]);
            clear cleanup cleanup2
        end
    end
end

function root = electronicFixtureRoot()
base = string(getenv("MATGENLAB_PYMATGEN_CORE"));
if base == "", base = "/tmp/matgenlab-pymatgen-core-v2026.7.24"; end
root = fullfile(base, "test-files", "electronic_structure");
end

function deleteIfPresent(filename)
if isfile(filename), delete(filename); end
end
