classdef VaspSetsTest < matlab.unittest.TestCase
    % Frozen parity and behavior tests for pymatgen.io.vasp.sets.

    methods (Test)
        function majorSetsMatchFrozenOracle(testCase)
            [structure, oracle] = testCase.fixture();
            names = ["MITRelaxSet","MPRelaxSet","MPScanRelaxSet", ...
                "MP24RelaxSet","MPMetalRelaxSet","MPHSERelaxSet", ...
                "MPStaticSet","MatPESStaticSet","MPScanStaticSet", ...
                "MP24StaticSet","MPNMRSet","MVLGWSet", ...
                "MPAbsorptionSet"];
            previous = warning("off", ...
                "KSSOLV:Matgenlab:Kpoints:KspacingPreferred");
            cleanup = onCleanup(@() warning(previous));
            for name = names
                constructor = str2func( ...
                    "kssolv.analysis.matgenlab.io.vasp." + name);
                generator = constructor(structure);
                reference = oracle.(char(name));
                testCase.verifyEqual(generator.potcar_symbols, ...
                    string(reference.potcar_symbols).', ...
                    "POTCAR symbols differ for " + name);
                expectedIncar = reference.incar;
                for tag = ["ENCUT","NSW","ISMEAR","LORBIT","KSPACING"]
                    if isfield(expectedIncar, char(tag))
                        testCase.verifyEqual( ...
                            double(generator.incar.get(tag)), ...
                            double(expectedIncar.(char(tag))), ...
                            "INCAR differs for " + name + "/" + tag, ...
                            AbsTol = 1e-12);
                    end
                end
                if isfield(reference, "kpoints") && ...
                        ~isempty(reference.kpoints)
                    testCase.verifyEqual(generator.kpoints.kpts, ...
                        double(reference.kpoints.kpoints), ...
                        "KPOINTS differs for " + name);
                else
                    testCase.verifyEmpty(generator.kpoints);
                end
            end
            clear cleanup
        end

        function everyConcreteSetBuildsPotcarSpec(testCase)
            [structure, ~] = testCase.fixture();
            names = ["MITRelaxSet","MPRelaxSet","MPScanRelaxSet", ...
                "MP24RelaxSet","MPMetalRelaxSet","MPHSERelaxSet", ...
                "MPStaticSet","MatPESStaticSet","MPScanStaticSet", ...
                "MP24StaticSet","MPHSEBSSet","MPNonSCFSet", ...
                "MPSOCSet","MPNMRSet","MVLElasticSet","MVLGWSet", ...
                "MVLSlabSet","MVLGBSet","MVLRelax52Set","MITMDSet", ...
                "MPMDSet","MVLNPTMDSet","MVLScanRelaxSet", ...
                "MPAbsorptionSet"];
            previous = warning("off", ...
                "KSSOLV:Matgenlab:Kpoints:KspacingPreferred");
            cleanup = onCleanup(@() warning(previous));
            for name = names
                constructor = str2func( ...
                    "kssolv.analysis.matgenlab.io.vasp." + name);
                generator = constructor(structure);
                inputs = generator.get_input_set(potcar_spec = true);
                testCase.verifyEqual(inputs.keys(), ...
                    ["INCAR","KPOINTS","POSCAR","POTCAR.spec"]);
                testCase.verifyClass(inputs.incar, ...
                    "kssolv.analysis.matgenlab.io.vasp.Incar");
                testCase.verifyClass(inputs.poscar, ...
                    "kssolv.analysis.matgenlab.io.vasp.Poscar");
            end
            clear cleanup
        end

        function writeAndReadDirectoryRoundTrip(testCase)
            [structure, ~] = testCase.fixture();
            folder = string(tempname);
            cleanup = onCleanup(@() testCase.removeFolder(folder));
            generator = kssolv.analysis.matgenlab.io.vasp. ...
                MPStaticSet(structure);
            generator.write_input(folder, potcar_spec = true);
            testCase.verifyTrue(isfile(fullfile(folder, "INCAR")));
            testCase.verifyTrue(isfile(fullfile(folder, "KPOINTS")));
            testCase.verifyTrue(isfile(fullfile(folder, "POSCAR")));
            testCase.verifyTrue(isfile(fullfile(folder, "POTCAR.spec")));
            restored = kssolv.analysis.matgenlab.io.vasp. ...
                VaspInputSet.from_directory(folder);
            testCase.verifyEqual(restored.incar.get("NSW"), int64(0));
            testCase.verifyEqual(restored.poscar.structure.formula, ...
                structure.formula);
            clear cleanup
        end

        function potcarBoundaryRequiresExplicitAuthorization(testCase)
            [structure, ~] = testCase.fixture();
            generator = kssolv.analysis.matgenlab.io.vasp. ...
                MPRelaxSet(structure);
            testCase.verifyError(@() testCase.readPotcar(generator), ...
                "KSSOLV:Matgenlab:VaspInputSet:PotcarAuthorization");
            testCase.verifyError(@() generator.get_input_set(), ...
                "KSSOLV:Matgenlab:VaspInputSet:PotcarAuthorization");
            spec = generator.get_input_set(potcar_spec = true);
            testCase.verifyEqual(strtrim(string(spec.potcar)), "Si");
        end

        function previousInputsAndSerializationAreStable(testCase)
            [structure, ~] = testCase.fixture();
            source = string(tempname);
            cleanup = onCleanup(@() testCase.removeFolder(source));
            base = kssolv.analysis.matgenlab.io.vasp. ...
                MPRelaxSet(structure);
            base.write_input(source, potcar_spec = true);
            child = kssolv.analysis.matgenlab.io.vasp. ...
                MPStaticSet([], user_incar_settings = struct("ENCUT",600));
            child = child.override_from_prev_calc(source);
            testCase.verifyEqual(child.structure.formula, structure.formula);
            testCase.verifyEqual(double(child.incar.get("ENCUT")), 600);
            encoded = child.as_dict();
            restored = kssolv.analysis.matgenlab.io.vasp. ...
                VaspInputSet.from_dict(encoded);
            testCase.verifyEqual(restored.structure.formula, ...
                child.structure.formula);
            testCase.verifyEqual(double(restored.incar.get("ENCUT")), 600);
            terse = child.as_dict(1);
            testCase.verifyFalse(isfield(terse, "structure"));
            clear cleanup
        end

        function nebWritesAllImagesAndClimbingFlag(testCase)
            [structure, ~] = testCase.fixture();
            folder = string(tempname);
            cleanup = onCleanup(@() testCase.removeFolder(folder));
            generator = kssolv.analysis.matgenlab.io.vasp. ...
                CINEBSet({structure, structure, structure});
            testCase.verifyEqual(numel(generator.poscars), 3);
            testCase.verifyTrue(generator.incar.get("LCLIMB"));
            testCase.verifyEqual(generator.incar.get("IMAGES"), int64(1));
            generator.write_input(folder, potcar_spec = true);
            for image = ["00","01","02"]
                testCase.verifyTrue(isfile( ...
                    fullfile(folder, image, "POSCAR")));
            end
            clear cleanup
        end

        function numericalHelpersMatchFrozenBehavior(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp.primes_less_than(9), ...
                [2,3,5,7]);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp. ...
                next_num_with_prime_factors(17, 7, true), 18);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp. ...
                auto_kspacing(0, 1e-4), 0.22, AbsTol = 1e-15);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.io.vasp. ...
                auto_kspacing(4, 1e-4), 0.44, AbsTol = 1e-15);
        end
    end

    methods (Static, Access = private)
        function [structure, oracle] = fixture()
            folder = fullfile(fileparts(mfilename("fullpath")), ...
                "+fixtures", "+vasp_sets");
            structure = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_file(fullfile(folder, "POSCAR_Si")).structure;
            oracle = jsondecode(fileread(fullfile(folder, ...
                "oracle_sets_2026_7_24.json")));
        end

        function value = readPotcar(generator)
            value = generator.potcar;
        end

        function removeFolder(folder)
            if isfolder(folder), rmdir(folder, "s"); end
        end
    end
end
