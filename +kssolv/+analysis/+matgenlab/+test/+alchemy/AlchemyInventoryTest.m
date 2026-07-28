classdef AlchemyInventoryTest < matlab.unittest.TestCase
    % Validate every frozen alchemy inventory row against a real API member.

    methods (Test)
        function frozenInventoryLedgerIsComplete(testCase)
            inventory = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev", "matgenlab", "inventory", "api.csv");
            options = detectImportOptions(inventory, "TextType", "string");
            rows = readtable(inventory, options);
            selected = startsWith(rows.module, "pymatgen.alchemy.");
            rows = rows(selected, :);
            testCase.verifyEqual(height(rows), 52);
            testCase.verifyEqual(sum(rows.module == ...
                "pymatgen.alchemy.filters"), 19);
            testCase.verifyEqual(sum(rows.module == ...
                "pymatgen.alchemy.materials"), 17);
            testCase.verifyEqual(sum(rows.module == ...
                "pymatgen.alchemy.transmuters"), 16);

            implemented = false(height(rows), 1);
            for index = 1:height(rows)
                qualified = split(rows.qualname(index), ".");
                if rows.kind(index) == "function"
                    target = "kssolv.analysis.matgenlab.alchemy." + ...
                        qualified(1);
                    implemented(index) = ~isempty(which(target));
                    continue
                end
                className = qualified(1);
                target = "kssolv.analysis.matgenlab.alchemy." + className;
                if rows.kind(index) == "class"
                    implemented(index) = exist(target, "class") == 8;
                elseif rows.kind(index) == "method"
                    implemented(index) = any(string(methods(char(target))) == ...
                        qualified(2));
                elseif rows.kind(index) == "property"
                    implemented(index) = any(string(properties(char(target))) == ...
                        qualified(2));
                end
            end
            missing = rows.qualname(~implemented);
            testCase.verifyTrue(all(implemented), ...
                "Missing frozen alchemy APIs: " + strjoin(missing, ", "));
        end
    end
end
