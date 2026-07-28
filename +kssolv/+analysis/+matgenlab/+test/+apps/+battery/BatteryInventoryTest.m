classdef BatteryInventoryTest < matlab.unittest.TestCase
    % Resolve every frozen pymatgen battery inventory row.

    methods (Test)
        function frozenInventoryLedgerIsComplete(testCase)
            inventory=fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev","matgenlab","inventory","api.csv");
            options=detectImportOptions(inventory,"TextType","string");
            rows=readtable(inventory,options);
            rows=rows(startsWith( ...
                rows.module,"pymatgen.apps.battery."),:);
            testCase.verifyEqual(height(rows),64);

            implemented=false(height(rows),1);
            for index=1:height(rows)
                qualified=split(rows.qualname(index),".");
                target="kssolv.analysis.matgenlab.apps.battery."+ ...
                    qualified(1);
                if rows.kind(index)=="function"
                    implemented(index)=~isempty(which(target));
                elseif rows.kind(index)=="class"
                    implemented(index)=exist(target,"class")==8;
                elseif rows.kind(index)=="method"
                    implemented(index)=any(string(methods(char(target)))== ...
                        qualified(2));
                elseif rows.kind(index)=="property"
                    implemented(index)=any(string(properties(char(target)))== ...
                        qualified(2));
                end
            end
            missing=rows.qualname(~implemented);
            testCase.verifyTrue(all(implemented), ...
                "Missing frozen battery APIs: "+strjoin(missing,", "));
        end
    end
end
