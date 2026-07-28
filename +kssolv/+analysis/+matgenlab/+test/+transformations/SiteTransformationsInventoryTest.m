classdef SiteTransformationsInventoryTest < matlab.unittest.TestCase
    % Resolve the frozen site and abstract transformation API inventory.

    methods (Test)
        function frozenInventoryLedgerIsComplete(testCase)
            inventory=fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev","matgenlab","inventory","api.csv");
            options=detectImportOptions(inventory,"TextType","string");
            rows=readtable(inventory,options);
            selected=ismember(rows.module,[ ...
                "pymatgen.transformations.site_transformations", ...
                "pymatgen.transformations.transformation_abc"]);
            rows=rows(selected,:);
            testCase.verifyEqual(height(rows),24);

            implemented=false(height(rows),1);
            for index=1:height(rows)
                qualified=split(rows.qualname(index),".");
                target="kssolv.analysis.matgenlab.transformations."+ ...
                    qualified(1);
                if rows.kind(index)=="class"
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
                "Missing frozen site transformation APIs: "+ ...
                strjoin(missing,", "));
        end
    end
end
