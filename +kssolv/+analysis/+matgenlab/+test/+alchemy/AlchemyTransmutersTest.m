classdef AlchemyTransmutersTest < matlab.unittest.TestCase
    % Official CifTransmuter/PoscarTransmuter flows ported to MATLAB.

    methods (Test)
        function cifAndPoscarOfficialFixtures(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.transformations.*
            cif = CifTransmuter.from_filenames( ...
                {fixture("MultiStructure.cif")}, ...
                {SubstitutionTransformation( ...
                {"Fe", "Mn"; "Fe2+", "Mn2+"})});
            testCase.verifyEqual(length(cif), 2);
            for index = 1:length(cif)
                testCase.verifyEqual(cif(index).final_structure.symbol_set, ...
                    ["Li", "Mn", "O", "P"]);
            end

            poscar = PoscarTransmuter.from_filenames( ...
                {fixture("POSCAR"), fixture("POSCAR")}, ...
                {SubstitutionTransformation({"Fe", "Mn"})});
            testCase.verifyEqual(length(poscar), 2);
            for index = 1:length(poscar)
                testCase.verifyEqual(poscar(index).final_structure.symbol_set, ...
                    ["Mn", "O", "P"]);
            end
        end

        function transformFilterParametersUndoAndAppend(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.transformations.*
            first = Structure(Lattice.cubic(4), ...
                {"Li", "O"}, [0, 0, 0; .5, .5, .5]);
            second = Structure(Lattice.cubic(4), ...
                {"Na", "O"}, [0, 0, 0; .5, .5, .5]);
            transmuter = StandardTransmuter.from_structures({first, second});
            changed = transmuter.append_transformation( ...
                SubstitutionTransformation({"Li", "K"}));
            testCase.verifyEqual(changed, [false, false]);
            testCase.verifyEqual( ...
                transmuter(1).final_structure.reduced_formula, "K2O2");
            transmuter.undo_last_change();
            testCase.verifyEqual( ...
                transmuter(1).final_structure.reduced_formula, "Li2O2");
            transmuter.redo_next_change();
            transmuter.apply_filter(ContainsSpecieFilter({"K"}));
            testCase.verifyEqual(transmuter.length(), 1);
            testCase.verifyEqual( ...
                transmuter(1).history{end}.x_class, "ContainsSpecieFilter");
            transmuter.set_parameter("para1", "hello");
            transmuter.add_tags({"world", "universe"});
            testCase.verifyEqual( ...
                transmuter(1).other_parameters.para1, "hello");
            testCase.verifyEqual(transmuter(1).other_parameters.tags, ...
                {"world", "universe"});

            appended = StandardTransmuter.from_structures({second});
            transmuter.append_transformed_structures(appended);
            testCase.verifyEqual(transmuter.length(), 2);
            testCase.verifyError(@() ...
                transmuter.append_transformed_structures({second}), ...
                "KSSOLV:Matgenlab:StandardTransmuter:StructureType");
        end

        function branchingAndBatchVaspInput(testCase)
            import kssolv.analysis.matgenlab.alchemy.*
            import kssolv.analysis.matgenlab.transformations.*
            transmuter = PoscarTransmuter.from_filenames({fixture("POSCAR")});
            super = SuperTransformation({ ...
                SubstitutionTransformation({"Fe", "Mg"}), ...
                SubstitutionTransformation({"Fe", "Zn"}), ...
                SubstitutionTransformation({"Fe", "Be"})});
            transmuter.append_transformation(super, true);
            testCase.verifyEqual(length(transmuter), 3);
            testCase.verifyTrue(all(cellfun(@(item) ...
                numel(item.history) == 2, ...
                transmuter.transformed_structures)));

            factory = @(structure) ...
                kssolv.analysis.matgenlab.test.alchemy.fixtures. ...
                FakeVaspInputSet(structure);
            output = string(tempname);
            cleanup = onCleanup(@() removeFolder(output));
            transmuter.write_vasp_input(factory, output, true, [], true);
            directories = dir(output);
            directories = directories([directories.isdir]);
            directories = directories(~ismember({directories.name}, {'.', '..'}));
            testCase.verifyNumElements(directories, 3);
            for index = 1:numel(directories)
                directory = fullfile(output, directories(index).name);
                testCase.verifyTrue(isfile(fullfile(directory, "POSCAR")));
                testCase.verifyTrue(isfile(fullfile( ...
                    directory, "transformations.json")));
                testCase.verifyEqual(numel(dir(fullfile( ...
                    directory, "*.cif"))), 1);
            end
            clear cleanup
        end

        function defaultBatchBoundaryIsExplicit(testCase)
            transformed = kssolv.analysis.matgenlab.alchemy. ...
                TransformedStructure(simpleStructure());
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.alchemy. ...
                batch_write_vasp_input({transformed}), ...
                "KSSOLV:Matgenlab:BatchVaspInput:MissingMPRelaxSet");
        end
    end
end

function path = fixture(name)
path = fullfile(fileparts(mfilename("fullpath")), "+fixtures", name);
end

function structure = simpleStructure()
structure = kssolv.analysis.matgenlab.core.Structure( ...
    kssolv.analysis.matgenlab.core.Lattice.cubic(4), ...
    {"Li", "O"}, [0, 0, 0; .5, .5, .5]);
end

function removeFolder(path)
if isfolder(path), rmdir(path, "s"); end
end
