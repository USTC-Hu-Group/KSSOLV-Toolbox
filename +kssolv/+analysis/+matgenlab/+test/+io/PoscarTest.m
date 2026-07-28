classdef PoscarTest < matlab.unittest.TestCase
    methods (Test)
        function constructorAndFormattingMatchPymatgen(testCase)
            lattice = [
                3.8401979337, 0, 0
                1.9200989668, 3.3257101909, 0
                0, -2.2171384943, 3.1355090603
                ];
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, ["Si", "Si"], [0, 0, 0; 0.75, 0.5, 0.75]);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(structure);
            expected = strjoin([
                "Si2"
                "1.0"
                "   3.84    0.00    0.00"
                "   1.92    3.33    0.00"
                "   0.00   -2.22    3.14"
                "Si"
                "2"
                "direct"
                "   0.00    0.00    0.00 Si"
                "   0.75    0.50    0.75 Si"
                ], newline) + newline;
            testCase.verifyEqual( ...
                poscar.get_str(significant_figures = 2), expected);
            testCase.verifyEqual(poscar.site_symbols, "Si");
            testCase.verifyEqual(poscar.natoms, 2);
            testCase.verifyEqual(poscar.temperature, -1);
        end

        function constructorOptionsStayAlignedWhenSorted(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                4 * eye(3), ["O", "Si"], ...
                [0, 0, 0; 0.25, 0.25, 0.25]);
            selective = logical([1, 0, 0; 0, 1, 1]);
            velocities = [1, 2, 3; 4, 5, 6];
            predictor = reshape(1:18, 2, 3, 3);
            latticeVelocities = reshape(1:18, 6, 3);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                structure, comment = "custom", ...
                selective_dynamics = selective, true_names = false, ...
                velocities = velocities, ...
                predictor_corrector = predictor, ...
                predictor_corrector_preamble = ...
                "PREDICTOR" + newline + "1" + newline + "2", ...
                lattice_velocities = latticeVelocities, ...
                sort_structure = true);
            testCase.verifyEqual(poscar.comment, "custom");
            testCase.verifyFalse(poscar.true_names);
            testCase.verifyEqual(poscar.site_symbols, ["Si", "O"]);
            testCase.verifyEqual(poscar.selective_dynamics, ...
                selective([2, 1], :));
            testCase.verifyEqual(poscar.velocities, velocities([2, 1], :));
            testCase.verifyEqual(poscar.predictor_corrector, ...
                predictor([2, 1], :, :));
            testCase.verifyEqual(poscar.lattice_velocities, latticeVelocities);
            outputLines = splitlines(poscar.get_str());
            testCase.verifyEqual(outputLines(6), "1 1");
        end

        function parsesVasp4NamesAppendedToCoordinates(testCase)
            data = strjoin([
                "Test1"
                "1.0"
                "3.840198 0 0"
                "1.920099 3.325710 0"
                "0 -2.217138 3.135509"
                "1 1"
                "direct"
                "0 0 0 Si"
                "0.75 0.5 0.75 F"
                ], newline);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyTrue(poscar.true_names);
            testCase.verifyEqual(poscar.site_symbols, ["Si", "F"]);
            testCase.verifyEqual(poscar.structure.formula, "Si1 F1");
        end

        function fallsBackToUniqueFalseNames(testCase)
            data = strjoin([
                "VASP4"
                "1"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "1 1"
                "Direct"
                "0 0 0"
                "0.5 0.5 0.5"
                ], newline);
            testCase.verifyWarning( ...
                @() kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data), ...
                "KSSOLV:Matgenlab:Poscar:UnknownElements");
            warning("off", "KSSOLV:Matgenlab:Poscar:UnknownElements");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:Poscar:UnknownElements"));
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyFalse(poscar.true_names);
            testCase.verifyEqual(poscar.site_symbols, ["H", "He"]);
            clear cleanup
        end

        function defaultNamesOverrideAndCartesianScale(testCase)
            data = strjoin([
                "Scaled"
                "1.1"
                "3.840198 0 0"
                "1.920099 3.325710 0"
                "0 -2.217138 3.135509"
                "Si F"
                "1 1"
                "Cartesian"
                "0 0 0"
                "3.840198 1.5 2.35163175"
                ], newline);
            testCase.verifyWarning( ...
                @() kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                data, default_names = ["Si", "O"]), ...
                "KSSOLV:Matgenlab:Poscar:ElementsOverwritten");
            warning("off", "KSSOLV:Matgenlab:Poscar:ElementsOverwritten");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:Poscar:ElementsOverwritten"));
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                data, default_names = ["Si", "O"]);
            testCase.verifyEqual(poscar.site_symbols, ["Si", "O"]);
            testCase.verifyEqual(poscar.structure(2).coords, ...
                [3.840198, 1.5, 2.35163175] * 1.1, AbsTol = 1e-12);
            clear cleanup
        end

        function negativeScaleMeansTargetVolume(testCase)
            data = strjoin([
                "Target volume"
                "-64"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "Si"
                "1"
                "Direct"
                "0.25 0.25 0.25"
                ], newline);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyEqual(poscar.structure.volume, 64, AbsTol = 1e-12);
            testCase.verifyEqual(poscar.structure.lattice.matrix, 4 * eye(3), ...
                AbsTol = 1e-12);
        end

        function selectiveDynamicsRoundTrip(testCase)
            data = strjoin([
                "Selective"
                "1"
                "3 0 0"
                "0 3 0"
                "0 0 3"
                "Si O"
                "1 1"
                "Selective dynamics"
                "Direct"
                "0 0 0 T T F"
                "0.5 0.5 0.5 F F F"
                ], newline);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyEqual(poscar.selective_dynamics, ...
                logical([1, 1, 0; 0, 0, 0]));
            restored = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                poscar.get_str());
            testCase.verifyEqual(restored.selective_dynamics, ...
                poscar.selective_dynamics);
            testCase.verifyTrue( ...
                isfield(poscar.structure.site_properties, ...
                "selective_dynamics"));
        end

        function parsesAndWritesMdSections(testCase)
            data = kssolv.analysis.matgenlab.test.io.PoscarTest.mdData();
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyEqual(poscar.velocities, ...
                [0.01, 0.02, 0.03; -0.01, -0.02, -0.03], ...
                AbsTol = 1e-15);
            testCase.verifySize(poscar.predictor_corrector, [2, 3, 3]);
            testCase.verifyEqual( ...
                squeeze(poscar.predictor_corrector(1, 2, :)).', ...
                [0.4, 0.5, 0.6], AbsTol = 1e-15);
            testCase.verifyEqual(sum(poscar.lattice_velocities, "all"), ...
                171, AbsTol = 1e-12);
            testCase.verifyEqual(string(poscar.predictor_corrector_preamble), ...
                "PREDICTOR-CORRECTOR" + newline + "0.5" + newline + "1 2 3");

            text = poscar.get_str();
            restored = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(text);
            testCase.verifyEqual(restored.velocities, ...
                poscar.velocities, AbsTol = 1e-12);
            testCase.verifyEqual(restored.predictor_corrector, ...
                poscar.predictor_corrector, AbsTol = 1e-12);
            testCase.verifyEqual(restored.lattice_velocities, ...
                poscar.lattice_velocities, AbsTol = 1e-12);
            latticeHeader = extractAfter(text, ...
                "Lattice velocities and vectors" + newline + "  1" + newline);
            firstLine = splitlines(latticeHeader);
            testCase.verifyMatches(firstLine(1), ...
                "^\s{2}1\.0000000E\+00\s{3}2\.0000000E\+00");
        end

        function canSkipMdSections(testCase)
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.mdData(), ...
                read_velocities = false);
            testCase.verifyEmpty(poscar.velocities);
            testCase.verifyEmpty(poscar.predictor_corrector);
            testCase.verifyEmpty(poscar.lattice_velocities);
        end

        function supportsVasp6HashesAndMultilineGroups(testCase)
            data = strjoin([
                "VASP6"
                "1"
                "4 0 0"
                "0 4 0"
                "0 0 4"
                "Fe_pv/deadbeef O/hash"
                "Si/hash"
                "1 2"
                "1"
                "Direct"
                "0 0 0"
                "0.1 0.1 0.1"
                "0.2 0.2 0.2"
                "0.3 0.3 0.3"
                ], newline);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyEqual(poscar.site_symbols, ["Fe", "O", "Si"]);
            testCase.verifyEqual(poscar.natoms, [1, 2, 1]);
        end

        function fileIoAndNeighborPotcarInference(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            path = fullfile(folder, "POSCAR");
            potcarPath = fullfile(folder, "POTCAR");
            data = strjoin([
                "VASP4"
                "1"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "1 1"
                "Direct"
                "0 0 0"
                "0.5 0.5 0.5"
                ], newline);
            kssolv.analysis.matgenlab.test.io.PoscarTest.writeText(path, data);
            kssolv.analysis.matgenlab.test.io.PoscarTest.writeText( ...
                potcarPath, strjoin([
                "TITEL  = PAW_PBE Si 05Jan2001"
                "TITEL  = PAW_PBE O 08Apr2002"
                ], newline));
            warning("off", "KSSOLV:Matgenlab:Poscar:ElementsOverwritten");
            warningCleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:Poscar:ElementsOverwritten"));
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_file(path);
            testCase.verifyEqual(poscar.site_symbols, ["Si", "O"]);
            output = fullfile(folder, "CONTCAR");
            poscar.write_file(output, direct = false);
            testCase.verifyTrue(isfile(output));
            restored = kssolv.analysis.matgenlab.io.vasp.Poscar.from_file( ...
                output, check_for_potcar = false);
            testCase.verifyEqual(restored.structure.cart_coords, ...
                poscar.structure.cart_coords, AbsTol = 1e-12);
            clear warningCleanup cleanup
        end

        function settersValidateSiteArrayShapes(testCase)
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.basicData());
            testCase.verifyError(@assignBadVelocity, ...
                "KSSOLV:Matgenlab:Poscar:SiteArrayLength");
            testCase.verifyError(@badPredictor, ...
                "KSSOLV:Matgenlab:Poscar:PredictorCorrector");

            function assignBadVelocity
                poscar.velocities = [0, 0, 0];
            end
            function badPredictor
                kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                    poscar.structure, predictor_corrector = zeros(2, 3));
            end
        end

        function rejectsEmptyTruncatedAndExtraFrames(testCase)
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(""), ...
                "KSSOLV:Matgenlab:Poscar:Empty");
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                "comment" + newline + "1"), ...
                "KSSOLV:Matgenlab:Poscar:Truncated");
            extra = ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.basicData() + ...
                newline + newline + ...
                "0 0 0" + newline + "0 0 0" + newline + newline + ...
                "key" + newline + "1" + newline + "2" + newline + ...
                strjoin(repmat("0 0 0", 1, 6), newline) + ...
                newline + newline + "frame";
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(extra), ...
                "KSSOLV:Matgenlab:Poscar:ExtraSections");
        end

        function dictionaryRoundTrip(testCase)
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.mdData());
            restored = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar.from_dict( ...
                poscar.as_dict());
            testCase.verifyEqual(restored.comment, poscar.comment);
            testCase.verifyEqual(restored.selective_dynamics, ...
                poscar.selective_dynamics);
            testCase.verifyEqual(restored.velocities, poscar.velocities);
            testCase.verifyEqual(restored.predictor_corrector, ...
                poscar.predictor_corrector);
        end

        function temperatureInitializationHasExactTemperature(testCase)
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.basicData());
            poscar.selective_dynamics = false(2, 3);
            poscar.predictor_corrector = ones(2, 3, 3);
            poscar = poscar.set_temperature(900, 42);
            testCase.verifyEqual(poscar.temperature, 900);
            testCase.verifyEmpty(poscar.selective_dynamics);
            testCase.verifyEmpty(poscar.predictor_corrector);
            testCase.verifyEqual(sum(poscar.velocities, 1), zeros(1, 3), ...
                AbsTol = 1e-12);

            mass = poscar.structure(1).specie.atomic_mass * 1.66053906660e-27;
            boltzmann = 1.380649e-23;
            measured = mass * sum(poscar.velocities .^ 2, "all") * ...
                1e10 / (3 * boltzmann);
            testCase.verifyEqual(measured, 900, AbsTol = 1e-8);
        end

        function outputMatchesFrozenPymatgenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                isAvailable(), ...
                "Pinned pymatgen reference environment is unavailable.");
            data = strjoin([
                "Oracle"
                "1"
                "3.8401979337 0 0"
                "1.9200989668 3.3257101909 0"
                "0 -2.2171384943 3.1355090603"
                "Si O"
                "1 1"
                "Selective dynamics"
                "Direct"
                "0 0 0 T F T"
                "0.75 0.5 0.75 F F F"
                ], newline);
            request = struct( ...
                "module", "pymatgen.io.vasp.inputs", ...
                "symbol", "Poscar", ...
                "construct", struct("method", "from_str", ...
                "args", {{data}}), ...
                "operations", {{struct("kind", "call", ...
                "name", "get_str", "kwargs", ...
                struct("significant_figures", 12))}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
            testCase.verifyEqual( ...
                poscar.get_str(significant_figures = 12), ...
                string(reference.results{1}));
        end

        function parsingCasesMatchFrozenPymatgenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                isAvailable(), ...
                "Pinned pymatgen reference environment is unavailable.");
            vasp4 = strjoin([
                "VASP4 appended names"
                "1"
                "-3.840198 0 0"
                "1.920099 3.325710 0"
                "0 -2.217138 3.135509"
                "1 1"
                "Direct"
                "0 0 0 Si"
                "0.75 0.5 0.75 F"
                ], newline);
            negativeVolume = strjoin([
                "Negative volume"
                "-64"
                "2 0 0"
                "0 2 0"
                "0 0 2"
                "Si"
                "1"
                "Direct"
                "0.25 0.25 0.25"
                ], newline);
            cases = {vasp4, negativeVolume, ...
                kssolv.analysis.matgenlab.test.io.PoscarTest.mdData()};
            for index = 1:numel(cases)
                data = cases{index};
                request = struct( ...
                    "module", "pymatgen.io.vasp.inputs", ...
                    "symbol", "Poscar", ...
                    "construct", struct("method", "from_str", ...
                    "args", {{data}}), ...
                    "operations", {{struct("kind", "call", ...
                    "name", "get_str", "kwargs", ...
                    struct("significant_figures", 9))}});
                reference = ...
                    kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                    execute(request);
                poscar = ...
                    kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(data);
                testCase.verifyEqual( ...
                    poscar.get_str(significant_figures = 9), ...
                    string(reference.results{1}), ...
                    sprintf("POSCAR oracle case %d differs.", index));
            end
        end
    end

    methods (Static, Access = private)
        function value = basicData()
            value = strjoin([
                "Si2"
                "1"
                "3.8401979337 0 0"
                "1.9200989668 3.3257101909 0"
                "0 -2.2171384943 3.1355090603"
                "Si"
                "2"
                "Direct"
                "0 0 0"
                "0.75 0.5 0.75"
                ], newline);
        end

        function value = mdData()
            value = strjoin([
                "MD"
                "1"
                "3 0 0"
                "0 3 0"
                "0 0 3"
                "Si"
                "2"
                "Direct"
                "0 0 0"
                "0.25 0.25 0.25"
                "Lattice velocities and vectors"
                "1"
                "1 2 3"
                "4 5 6"
                "7 8 9"
                "10 11 12"
                "13 14 15"
                "16 17 18"
                ""
                "0.01 0.02 0.03"
                "-0.01 -0.02 -0.03"
                ""
                "PREDICTOR-CORRECTOR"
                "0.5"
                "1 2 3"
                "0.1 0.2 0.3"
                "1.1 1.2 1.3"
                "0.4 0.5 0.6"
                "1.4 1.5 1.6"
                "0.7 0.8 0.9"
                "1.7 1.8 1.9"
                ], newline);
        end

        function writeText(path, text)
            fid = fopen(path, "w", "n", "UTF-8");
            if fid < 0, error("Test:Open", "Cannot create test file."); end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, char(text), "char");
            clear cleanup
        end
    end
end
