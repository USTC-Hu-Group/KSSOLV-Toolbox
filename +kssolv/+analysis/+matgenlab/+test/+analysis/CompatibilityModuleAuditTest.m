classdef CompatibilityModuleAuditTest < matlab.unittest.TestCase
    %COMPATIBILITYMODULEAUDITTEST Frozen v2026.5.4 module-level audit.
    methods (Test)
        function provenanceAndOfficialConfigs(testCase)
            oracle=moduleOracle();
            testCase.verifyEqual(string(oracle.upstream_tag),"v2026.5.4");
            testCase.verifyEqual(string(oracle.upstream_commit), ...
                "8495e941504cd5123701635b6572942c78d9589c");
            folder=productionData();
            names=["MITCompatibility.yaml","MPCompatibility.yaml", ...
                "MP2020Compatibility.yaml","SmoothPESCompatibility.yaml"];
            expected=[ ...
                "7903ee94d49cfd3e680c125d099a9e6f5314d127149ba0cd744823e9e54f3dc9", ...
                "76c87cc94820b3fc008ecf6c711e86e54f2157806b4548e7193db8c081df61eb", ...
                "90a5af2132c8eb85be1da4d89c2a78b58e045528bcba1189fa5ec356fb8e6d9a", ...
                "beb156f1745a005b2126e9f7a70982ffe22d460368f40ae005d12cf1700d06ba"];
            for index=1:numel(names)
                testCase.verifyEqual(fileHash(fullfile(folder,names(index))), ...
                    expected(index));
            end
        end

        function mp2020AdjustmentsAndGgaMode(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            oracle=moduleOracle().mp2020;
            parameters=struct(run_type="GGA+U", ...
                hubbards=struct(Fe=5.3,O=0),software="other");
            data=struct(oxide_type="oxide", ...
                oxidation_states=struct(Fe=3,O=-2));
            entry=ComputedEntry("Fe2O3",-1,"parameters",parameters,"data",data);
            scheme=MaterialsProject2020Compatibility("check_potcar",false);
            processed=scheme.process_entry(entry,"inplace",false);
            testCase.verifyEqual(processed.correction, ...
                oracle.fe2o3_correction,AbsTol=1e-12);

            parameters.run_type="GGA";parameters.hubbards=struct();
            entry=ComputedEntry("Fe2O3",-1,"parameters",parameters,"data",data);
            scheme=MaterialsProject2020Compatibility("compat_type","GGA", ...
                "check_potcar",false);
            processed=scheme.process_entry(entry);
            testCase.verifyEqual(processed.correction, ...
                oracle.gga_fe2o3_correction,AbsTol=1e-12);
            testCase.verifyNumElements(processed.energy_adjustments,1);

            parameters=struct(run_type="GGA+U", ...
                hubbards=struct(Fe=5.3,Co=3.32,O=0),software="other");
            entry=ComputedEntry("Fe2CoO4",-10,"parameters",parameters, ...
                "data",struct(oxide_type="oxide"));
            processed=MaterialsProject2020Compatibility( ...
                "check_potcar",false).process_entry(entry);
            testCase.verifyEqual(processed.correction, ...
                oracle.fe2coo4_correction,AbsTol=1e-12);
            testCase.verifyEqual(cellfun(@(item)item.value, ...
                processed.energy_adjustments), ...
                reshape(oracle.fe2coo4_values,1,[]),AbsTol=1e-12);
            testCase.verifyEqual(cellfun(@(item)item.uncertainty, ...
                processed.energy_adjustments), ...
                reshape(oracle.fe2coo4_uncertainties,1,[]),AbsTol=1e-12);
        end

        function alternateConfigAndStrictAnions(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            fixture=fullfile(fileparts(mfilename("fullpath")),"+fixtures", ...
                "+compatibility","MP2020Compatibility_alternate.yaml");
            entry=ComputedEntry("Fe2O3",-1,"parameters",struct( ...
                run_type="GGA+U",hubbards=struct(Fe=5.3,O=0), ...
                software="other"),"data",struct(oxide_type="oxide"));
            processed=MaterialsProject2020Compatibility("config_file",fixture, ...
                "check_potcar",false).process_entry(entry);
            names=string(cellfun(@(item)item.name, ...
                processed.energy_adjustments,"UniformOutput",false));
            index=find(contains(names,"mixing correction (Fe)"),1);
            testCase.verifyEqual(processed.energy_adjustments{index}.value, ...
                -0.224*2,AbsTol=1e-12);

            cuI=ComputedEntry("CuI9",-1,"parameters",struct( ...
                run_type="GGA",hubbards=struct(),software="other"));
            bound=MaterialsProject2020Compatibility("strict_anions", ...
                "require_bound","check_potcar",false).process_entry( ...
                cuI,"inplace",false);
            unchecked=MaterialsProject2020Compatibility("strict_anions", ...
                "no_check","check_potcar",false).process_entry( ...
                cuI,"inplace",false);
            exact=MaterialsProject2020Compatibility("strict_anions", ...
                "require_exact","check_potcar",false).process_entry( ...
                cuI,"inplace",false);
            testCase.verifyEqual([bound.energy,unchecked.energy,exact.energy], ...
                [-1,-4.411,-1],AbsTol=1e-12);
        end

        function legacyNamesMapsAndMitHash(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            oracle=moduleOracle();
            entry=ComputedEntry("Fe2O3",-1,"parameters",struct( ...
                run_type="GGA+U",hubbards=struct(Fe=5.3,O=0), ...
                potcar_symbols={{"PBE Fe_pv","PBE O"}}));
            scheme=MaterialsProjectCompatibility();
            explanation=scheme.get_explanation_dict(entry);
            testCase.verifyEqual(string({explanation.corrections.name}), ...
                string(oracle.legacy.explanation_names).');
            testCase.verifyEqual([explanation.corrections.value], ...
                reshape(oracle.legacy.explanation_values,1,[]),AbsTol=1e-12);
            [values,uncertainties]=scheme.get_corrections_dict(entry);
            testCase.verifyClass(values,"containers.Map");
            testCase.verifyEqual(values("MP Anion Correction"),-2.10687, ...
                AbsTol=1e-12);
            testCase.verifyTrue(isnan(uncertainties("MP Anion Correction")));

            spec={struct(titel="PAW_PBE Fe 06Sep2000", ...
                hash="9530da8244e4dac17580869b4adab115"), ...
                struct(titel="PAW_PBE O 08Apr2002", ...
                hash="7a25bc5b9a5393f46600a4939d357982")};
            entry=ComputedEntry("Fe2O3",-1,"parameters",struct( ...
                run_type="GGA+U",hubbards=struct(Fe=4,O=0), ...
                potcar_spec={spec}));
            processed=MITCompatibility("check_potcar_hash",true). ...
                process_entry(entry);
            testCase.verifyEqual(processed.correction, ...
                oracle.mit_hash_correction,AbsTol=1e-12);
            spec{1}.hash="different";
            entry.parameters.potcar_spec=spec;
            testCase.verifyEmpty(MITCompatibility( ...
                "check_potcar_hash",true).process_entry(entry));
            testCase.verifyError(@()MaterialsProjectCompatibility( ...
                "check_potcar_hash",true), ...
                "KSSOLV:Matgenlab:Compatibility:PotcarHashUnavailable");
        end

        function smoothPesOracle(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            oracle=moduleOracle().smooth;
            for index=1:numel(oracle.metals)
                metal=string(oracle.metals{index});
                hubbards=struct();hubbards.(metal)=oracle.u_values(index);
                hubbards.O=0;
                entry=ComputedEntry(metal+"O",-1,"parameters",struct( ...
                    run_type="GGA+U",hubbards=hubbards,software="other"));
                processed=SmoothPESCompatibility("check_potcar",false). ...
                    process_entry(entry);
                testCase.verifyEqual(processed.correction, ...
                    oracle.corrections(index),AbsTol=1e-12);
                testCase.verifyNumElements(processed.energy_adjustments,2);
                testCase.verifyTrue(contains( ...
                    processed.energy_adjustments{2}.name,metal));
            end
            sulfide=ComputedEntry("FeS",-1,"parameters",struct( ...
                run_type="GGA",hubbards=struct(),software="other"));
            processed=SmoothPESCompatibility("check_potcar",false). ...
                process_entry(sulfide);
            testCase.verifyEqual(processed.correction,0,AbsTol=1e-12);
            testCase.verifyNumElements(processed.energy_adjustments,1);
        end

        function aqueousAndLegacyCorrectEntry(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            oracle=moduleOracle().aqueous;
            scheme=MaterialsProjectAqueousCompatibility("solid_compat","none", ...
                "o2_energy",-10,"h2o_energy",-20,"h2o_adjustments",-0.5);
            entries={ComputedEntry("O2",-10),ComputedEntry("FeH4O2",-10), ...
                ComputedEntry("Li2O2H2",-10)};
            result=scheme.process_entries(entries);
            testCase.verifyEqual(cellfun(@(item)item.correction,result), ...
                [oracle.o2_correction,oracle.hydrate_correction, ...
                oracle.nonhydrate_correction],AbsTol=1e-12);

            correction=AqueousCorrection(fullfile(productionData(), ...
                "MITCompatibility.yaml"));
            water=correction.correct_entry(ComputedEntry("H2O",-16, ...
                "parameters",struct(run_type="GGA")));
            testCase.verifyEqual(water.energy,-14.916,AbsTol=1e-12);
        end

        function cleanupOverlapAndBatchSemantics(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.test.analysis.fixtures.FixedCompatibility
            oracle=moduleOracle().cleanup;
            existing=ConstantEnergyAdjustment(-5,"name","collision");
            entry=ComputedEntry("Fe2O3",-2,"energy_adjustments",{existing});
            scheme=FixedCompatibility(-6,"collision");
            warning("off","KSSOLV:Matgenlab:Compatibility:Overlap");
            cleanup=onCleanup(@()warning("on", ...
                "KSSOLV:Matgenlab:Compatibility:Overlap"));
            testCase.verifyNotEmpty(scheme.process_entry(entry,"clean",false));
            testCase.verifyEqual(oracle.single_overlap_returned,true);
            testCase.verifyNumElements(scheme.process_entries(entry, ...
                "clean",false),oracle.batch_overlap_count);

            entry=ComputedEntry("H2",-1,"correction",-4);
            processed=scheme.process_entries(entry);
            testCase.verifyEqual(processed{1}.correction, ...
                oracle.clean_default,AbsTol=1e-12);
            processed=scheme.process_entries(entry,"clean",false);
            testCase.verifyEqual(processed{1}.correction,-10,AbsTol=1e-12);
            testCase.verifyError(@()scheme.process_entries(entry, ...
                "n_workers",2),"KSSOLV:Matgenlab:Compatibility:ParallelInplace");
            copied=scheme.process_entries(entry,"n_workers",2,"inplace",false);
            testCase.verifyNumElements(copied,1);
        end

        function needsUCorrectionOracle(testCase)
            import kssolv.analysis.matgenlab.analysis.compatibility.needs_u_correction
            oracle=moduleOracle().needs_u;
            formulas=["Fe2O3","FeS","FeF3","LiH","LiFePO4","LiFePS4"];
            for formula=formulas
                expected=string(oracle.(formula));
                actual=sort(needs_u_correction(formula));
                testCase.verifyEqual(sort(actual),sort(reshape(expected,1,[])));
            end
        end
    end
end

function value=moduleOracle()
path=fullfile(fileparts(mfilename("fullpath")),"+fixtures", ...
    "compatibility_module_oracle.json");
value=jsondecode(fileread(path));
end

function folder=productionData()
source=which("kssolv.analysis.matgenlab.analysis.compatibility.Compatibility");
folder=fullfile(fileparts(source),"data");
end

function value=fileHash(path)
file=fopen(path,"rb");
cleanup=onCleanup(@()fclose(file));
bytes=fread(file,Inf,"*uint8");
digest=java.security.MessageDigest.getInstance("SHA-256");
digest.update(typecast(bytes,"int8"));
value=lower(string(reshape(dec2hex(typecast(digest.digest(), ...
    "uint8"),2).',1,[])));
end
