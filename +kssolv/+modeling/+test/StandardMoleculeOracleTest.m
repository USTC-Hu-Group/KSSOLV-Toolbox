classdef StandardMoleculeOracleTest < matlab.unittest.TestCase
    %STANDARDMOLECULEORACLETEST P4 independent 200-molecule gate.

    methods (TestClassSetup)
        function configureKssolvPaths(~)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
        end
    end

    methods (Test)
        function catalogIsDiverseStableAndUnique(testCase)
            entries = kssolv.modeling.test. ...
                StandardMoleculeOracleCatalog.entries();
            testCase.verifyNumElements(entries, 200);
            testCase.verifyNumElements(unique(string({entries.id})), 200);
            families = string({entries.family});
            testCase.verifyNumElements(unique(families), 20);
            for family = unique(families)
                testCase.verifyEqual(sum(families == family), 10);
            end
            allBonds = vertcat(entries.bonds);
            testCase.verifyTrue(all(ismember([1, 1.5, 2, 3], ...
                unique(allBonds(:, 3)))));
        end

        function hydrogenAndValenceRulesMatchIndependentOracle(testCase)
            entries = kssolv.modeling.test. ...
                StandardMoleculeOracleCatalog.entries();
            for entry = entries
                heavy = kssolv.modeling.test. ...
                    StandardMoleculeOracleCatalog.molecule(entry);
                hydrated = execute(heavy, "add_hydrogens", ...
                    struct("indices", 1:heavy.num_sites));
                actual = elementCounts(hydrated);
                expectedFields = fieldnames(entry.expectedCounts);
                for fieldIndex = 1:numel(expectedFields)
                    field = expectedFields{fieldIndex};
                    testCase.verifyEqual(actual.(field), ...
                        entry.expectedCounts.(field), ...
                        sprintf("%s expected %s", entry.id, ...
                        entry.expectedFormula));
                end
                testCase.verifyEqual(actual.H, entry.expectedHydrogens, ...
                    sprintf("%s hydrogen oracle", entry.id));

                heavyBonds = hydrated.properties.topology.bonds;
                heavyBonds = heavyBonds(all( ...
                    heavyBonds(:, 1:2) <= heavy.num_sites, 2), :);
                testCase.verifyEqual(sortrows(heavyBonds), ...
                    sortrows(entry.bonds), sprintf( ...
                    "%s heavy topology changed", entry.id));

                diagnostics = kssolv.modeling.chemistry. ...
                    MoleculeDiagnostics.inspect(hydrated);
                testCase.verifyEmpty(diagnostics.atomIssues, sprintf( ...
                    "%s valence diagnostics did not close", entry.id));
                assertHydrogenTopology(testCase, hydrated, ...
                    heavy.num_sites, entry.id);

                restored = execute(hydrated, "remove_hydrogens", ...
                    struct("indices", 1:heavy.num_sites));
                testCase.verifyEqual(siteSymbols(restored), ...
                    siteSymbols(heavy), sprintf( ...
                    "%s hydrogen removal changed species", entry.id));
                testCase.verifyEqual( ...
                    restored.properties.topology.bonds, ...
                    heavy.properties.topology.bonds, sprintf( ...
                    "%s hydrogen removal changed topology", entry.id));
            end
        end
    end
end

function model = execute(model, commandId, parameters)
result = kssolv.modeling.CommandExecutor.execute( ...
    model, commandId, parameters);
model = result.model;
end

function counts = elementCounts(model)
fields = ["C", "H", "N", "O", "S", "F", "Cl", "Br"];
counts = cell2struct(num2cell(zeros(1, numel(fields))), ...
    cellstr(fields), 2);
for symbol = siteSymbols(model)
    counts.(symbol) = counts.(symbol) + 1;
end
end

function symbols = siteSymbols(model)
symbols = strings(1, model.num_sites);
for index = 1:model.num_sites
    symbols(index) = string(model(index).specie.symbol);
end
end

function assertHydrogenTopology(testCase, model, heavyCount, identifier)
bonds = model.properties.topology.bonds;
for hydrogen = heavyCount + 1:model.num_sites
    connected = bonds(any(bonds(:, 1:2) == hydrogen, 2), :);
    testCase.verifySize(connected, [1, 3], sprintf( ...
        "%s hydrogen %d degree", identifier, hydrogen));
    testCase.verifyEqual(connected(3), 1, sprintf( ...
        "%s hydrogen %d bond order", identifier, hydrogen));
end
end
