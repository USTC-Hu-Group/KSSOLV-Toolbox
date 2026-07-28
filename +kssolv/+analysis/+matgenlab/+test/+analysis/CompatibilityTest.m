classdef CompatibilityTest < matlab.unittest.TestCase
    %COMPATIBILITYTEST Frozen pymatgen compatibility-module acceptance.
    methods (Test)
        function mp2020FrozenOracle(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            entry=ComputedEntry("Fe2O3",-10,"parameters",struct( ...
                run_type="GGA+U",hubbards=struct(Fe=5.3), ...
                software="other"),"data",struct(oxide_type="oxide", ...
                oxidation_states=struct(Fe=3,O=-2)));
            scheme=MaterialsProject2020Compatibility("check_potcar",false);
            adjustments=scheme.get_adjustments(entry);
            oracle=compatibilityOracle();
            testCase.verifyNumElements(adjustments,2);
            testCase.verifyEqual(adjustments{1}.value, ...
                oracle.mp2020_fe2o3.oxide,AbsTol=1e-12);
            testCase.verifyEqual(adjustments{2}.value, ...
                oracle.mp2020_fe2o3.gga_u_mixing_fe,AbsTol=1e-12);
            processed=scheme.process_entry(entry,"inplace",false);
            testCase.verifyEqual(processed.correction, ...
                oracle.mp2020_fe2o3.total,AbsTol=1e-12);
            testCase.verifyEqual(needs_u_correction("Fe2O3"),["Fe","O"]);
        end

        function legacyAndAqueousRules(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            legacy=MaterialsProjectCompatibility("check_potcar_hash",false);
            entry=ComputedEntry("Fe2O3",-10,"parameters",struct( ...
                run_type="GGA+U",hubbards=struct(Fe=5.3), ...
                potcar_symbols={{"PAW_PBE Fe_pv 06Sep2000", ...
                "PAW_PBE O 08Apr2002"}}),"data",struct(oxide_type="oxide"));
            testCase.verifyNotEmpty(legacy.process_entry(entry,"inplace",false));

            aqueous=MaterialsProjectAqueousCompatibility( ...
                "solid_compat","none","o2_energy",-10, ...
                "h2o_energy",-20,"h2o_adjustments",-0.5);
            oxygen=ComputedEntry("O2",-10);
            result=aqueous.process_entries(oxygen);oxygen=result{1};
            testCase.verifyEqual(oxygen.correction_per_atom,-0.316731, ...
                AbsTol=1e-12);
            hydrate=ComputedEntry("FeH4O2",-10);
            result=aqueous.process_entries(hydrate);hydrate=result{1};
            testCase.verifyEqual(hydrate.correction, ...
                2*(2.4583-3*(-0.5)),AbsTol=1e-12);
        end

        function experimentalEntryRoundTrip(testCase)
            data=kssolv.analysis.matgenlab.analysis.ThermoData( ...
                "fH","Iron oxide","solid","Fe2O3",-825.5);
            entry=kssolv.analysis.matgenlab.analysis.compatibility. ...
                ExpEntry("Fe2O3",{data});
            testCase.verifyEqual(entry.energy,-825.5,AbsTol=1e-12);
            restored=kssolv.analysis.matgenlab.analysis.compatibility. ...
                ExpEntry.from_dict(entry.as_dict());
            testCase.verifyEqual(restored.energy,entry.energy,AbsTol=1e-12);
        end

        function gibbsOfficialFixtures(testCase)
            root=compatibilityFixtureRoot();
            testCase.assumeTrue(strlength(root)>0, ...
                "Official compatibility fixtures unavailable.");
            run=kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
                fullfile(root,"vasprun.xml.gz"),"parse_dos",false, ...
                "parse_eigen",false,"parse_potcar_file",false);
            oracle=compatibilityOracle();
            entry=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry(run.final_structure,-2.436, ...
                "temp",300);
            testCase.verifyEqual(entry.energy,oracle.gibbs.lifepo4_300, ...
                AbsTol=1e-10);
            entry=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry(run.final_structure,-2.436, ...
                "temp",450);
            testCase.verifyEqual(entry.energy,oracle.gibbs.lifepo4_450, ...
                AbsTol=1e-10);
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                jsondecode(fileread(fullfile(root,"structure_CO2.json"))));
            entry=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry(structure,0,"temp",900);
            testCase.verifyEqual(entry.energy,oracle.gibbs.co2_900, ...
                AbsTol=1e-10);
            restored=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.from_dict(entry.as_dict());
            testCase.verifyEqual(restored.energy,entry.energy,AbsTol=1e-12);

            import kssolv.analysis.matgenlab.core.*
            hydrogen=Structure(Lattice.cubic(5),{"H"},[0,0,0]);
            oxygen=Structure(Lattice.cubic(5),{"O"},[0,0,0]);
            water=Structure(Lattice.cubic(5),{"H","H","O"}, ...
                [0,0,0;.2,0,0;.1,.1,0]);
            entries={ComputedStructureEntry(hydrogen,0), ...
                ComputedStructureEntry(oxygen,0), ...
                ComputedStructureEntry(water,-3)};
            fromEntries=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.from_entries(entries);
            diagram=kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries);
            fromDiagram=kssolv.analysis.matgenlab.analysis.compatibility. ...
                GibbsComputedStructureEntry.from_pd(diagram);
            testCase.verifyNumElements(fromEntries,3);
            testCase.verifyEqual(cellfun(@(item)item.energy,fromEntries), ...
                cellfun(@(item)item.energy,fromDiagram),AbsTol=1e-12);
        end

        function correctionCalculatorOfficialFixtures(testCase)
            root=compatibilityFixtureRoot();
            folder=fullfile(root,"correction_calculator");
            testCase.assumeTrue(isfile(fullfile(folder, ...
                "exp_compounds_norm.json.gz")));
            calculator=kssolv.analysis.matgenlab.analysis.compatibility. ...
                CorrectionCalculator();
            actual=calculator.compute_from_files(fullfile(folder, ...
                "exp_compounds_norm.json.gz"),fullfile(folder, ...
                "calc_compounds_norm.json.gz"));
            expected=compatibilityOracle().correction_calculator;
            names=fieldnames(expected);
            for index=1:numel(names)
                testCase.verifyEqual(actual.(names{index}), ...
                    reshape(expected.(names{index}),1,[]),AbsTol=1e-12);
            end
            axesHandle=calculator.graph_residual_error();
            testCase.verifyTrue(isgraphics(axesHandle,"axes"));
            close(axesHandle.Parent);
            specie=calculator.species(find(any( ...
                calculator.coeff_mat~=0,1),1));
            axesHandle=calculator.graph_residual_error_per_species(specie);
            testCase.verifyTrue(isgraphics(axesHandle,"axes"));
            close(axesHandle.Parent);
            folder=string(tempname);
            mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,"s"));
            path=calculator.make_yaml("name","Frozen", ...
                "dir",folder);
            testCase.verifyTrue(isfile(path));
            testCase.verifyTrue(contains(fileread(path), ...
                "Name: Frozen"));
            clear cleanup
        end

        function mixingStateAndSelection(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.analysis.compatibility.*
            hydrogen=Structure(5*eye(3),{"H"},[0,0,0]);
            oxygen=Structure(5*eye(3),{"O"},[0,0,0]);
            entries={mixEntry(hydrogen,0,"GGA","h-gga"), ...
                mixEntry(oxygen,0,"GGA","o-gga"), ...
                mixEntry(hydrogen,-1,"r2SCAN","h-scan"), ...
                mixEntry(oxygen,-1,"r2SCAN","o-scan")};
            scheme=MaterialsProjectDFTMixingScheme("compat_1",[], ...
                "compat_2",[]);
            state=scheme.get_mixing_state_data(entries);
            testCase.verifyEqual(height(state),2);
            testCase.verifyEmpty(scheme.get_adjustments(entries{3}, ...
                "mixing_state_data",state));
            testCase.verifyEqual(height(scheme.display_entries(entries)),4);
            output=scheme.process_entries(entries);
            testCase.verifyEqual(numel(output),2);
            testCase.verifyTrue(all(cellfun(@(item) ...
                string(item.parameters.run_type)=="r2SCAN",output)));

            function entry=mixEntry(structure,energy,runType,id)
                entry=ComputedStructureEntry(structure,energy, ...
                    "parameters",struct(run_type=runType), ...
                    "entry_id",id);
            end
        end
    end
end

function value=compatibilityOracle()
path=fullfile(fileparts(mfilename("fullpath")),"+fixtures", ...
    "compatibility_oracle.json");
value=jsondecode(fileread(path));
end

function root=compatibilityFixtureRoot()
roots=[string(getenv("MATGENLAB_PYMATGEN_ANALYSIS")), ...
    "/tmp/matgenlab-analysis.n8g66Z/pymatgen/test-files/entries", ...
    string(getenv("MATGENLAB_PYMATGEN_CORE"))+ ...
    "/test-files/entries"];
root="";
for candidate=roots
    if strlength(candidate)>0&&isfile(fullfile(candidate, ...
            "structure_CO2.json"))
        root=candidate;return
    end
end
end
