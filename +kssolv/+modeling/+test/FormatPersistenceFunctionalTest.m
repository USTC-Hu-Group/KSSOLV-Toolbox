classdef FormatPersistenceFunctionalTest < matlab.unittest.TestCase
    %FORMATPERSISTENCEFUNCTIONALTEST P1 six-format, ten-sample matrix.

    methods (Test)
        function sixFormatsAndProjectReopenPreserveTenEditedSamples(testCase)
            directory = string(tempname);
            mkdir(directory);
            cleanup = onCleanup(@()rmdir(directory, "s"));
            moleculeFormats = ["xyz", "mol", "sdf", "mol2", "pdb"];
            topologyFormats = ["mol", "sdf", "mol2"];
            project = kssolv.services.filemanager.Project();
            folder = project.findChildrenItem("Structure");
            expected = containers.Map("KeyType", "char", "ValueType", "any");

            for sample = 1:10
                molecule = moleculeFixture(sample);
                molecule = kssolv.modeling.CommandExecutor.execute( ...
                    molecule, "translate_atoms", struct( ...
                    "indices", [1, 4], "vector", ...
                    [.01 * sample, -.005 * sample, .002 * sample], ...
                    "fractional", false)).model;
                moleculeName = "P1 Molecule " + sample;
                addProjectItem(moleculeName, molecule);
                expected(char(moleculeName)) = molecule;

                for format = moleculeFormats
                    path = fullfile(directory, ...
                        sprintf("molecule-%02d.%s", sample, format));
                    molecule.to(path, format);
                    restored = kssolv.analysis.matgenlab.core.Molecule. ...
                        from_file(path, format);
                    testCase.verifyEqual(restored.num_sites, ...
                        molecule.num_sites, format + " sample " + sample);
                    testCase.verifyEqual(sort(restored.atomic_numbers), ...
                        sort(molecule.atomic_numbers));
                    tolerance = 2e-3;
                    if format == "xyz", tolerance = 1e-8; end
                    testCase.verifyEqual(restored.cart_coords, ...
                        molecule.cart_coords, AbsTol = tolerance);
                    if any(format == topologyFormats)
                        restoredBonds = kssolv.modeling.chemistry. ...
                            MoleculeDiagnostics.topology(restored);
                        sourceBonds = kssolv.modeling.chemistry. ...
                            MoleculeDiagnostics.topology(molecule);
                        testCase.verifyEqual(sortrows(restoredBonds), ...
                            sortrows(sourceBonds), AbsTol = 1e-12);
                    end
                    importedName = "P1 Imported " + upper(format) + ...
                        " " + sample;
                    addProjectItem(importedName, restored);
                    expected(char(importedName)) = restored;
                end

                crystal = crystalFixture(sample);
                crystal = kssolv.modeling.CommandExecutor.execute( ...
                    crystal, "translate_atoms", struct( ...
                    "indices", 1, "vector", [.001 * sample, 0, 0], ...
                    "fractional", true)).model;
                crystalName = "P1 Crystal " + sample;
                addProjectItem(crystalName, crystal);
                expected(char(crystalName)) = crystal;
                cifPath = fullfile(directory, ...
                    sprintf("crystal-%02d.cif", sample));
                crystal.to(cifPath, "cif");
                restoredCrystal = ...
                    kssolv.analysis.matgenlab.core.Structure.from_file( ...
                    cifPath, "cif");
                testCase.verifyEqual(restoredCrystal.num_sites, ...
                    crystal.num_sites);
                testCase.verifyEqual(sort(restoredCrystal.atomic_numbers), ...
                    sort(crystal.atomic_numbers));
                testCase.verifyEqual(restoredCrystal.lattice.matrix, ...
                    crystal.lattice.matrix, AbsTol = 2e-6);
                importedCrystalName = "P1 Imported CIF " + sample;
                addProjectItem(importedCrystalName, restoredCrystal);
                expected(char(importedCrystalName)) = restoredCrystal;
            end

            projectPath = fullfile(directory, "p1-format-matrix.ks");
            project.saveToKsFile(projectPath);
            reopened = kssolv.services.filemanager.Project.loadKsFile(projectPath);
            names = string(keys(expected));
            for index = 1:numel(names)
                item = reopened.findChildrenItem(names(index));
                testCase.verifyNotEmpty(item);
                actual = item.data.MatgenlabObject;
                reference = expected(char(names(index)));
                testCase.verifyEqual( ...
                    kssolv.modeling.provenance.CanonicalHash.of(actual), ...
                    kssolv.modeling.provenance.CanonicalHash.of(reference));
            end
            clear cleanup

            function addProjectItem(name, model)
                item = kssolv.services.filemanager.Structure(name);
                item.data = ...
                    kssolv.services.fileparser.ModeledStructureData( ...
                    model, item.label);
                folder.addChildrenItem(item);
            end
        end
    end
end

function molecule = moleculeFixture(sample)
order = [1, 2, 3];
order = order(mod(sample - 1, numel(order)) + 1);
coordinates = [0, 0, 0; 1.47, 0, 0; 2.68, .08, 0; -.92, .55, 0];
coordinates(:, 3) = .01 * sample * [0; 1; -1; .5];
siteProperties = struct();
siteProperties.sample_id = repmat({sample}, 1, size(coordinates, 1));
properties = struct("audit_marker", "p1-" + sample, ...
    "topology", struct("bonds", [1, 2, order; 2, 3, 1; 1, 4, 1], ...
    "origin", "source", "schemaVersion", 1));
molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    ["C", "C", "O", "H"], coordinates, ...
    charge_spin_check = false, site_properties = siteProperties, ...
    properties = properties);
end

function crystal = crystalFixture(sample)
lengthValue = 4.8 + .03 * sample;
lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(lengthValue);
siteProperties = struct();
siteProperties.sample_id = {sample, sample};
crystal = kssolv.analysis.matgenlab.core.Structure( ...
    lattice, {"Na", "Cl"}, [0, 0, 0; .5, .5, .5], ...
    site_properties = siteProperties, ...
    properties = struct("audit_marker", "p1-" + sample));
end
