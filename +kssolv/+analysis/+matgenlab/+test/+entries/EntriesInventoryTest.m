classdef EntriesInventoryTest < matlab.unittest.TestCase
    % Frozen pymatgen.entries namespace and mixing scheme inventory.

    methods (Test)
        function aliasesAndMixingBehavior(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.entries.*
            entry=Entry("Li",-1);
            testCase.verifyEqual(entry.reduced_formula,"Li");
            testCase.verifyEqual(entry.energy,-1);

            hydrogen=Structure(5*eye(3),{"H"},[0,0,0]);
            oxygen=Structure(5*eye(3),{"O"},[0,0,0]);
            values={mixEntry(hydrogen,0,"GGA","h-gga"), ...
                mixEntry(oxygen,0,"GGA","o-gga"), ...
                mixEntry(hydrogen,-1,"r2SCAN","h-scan"), ...
                mixEntry(oxygen,-1,"r2SCAN","o-scan")};
            scheme=MaterialsProjectDFTMixingScheme( ...
                "compat_1",[],"compat_2",[]);
            state=scheme.get_mixing_state_data(values);
            testCase.verifyEqual(height(state),2);
            testCase.verifyEmpty(scheme.get_adjustments(values{3}, ...
                "mixing_state_data",state));
            testCase.verifyEqual(height(scheme.display_entries(values)),4);
            processed=scheme.process_entries(values);
            testCase.verifyEqual(numel(processed),2);
            testCase.verifyTrue(all(cellfun(@(item) ...
                string(item.parameters.run_type)=="r2SCAN",processed)));
            testCase.verifyEqual(scheme.as_dict().x_module, ...
                "pymatgen.entries.mixing_scheme");
        end

        function frozenInventoryIsExact(testCase)
            inventory=fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev","matgenlab","inventory","api.csv");
            options=detectImportOptions(inventory,"TextType","string");
            rows=readtable(inventory,options);
            rows=rows(startsWith(rows.module,"pymatgen.entries"),:);
            testCase.verifyEqual(height(rows),7);

            mixing="kssolv.analysis.matgenlab.entries."+ ...
                "MaterialsProjectDFTMixingScheme";
            available=string(methods(char(mixing)));
            for index=1:height(rows)
                if rows.module(index)=="pymatgen.entries"
                    testCase.verifyTrue(any(rows.qualname(index)== ...
                        ["annotations","Entry"]));
                elseif rows.kind(index)=="class"
                    testCase.verifyEqual(exist(mixing,"class"),8);
                else
                    qualified=split(rows.qualname(index),".");
                    testCase.verifyTrue(any(available==qualified(2)));
                end
            end
        end
    end
end

function entry=mixEntry(structure,energy,runType,id)
entry=kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
    structure,energy,"parameters",struct(run_type=runType), ...
    "entry_id",id);
end
