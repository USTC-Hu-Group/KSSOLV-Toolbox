classdef VaspInputsTest < matlab.unittest.TestCase
    methods (Test)
        function incarParsesKnownTypesMultipliersAndCase(testCase)
            text = strjoin([
                "algo = Fast"
                "ENCUT = 520"
                "LASPH = .TRUE."
                "LATTICE_CONSTRAINTS = False False True"
                "ROPT = 2*1e-3"
                "MAGMOM = 1*6.0 2*-6.0 3*0.6"
                "SYSTEM = Do NOT Capitalize"
                "ML_MODE = RUN"
                ], newline);
            incar = kssolv.analysis.matgenlab.io.vasp.Incar.from_str(text);
            testCase.verifyEqual(incar("ALGO"), "Fast");
            testCase.verifyEqual(incar("encut"), 520);
            testCase.verifyTrue(incar("lasph"));
            testCase.verifyEqual(incar("LATTICE_CONSTRAINTS"), ...
                logical([0,0,1]));
            testCase.verifyEqual(incar("ROPT"), [1e-3,1e-3], ...
                AbsTol = 1e-15);
            testCase.verifyEqual(incar("MAGMOM"), ...
                [6,-6,-6,0.6,0.6,0.6], AbsTol = 1e-15);
            testCase.verifyEqual(incar("SYSTEM"), "Do NOT Capitalize");
            testCase.verifyEqual(incar("ML_MODE"), "run");
        end

        function incarHandlesCommentsSemicolonsContinuationsAndQuotes(testCase)
            text = sprintf([ ...
                'ENCUT = 500; ISMEAR = 0 # ignored\n', ...
                'MAGMOM = 0 0 1 \\\n 3*0\n', ...
                'WANNIER90_WIN = "begin Projections # removed\n', ...
                'Fe:d ; Fe:p ! removed\nEnd Projections "\n']);
            incar = kssolv.analysis.matgenlab.io.vasp.Incar.from_str(text);
            testCase.verifyEqual(incar("ENCUT"), 500);
            testCase.verifyEqual(incar("ISMEAR"), int64(0));
            testCase.verifyEqual(incar("MAGMOM"), ...
                int64([0,0,1,0,0,0]));
            testCase.verifyEqual(incar("WANNIER90_WIN"), ...
                "begin Projections" + newline + ...
                "Fe:d ; Fe:p" + newline + "End Projections");
        end

        function incarMappingOperationsAndDiffAreStable(testCase)
            first = kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("ENCUT", 520, "ISMEAR", 0));
            first("algo") = "fast";
            testCase.verifyEqual(first("ALGO"), "Fast");
            second = first.copy();
            second("NSW") = 20;
            difference = first.diff(second);
            testCase.verifyTrue(isfield(difference.Different, "NSW"));
            testCase.verifyEqual(difference.Different.NSW.INCAR2, int64(20));
            merged = first + kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("SIGMA", 0.05));
            testCase.verifyEqual(merged("SIGMA"), 0.05);
            testCase.verifyError(@() first + ...
                kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("ENCUT", 400)), ...
                "KSSOLV:Matgenlab:Incar:Conflict");
        end

        function incarDuplicateAndInvalidTagWarningsAreExplicit(testCase)
            testCase.verifyWarning(@() ...
                kssolv.analysis.matgenlab.io.vasp.Incar.from_str( ...
                "encut=400" + newline + "ENCUT=500"), ...
                "KSSOLV:Matgenlab:BadIncarWarning");
            incar = kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("NOT_A_VASP_TAG", 1));
            testCase.verifyWarning(@() incar.check_params(), ...
                "KSSOLV:Matgenlab:BadIncarWarning");
        end

        function incarFileIoAndDictionaryRoundTrip(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            incar = kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("ENCUT", 520, "LASPH", true));
            filename = fullfile(folder, "INCAR.gz");
            incar.write_file(filename);
            restored = ...
                kssolv.analysis.matgenlab.io.vasp.Incar.from_file(filename);
            testCase.verifyEqual(restored, incar);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp.Incar. ...
                from_dict(incar.as_dict()), incar);
            clear cleanup
        end

        function incarSerializationMatchesFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                isAvailable());
            contents = strjoin([
                "ENCUT = 520"
                "LASPH = T"
                "LREAL = Auto"
                "MAGMOM = 1*6.0 2*-6.0 3*0.6"
                ], newline);
            request = struct("module", "pymatgen.io.vasp.inputs", ...
                "symbol", "Incar", "construct", struct( ...
                "method", "from_str", "args", {{contents}}), ...
                "operations", {{struct("kind", "call", "name", ...
                "get_str", "kwargs", struct("sort_keys", true))}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            actual = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                from_str(contents);
            testCase.verifyEqual(actual.get_str(sort_keys = true), ...
                string(reference.results{1}));
        end

        function supportedKpointModesAreCaseInsensitive(testCase)
            modes = ["Automatic","Gamma","Monkhorst", ...
                "Line_mode","Cartesian","Reciprocal"];
            for mode = modes
                class = kssolv.analysis.matgenlab.io.vasp. ...
                    KpointsSupportedModes;
                testCase.verifyEqual(class.from_str(lower(mode)), mode);
                testCase.verifyEqual(class.from_str(extractBefore(mode, 2)), ...
                    mode);
            end
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.vasp. ...
                KpointsSupportedModes.from_str("invalid"), ...
                "KSSOLV:Matgenlab:Kpoints:InvalidMode");
        end

        function kpointsParsesAndWritesEveryFileMode(testCase)
            cases = {
                strjoin(["mesh","0","Gamma","4 4 4","0.5 0.5 0.5"], newline)
                strjoin(["basis","0","Cartesian", ...
                    "0.25 0 0","0 0.25 0","0 0 0.25","0.5 0.5 0.5"], newline)
                strjoin(["bands","12","Line-mode","Reciprocal", ...
                    "0 0 0 ! G","0.5 0 0 ! X"], newline)
                strjoin(["explicit","2","Cartesian", ...
                    "0 0 0 1 G","0.5 0.5 0.5 2 R", ...
                    "Tetrahedron","1 0.5","6 1 2 1 2"], newline)
                };
            for index = 1:numel(cases)
                parsed = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    from_str(cases{index});
                restored = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    from_str(char(parsed));
                testCase.verifyEqual(restored, parsed);
            end
        end

        function kpointConvenienceConstructorsAndDensity(testCase)
            gamma = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                gamma_automatic([3,3,3], [0,0,0]);
            monkhorst = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                monkhorst_automatic([2,2,2], [0,0,0]);
            testCase.verifyEqual(gamma.style, "Gamma");
            testCase.verifyEqual(monkhorst.style, "Monkhorst");
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                3 * eye(3), {"Al"}, [0,0,0]);
            density = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                automatic_density(structure, 1000);
            testCase.verifyEqual(density.kpts, [10,10,10]);
            lengths = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                automatic_density_by_lengths(structure, [50,50,1]);
            testCase.verifyEqual(lengths.kpts, [17,17,1]);
        end

        function kpointsDictionaryCopyAndValidation(testCase)
            source = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = "test", num_kpts = 2, style = "Reciprocal", ...
                kpts = [0,0,0; .5,.5,.5], ...
                kpts_weights = [1,2], labels = ["G","R"]);
            restored = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                from_dict(source.as_dict());
            testCase.verifyEqual(restored, source);
            testCase.verifyEqual(source.copy(), source);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                kpts = [1,1]), ...
                "KSSOLV:Matgenlab:Kpoints:InvalidKpoint");
        end

        function kpointsSerializationMatchesFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                isAvailable());
            contents = strjoin([
                "Example file"
                "4"
                "Cartesian"
                "0 0 0 1"
                "0 0 0.5 1"
                "0 0.5 0.5 2"
                "0.5 0.5 0.5 4"
                ], newline);
            request = struct("module", "pymatgen.io.vasp.inputs", ...
                "symbol", "Kpoints", "construct", struct( ...
                "method", "from_str", "args", {{contents}}), ...
                "operations", {{struct("kind", "call", ...
                "name", "__str__")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            actual = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                from_str(contents);
            testCase.verifyEqual(string(actual), string(reference.results{1}));
        end

        function potcarSingleParsesMetadataAndElectronConfiguration(testCase)
            warning("off", "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning"));
            single = kssolv.analysis.matgenlab.io.vasp.PotcarSingle( ...
                testCase.syntheticPotcar("Fe", 8));
            testCase.verifyEqual(single.symbol, "Fe");
            testCase.verifyEqual(single.element, "Fe");
            testCase.verifyEqual(single.atomic_no, 26);
            testCase.verifyEqual(single.nelectrons, 8);
            testCase.verifyEqual(single.functional, "PBE");
            testCase.verifyEqual(single.functional_class, "GGA");
            testCase.verifyEqual(single.potential_type, "PAW");
            testCase.verifyEqual(single.ENMAX, 300);
            configuration = single.electron_configuration;
            testCase.verifyEqual(configuration(:, 1), {3;4});
            testCase.verifyEqual(string(configuration(:, 2)), ["d";"s"]);
            testCase.verifyEqual(cell2mat(configuration(:, 3)), [7;1]);
            clear cleanup
        end

        function potcarCollectionRoundTripsAndExposesSpecs(testCase)
            warning("off", "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning"));
            raw = testCase.syntheticPotcar("Fe", 8) + ...
                testCase.syntheticPotcar("O", 6);
            potcar = kssolv.analysis.matgenlab.io.vasp.Potcar.from_str(raw);
            testCase.verifyEqual(potcar.symbols, ["Fe","O"]);
            testCase.verifyEqual(potcar.count, 2);
            testCase.verifyEqual(potcar(1).nelectrons, 8);
            restored = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                from_str(char(potcar));
            testCase.verifyEqual(restored.symbols, potcar.symbols);
            testCase.verifyEqual(numel(potcar.spec), 2);
            clear cleanup
        end

        function potcarMetadataMatchesFrozenOracle(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                isAvailable());
            raw = testCase.syntheticPotcar("Fe", 8);
            request = struct("module", "pymatgen.io.vasp.inputs", ...
                "symbol", "PotcarSingle", ...
                "construct", struct("args", {{raw}}), ...
                "operations", {{ ...
                struct("kind", "get", "name", "symbol"), ...
                struct("kind", "get", "name", "functional"), ...
                struct("kind", "get", "name", "potential_type"), ...
                struct("kind", "get", "name", "nelectrons"), ...
                struct("kind", "get", ...
                "name", "electron_configuration")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle. ...
                execute(request);
            warning("off", "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning"));
            actual = kssolv.analysis.matgenlab.io.vasp.PotcarSingle(raw);
            testCase.verifyEqual(actual.symbol, string(reference.results{1}));
            testCase.verifyEqual(actual.functional, ...
                string(reference.results{2}));
            testCase.verifyEqual(actual.potential_type, ...
                string(reference.results{3}));
            testCase.verifyEqual(actual.nelectrons, reference.results{4});
            referenceConfiguration = reference.results{5};
            for index = 1:numel(referenceConfiguration)
                row = referenceConfiguration{index};
                testCase.verifyEqual(actual.electron_configuration{index, 1}, ...
                    row{1});
                testCase.verifyEqual(actual.electron_configuration{index, 2}, ...
                    string(row{2}));
                testCase.verifyEqual(actual.electron_configuration{index, 3}, ...
                    row{3});
            end
            clear cleanup
        end

        function potcarSymbolMapAndMissingDirectorySemantics(testCase)
            warning("off", "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning"));
            mapping = containers.Map("X", ...
                char(testCase.syntheticPotcar("Fe", 8)));
            potcar = kssolv.analysis.matgenlab.io.vasp.Potcar( ...
                "X", "PBE", mapping);
            testCase.verifyEqual(potcar.symbols, "Fe");
            previous = getenv("PMG_VASP_PSP_DIR");
            environmentCleanup = onCleanup(@() setenv( ...
                "PMG_VASP_PSP_DIR", previous));
            setenv("PMG_VASP_PSP_DIR", "");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                from_symbol_and_functional("Fe", "PBE"), ...
                "KSSOLV:Matgenlab:PmgVaspPspDirError");
            clear environmentCleanup cleanup
        end

        function potcarScramblerRetainsReadableMetadata(testCase)
            warning("off", "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning("on", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning"));
            rng(17);
            original = kssolv.analysis.matgenlab.io.vasp.PotcarSingle( ...
                testCase.syntheticPotcar("Fe", 8));
            scrambler = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarScrambler(original);
            testCase.verifyNotEqual(scrambler.scrambled_potcars_str, ...
                original.data);
            testCase.verifySubstring(scrambler.scrambled_potcars_str, ...
                "TITEL");
            restored = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                from_str(scrambler.scrambled_potcars_str);
            testCase.verifyEqual(restored.symbols, "Fe");
            clear cleanup
        end

        function vaspInputWritesAndReadsStandardSet(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                3 * eye(3), {"Si"}, [0,0,0]);
            inputs = kssolv.analysis.matgenlab.io.vasp.VaspInput( ...
                struct("ENCUT", 520), ...
                kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                gamma_automatic(), ...
                kssolv.analysis.matgenlab.io.vasp.Poscar(structure), ...
                "Si", potcar_spec = true);
            folder = string(tempname);
            cleanup = onCleanup(@() rmdir(folder, "s"));
            inputs.write_input(output_dir = folder);
            testCase.verifyTrue(isfile(fullfile(folder, "INCAR")));
            testCase.verifyTrue(isfile(fullfile(folder, "KPOINTS")));
            testCase.verifyTrue(isfile(fullfile(folder, "POSCAR")));
            testCase.verifyTrue(isfile(fullfile(folder, "POTCAR.spec")));
            restored = ...
                kssolv.analysis.matgenlab.io.vasp.VaspInput. ...
                from_directory(folder);
            testCase.verifyEqual(restored.incar("ENCUT"), 520);
            testCase.verifyEqual(restored.kpoints.style, "Gamma");
            testCase.verifyEqual(restored.poscar.structure.formula, "Si1");
            testCase.verifyEqual(string(restored.potcar), "Si");
            clear cleanup
        end

        function warningAndErrorCategoriesAreExposed(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp.BadIncarWarning.identifier, ...
                "KSSOLV:Matgenlab:BadIncarWarning");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp.BadPotcarWarning.identifier, ...
                "KSSOLV:Matgenlab:BadPotcarWarning");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp.PotcarHashMismatch.identifier, ...
                "KSSOLV:Matgenlab:PotcarHashMismatch");
        end
    end

    methods (Static, Access = private)
        function text = syntheticPotcar(symbol, zval)
            text = strjoin([
                "PAW_PBE " + symbol + " 01Jan2000"
                "parameters from PSCTR are:"
                "VRHFIN = " + symbol + ": 3d4s;"
                "LEXCH = PE;"
                "TITEL = PAW_PBE " + symbol + " 01Jan2000;"
                "LULTRA = F;"
                "LPAW = T;"
                "POMASS = 55.0;"
                "ZVAL = " + zval + ";"
                "ENMAX = 300.0;"
                "Atomic configuration"
                "2 entries"
                "n l j E occ."
                "3 2 2.5 -4.0 7.0"
                "4 0 0.5 -3.0 1.0"
                "Description"
                "2 -4.0 23 2.3"
                "Error from kinetic energy argument (eV)"
                "END of PSCTR-controll parameters"
                "Local Part"
                "1.0 2.0 True"
                "End of Dataset"
                ], newline) + newline;
        end
    end
end
