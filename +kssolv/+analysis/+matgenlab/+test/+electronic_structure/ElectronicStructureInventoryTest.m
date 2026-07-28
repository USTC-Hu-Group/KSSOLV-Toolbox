classdef ElectronicStructureInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function frozenInventoryIsFullyImplemented(testCase)
            root = KSSOLV_Toolbox.RootDirectory;
            ledger = readtable(fullfile(root, "dev", "matgenlab", ...
                "inventory", "compatibility_ledger.csv"), ...
                TextType="string");
            selected = startsWith(ledger.module, ...
                "pymatgen.electronic_structure");
            rows = ledger(selected, :);
            testCase.verifyEqual(height(rows), 279);
            testCase.verifyTrue(all(rows.status == "implemented"), ...
                join(rows.api_id(rows.status ~= "implemented"), newline));
            package = "kssolv.analysis.matgenlab.electronic_structure.";
            failures = strings(0, 1);
            for index = 1:height(rows)
                row = rows(index, :);
                kind = string(row.kind);
                name = string(row.name);
                qualname = string(row.qualname);
                if name == "DOS", name = "Dos"; end
                switch kind
                    case "class"
                        present = ~isempty(meta.class.fromName( ...
                            package + name));
                    case "function"
                        present = strlength(string(which( ...
                            package + name))) > 0;
                    case {"method", "property"}
                        pieces = split(qualname, ".");
                        if pieces(1) == "DOS", pieces(1) = "Dos"; end
                        metadata = meta.class.fromName(package + pieces(1));
                        if isempty(metadata)
                            present = false;
                        elseif kind == "method"
                            present = any(metadataNames( ...
                                metadata.MethodList) == pieces(end));
                        else
                            present = any(metadataNames( ...
                                metadata.PropertyList) == pieces(end));
                        end
                    otherwise
                        present = true;
                end
                if ~present
                    failures(end + 1) = string(row.api_id); %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(failures, join(failures, newline));
        end
    end
end

function names = metadataNames(values)
if iscell(values), values = [values{:}]; end
names = string({values.Name});
end
