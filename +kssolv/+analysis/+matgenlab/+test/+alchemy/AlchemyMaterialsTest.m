classdef AlchemyMaterialsTest < matlab.unittest.TestCase
    % Official pymatgen TransformedStructure cases ported to MATLAB.

    methods (Test)
        function appendHistoryAlternativesAndUndoRedo(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.transformations.*
            structure = simpleOlivine();
            transformed = TransformedStructure(structure, ...
                {SubstitutionTransformation({"Li", "Na"})});
            transformed.append_transformation( ...
                SubstitutionTransformation({"Fe", "Mn"}));
            testCase.verifyEqual( ...
                transformed.final_structure.reduced_formula, "NaMnPO4");
            testCase.verifyNumElements(transformed.structures, 3);
            testCase.verifyTrue(transformed.was_modified);

            transformed.undo_last_change();
            testCase.verifyEqual( ...
                transformed.final_structure.reduced_formula, "NaFePO4");
            transformed.undo_last_change();
            testCase.verifyEqual( ...
                transformed.final_structure.reduced_formula, "LiFePO4");
            testCase.verifyError(@() transformed.undo_last_change(), ...
                "KSSOLV:Matgenlab:TransformedStructure:Undo");
            transformed.redo_next_change();
            transformed.redo_next_change();
            testCase.verifyEqual( ...
                transformed.final_structure.reduced_formula, "NaMnPO4");
            testCase.verifyError(@() transformed.redo_next_change(), ...
                "KSSOLV:Matgenlab:TransformedStructure:Redo");

            lattice = [3.8401979337, 0, 0; ...
                1.9200989668, 3.3257101909, 0; ...
                0, -2.2171384943, 3.1355090603];
            silicon = Structure(lattice, {"Si4+", "Si4+"}, ...
                [0, 0, 0; .75, .5, .75]);
            branched = TransformedStructure(silicon);
            branched.append_transformation( ...
                SupercellTransformation.from_scaling_factors(2, 1, 1));
            alternatives = branched.append_transformation( ...
                PartialRemoveSpecieTransformation( ...
                "Si4+", .5, PartialRemoveSpecieTransformation.ALGO_COMPLETE), 5);
            testCase.verifyNumElements(alternatives, 2);
            testCase.verifyEqual(numel(branched.history), 2);
            testCase.verifyEqual(numel(alternatives{1}.history), 2);
        end

        function officialSerializedFixtureAndParameters(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.transformations.*
            dictionary = jsondecode(fileread(fixture("transformations.json")));
            transformed = TransformedStructure.from_dict(dictionary);
            transformed.set_parameter("tags", {"test"});
            transformed.set_parameter("author", "Will");
            transformed.append_transformation( ...
                SubstitutionTransformation({"Fe", "Mn"}));
            testCase.verifyEqual( ...
                transformed.final_structure.reduced_formula, "MnPO4");
            testCase.verifyEqual(transformed.other_parameters.tags, {"test"});
            testCase.verifyEqual(transformed.other_parameters.author, "Will");
            serialized = transformed.as_dict();
            testCase.verifyTrue(isfield(serialized, "last_modified"));
            testCase.verifyTrue(isfield(serialized, "history"));
        end

        function constructorsAndMsonRoundTrip(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.transformations.*
            cif = fileread(fixture("LiFePO4.cif"));
            fromCif = TransformedStructure.from_cif_str(cif, {}, false);
            testCase.verifyEqual(fromCif.final_structure.reduced_formula, ...
                "LiFePO4");
            testCase.verifyEqual(fromCif.history{1}.source, "uploaded cif");
            poscar = fileread(fixture("POSCAR"));
            fromPoscar = TransformedStructure.from_poscar_str(poscar);
            testCase.verifyEqual(fromPoscar.final_structure.reduced_formula, ...
                "FePO4");
            testCase.verifyEqual(fromPoscar.history{1}.source, "POSCAR");

            transformed = TransformedStructure(simpleOlivine(), ...
                {SubstitutionTransformation({"Li", "Na"})});
            transformed.set_parameter("author", "will");
            decoded = kssolv.analysis.matgenlab.util.decode( ...
                kssolv.analysis.matgenlab.util.encode(transformed));
            testCase.verifyClass(decoded, ...
                "kssolv.analysis.matgenlab.alchemy.TransformedStructure");
            testCase.verifyEqual(decoded.final_structure, ...
                transformed.final_structure);
            testCase.verifyNumElements(decoded.structures, 2);
            decoded.undo_last_change();
            testCase.verifyEqual(decoded.final_structure.reduced_formula, ...
                "LiFePO4");
        end

        function filterAndStructureNlProvenance(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.transformations.*
            transformed = TransformedStructure(simpleOlivine(), ...
                {SubstitutionTransformation({"Li", "Na"})});
            transformed.append_filter(ContainsSpecieFilter({"O"}));
            testCase.verifyEqual(numel(transformed.history), 2);
            transformed.undo_last_change();
            transformed.redo_next_change();
            transformed.set_parameter("author", "will");
            testCase.verifyWarning(@() transformed.to_snl( ...
                {{"will", "will@test.com"}}), ...
                "KSSOLV:Matgenlab:TransformedStructure:SNLParameters");
            transformed.other_parameters = struct();
            snl = transformed.to_snl({{"will", "will@test.com"}});
            restored = TransformedStructure.from_snl(snl);
            testCase.verifyEqual(numel(restored.history), 2);
            testCase.verifyEqual(restored.history{1}.x_class, ...
                "SubstitutionTransformation");
        end

        function injectableVaspInputSetAndDefaultBoundary(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            transformed = TransformedStructure(simpleOlivine());
            factory = @(structure) ...
                kssolv.analysis.matgenlab.test.alchemy.fixtures. ...
                FakeVaspInputSet(structure);
            value = transformed.get_vasp_input(factory);
            testCase.verifyTrue(isKey(value, "POSCAR"));
            testCase.verifyTrue(isKey(value, "transformations.json"));
            testCase.verifyError(@() transformed.get_vasp_input(), ...
                "KSSOLV:Matgenlab:TransformedStructure:MissingMPRelaxSet");

            output = string(tempname);
            cleanup = onCleanup(@() removeFolder(output));
            transformed.write_vasp_input(factory, output, true);
            testCase.verifyTrue(isfile(fullfile(output, "POSCAR")));
            testCase.verifyTrue(isfile(fullfile( ...
                output, "transformations.json")));
            clear cleanup
        end
    end
end

function structure = simpleOlivine()
structure = kssolv.analysis.matgenlab.core.Structure( ...
    kssolv.analysis.matgenlab.core.Lattice.cubic(8), ...
    {"Li", "Fe", "P", "O", "O", "O", "O"}, ...
    [0, 0, 0; .5, 0, 0; 0, .5, 0; 0, 0, .5; ...
    .5, .5, 0; .5, 0, .5; 0, .5, .5]);
end

function path = fixture(name)
path = fullfile(fileparts(mfilename("fullpath")), "+fixtures", name);
end

function removeFolder(path)
if isfolder(path), rmdir(path, "s"); end
end
