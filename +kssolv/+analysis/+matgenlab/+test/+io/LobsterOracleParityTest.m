classdef LobsterOracleParityTest < matlab.unittest.TestCase
    %LOBSTERORACLEPARITYTEST Frozen Python-oracle numerical parity checks.
    methods (Test)
        function chargeAndIntegratedList(testCase)
            testCase.assumeTrue(oracleAvailable());
            root = lobsterFixtureRoot();
            chargePath = fullfile(root, "CHARGE.lobster.MnO");
            reference = oracle("CHARGE", chargePath, ...
                [operation("get", "mulliken"), operation("get", "loewdin"), ...
                operation("get", "filename")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                CHARGE(chargePath);
            testCase.verifyEqual(value.mulliken, ...
                reshape(reference.results{1}, 1, []), AbsTol=1e-12);
            testCase.verifyEqual(value.loewdin, ...
                reshape(reference.results{2}, 1, []), AbsTol=1e-12);
            listPath = fullfile(root, "ICOHPLIST.lobster");
            reference = oracle("ICOHPLIST", listPath, ...
                [operation("get", "data"), operation("get", "filename")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOHPLIST(listPath);
            testCase.verifyEqual(value.data, ...
                reshape(reference.results{1}, size(value.data)), AbsTol=1e-12);
        end

        function dosBwdfAndPotentials(testCase)
            testCase.assumeTrue(oracleAvailable());
            root = lobsterFixtureRoot();
            dosPath = fullfile(root, "DOSCAR.lobster.nonspin");
            reference = oracle("DOSCAR", dosPath, ...
                [operation("get", "efermi"), operation("get", "energies")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                DOSCAR(dosPath);
            testCase.verifyEqual(value.efermi, reference.results{1}, AbsTol=1e-12);
            testCase.verifyEqual(value.energies, ...
                reshape(reference.results{2}, 1, []), AbsTol=1e-12);
            bwdfPath = fullfile(root, "BWDF.lobster.AlN.gz");
            reference = oracle("BWDF", bwdfPath, ...
                [operation("get", "data"), operation("get", "filename")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                BWDF(bwdfPath);
            testCase.verifyEqual(value.data, reference.results{1}, AbsTol=1e-12);
            sitePath = fullfile(root, "SitePotentials.lobster.perovskite");
            reference = oracle("SitePotentials", sitePath, ...
                [operation("get", "site_potentials_mulliken"), ...
                operation("get", "madelung_energies_mulliken")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                SitePotentials(sitePath);
            testCase.verifyEqual(value.site_potentials_mulliken, ...
                reshape(reference.results{1}, 1, []), AbsTol=1e-12);
            testCase.verifyEqual(value.madelung_energies_mulliken, ...
                reference.results{2}, AbsTol=1e-12);
        end

        function cohpAndFatband(testCase)
            testCase.assumeTrue(oracleAvailable());
            root = lobsterFixtureRoot();
            cohpPath = fullfile(root, "COHPCAR.lobster.gz");
            reference = oracle("COHPCAR", cohpPath, ...
                [operation("get", "data"), operation("get", "efermi")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                COHPCAR(cohpPath);
            testCase.verifyEqual(value.data, reference.results{1}, AbsTol=1e-12);
            testCase.verifyEqual(value.efermi_value, ...
                reference.results{2}, AbsTol=1e-12);
            fatbandPath = fullfile(root, "FATBAND_si1_3s.lobster");
            reference = oracle("Fatband", fatbandPath, ...
                [operation("get", "nbands"), operation("get", "fatband")]);
            value = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                Fatband(fatbandPath);
            testCase.verifyEqual(value.nbands, reference.results{1});
            spinFields = fieldnames(reference.results{2}.energies);
            testCase.verifyEqual(value.fatband.energies.up, ...
                reference.results{2}.energies.(spinFields{1}), AbsTol=1e-12);
        end
    end
end

function response = oracle(symbol, path, operations)
request = struct("module", "pymatgen.io.lobster.future.outputs", ...
    "symbol", symbol, "construct", struct("args", {{path}}), ...
    "operations", operations);
response = kssolv.analysis.matgenlab.test.support.PymatgenOracle.execute(request);
end

function value = operation(kind, name)
value = struct("kind", kind, "name", name);
end

function value = oracleAvailable()
value = kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable();
end

function root = lobsterFixtureRoot()
root = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", "+analysis", ...
    "+matgenlab", "+test", "+io", "+fixtures", "+lobster");
end
