classdef MoleculeBuilderFunctionalTest < matlab.unittest.TestCase
    %MOLECULEBUILDERFUNCTIONALTEST P3/P4 production acceptance coverage.

    methods (Test)
        function buildsReferenceMoleculesFromBlank(testCase)
            water = addHydrogens(testCase.blankWithAtoms("O", [0,0,0]));
            testCase.verifyFormula(water, struct("O",1,"H",2));

            ethanol = testCase.blankWithAtoms(["C","C","O"], ...
                [0,0,0;1.52,0,0;2.95,0,0], [1,2,1;2,3,1]);
            ethanol = addHydrogens(ethanol);
            testCase.verifyFormula(ethanol, struct("C",2,"H",6,"O",1));

            formaldehyde = testCase.blankWithAtoms(["C","O"], ...
                [0,0,0;1.23,0,0], [1,2,2]);
            formaldehyde = addHydrogens(formaldehyde);
            testCase.verifyFormula(formaldehyde, struct("C",1,"H",2,"O",1));

            benzene = testCase.blank();
            benzene = execute(benzene, "sketch_ring", struct( ...
                "ringSize",6,"species","C","aromatic",true));
            benzene = addHydrogens(benzene);
            testCase.verifyFormula(benzene, struct("C",6,"H",6));
            ringBonds = benzene.properties.topology.bonds;
            ringBonds = ringBonds(all(ringBonds(:,1:2)<=6,2),:);
            testCase.verifyEqual(ringBonds(:,3),repmat(1.5,6,1));

            pyridine = testCase.blank();
            pyridine = execute(pyridine, "sketch_ring", struct( ...
                "ringSize",6,"species","C","aromatic",true));
            pyridine = execute(pyridine, "set_atom_chemistry", struct( ...
                "indices",1,"species","N","formalCharge",0, ...
                "hybridization","sp2","aromatic",true));
            pyridine = addHydrogens(pyridine);
            testCase.verifyFormula(pyridine, struct("C",5,"H",5,"N",1));

            benzamide = testCase.blank();
            benzamide = execute(benzamide, "sketch_ring", struct( ...
                "ringSize",6,"species","C","aromatic",true));
            benzamide = execute(benzamide, "sketch_atom", struct( ...
                "species","C","coordinates",[2.8,0,0], ...
                "connectTo",1,"bondOrder",1,"hybridization","sp2"));
            benzamide = execute(benzamide, "sketch_atom", struct( ...
                "species","O","coordinates",[4.03,0,0], ...
                "connectTo",7,"bondOrder",2,"hybridization","sp2"));
            benzamide = execute(benzamide, "sketch_atom", struct( ...
                "species","N","coordinates",[2.8,1.33,0], ...
                "connectTo",7,"bondOrder",1,"hybridization","sp2"));
            benzamide = addHydrogens(benzamide);
            testCase.verifyFormula(benzamide, ...
                struct("C",7,"H",7,"N",1,"O",1));
        end

        function bondEditingAndDiagnosticsAreExplicit(testCase)
            molecule = testCase.blankWithAtoms(["C","O"], ...
                [0,0,0;1.4,0,0]);
            molecule = execute(molecule,"add_bond", ...
                struct("indices",[1,2],"bondOrder",1));
            molecule = execute(molecule,"set_bond_order", ...
                struct("indices",[1,2],"bondOrder",2));
            testCase.verifyEqual(molecule.properties.topology.bonds,[1,2,2]);
            report = kssolv.modeling.CommandExecutor.execute( ...
                molecule,"diagnose_molecule",struct());
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.analysis.method, ...
                "rule-based-valence-and-geometry");
            testCase.verifyFalse(report.analysis.isEnergyMinimization);
            molecule = execute(molecule,"delete_bond",struct("indices",[1,2]));
            testCase.verifyEmpty(molecule.properties.topology.bonds);
        end

        function sketchAtomUsesForceFieldIdealBondLength(testCase)
            molecule = testCase.blankWithAtoms("C", [2, -1, 0.5]);
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("C", "O", 1);
            result = execute(molecule, "sketch_atom", struct( ...
                "species", "O", "connectTo", 1, "bondOrder", 1, ...
                "useIdealBondLength", true));

            testCase.verifyEqual(result.num_sites, 2);
            testCase.verifyEqual( ...
                result.properties.topology.bonds, [1, 2, 1]);
            testCase.verifyEqual(norm( ...
                result.cart_coords(2, :) - result.cart_coords(1, :)), ...
                double(parameter.value), "AbsTol", 1e-12);
            testCase.verifyError(@()execute(molecule, "sketch_atom", ...
                struct("species", "O", "connectTo", 0, ...
                "useIdealBondLength", true)), ...
                "KSSOLV:Modeling:IdealSketchConnection");
        end

        function sketchAtomRejectsInvalidElementBeforeSpeciesParsing(testCase)
            molecule = testCase.blankWithAtoms("C", [0, 0, 0]);
            testCase.verifyError(@()execute(molecule, "sketch_atom", ...
                struct("species", "Oo", "connectTo", 1, ...
                "bondOrder", 1, "useIdealBondLength", true)), ...
                "KSSOLV:Modeling:SketchElement");
        end

        function hydrogenRuleAccuracyAcrossFiftyMolecules(testCase)
            correct = 0; total = 50;
            for sample = 1:total
                carbonCount = mod(sample - 1,10) + 1;
                species = repmat("C",1,carbonCount);
                coordinates = [(0:carbonCount-1).'*1.52, ...
                    zeros(carbonCount,2)];
                bonds = [(1:carbonCount-1).',(2:carbonCount).', ...
                    ones(max(carbonCount-1,0),1)];
                molecule = testCase.blankWithAtoms(species,coordinates,bonds);
                molecule = addHydrogens(molecule);
                counts = elementCounts(molecule);
                correct = correct + double(counts.C == carbonCount && ...
                    counts.H == 2*carbonCount+2);
            end
            testCase.verifyGreaterThanOrEqual(correct/total,0.98);
        end

        function molAndSdfRoundTripPreservesBondOrder(testCase)
            molecule = testCase.blankWithAtoms(["C","O","N"], ...
                [0,0,0;1.22,0,0;-1.32,0,0], [1,2,2;1,3,1]);
            for format = ["mol","sdf"]
                text = molecule.to("",format);
                restored = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_str(text,format);
                testCase.verifyEqual(restored.properties.topology.bonds, ...
                    molecule.properties.topology.bonds);
            end
        end

        function exactGeometryEditsMeetTolerance(testCase)
            molecule = testCase.blankWithAtoms(["C","C","C","C"], ...
                [0,0,0;1.5,0,0;2.0,1.4,0;3.0,1.7,1.0], ...
                [1,2,1;2,3,1;3,4,1]);
            molecule = execute(molecule,"set_distance",struct( ...
                "indices",[1,2],"value",1.234567,"scope","subtree"));
            measured = measurement(molecule,[1,2]);
            testCase.verifyEqual(measured,1.234567,"AbsTol",1e-6);
            molecule = execute(molecule,"set_angle",struct( ...
                "indices",[1,2,3],"value",117.25,"scope","subtree"));
            measured = measurement(molecule,[1,2,3]);
            testCase.verifyEqual(measured,117.25,"AbsTol",1e-5);
            molecule = execute(molecule,"set_dihedral",struct( ...
                "indices",[1,2,3,4],"value",-62.75,"scope","subtree"));
            measured = measurement(molecule,[1,2,3,4]);
            testCase.verifyEqual(measured,-62.75,"AbsTol",1e-5);
        end

        function alignmentAndCleanMeetContracts(testCase)
            molecule = testCase.blankWithAtoms(["C","C","O"], ...
                [0,0,0;0.2,1.7,0.3;0.5,3.4,0.5], [1,2,1;2,3,1]);
            aligned = execute(molecule,"align_geometry",struct( ...
                "indices",[1,2,3],"mode","principal_axis", ...
                "target",[1,0,0]));
            centered = aligned.cart_coords-mean(aligned.cart_coords,1);
            [~,~,v] = svd(centered,0);
            errorDegrees = acosd(min(1,abs(dot(v(:,1),[1;0;0]))));
            testCase.verifyLessThan(errorDegrees,0.01);
            originalFormula = molecule.formula;
            originalBonds = molecule.properties.topology.bonds;
            result = kssolv.modeling.CommandExecutor.execute( ...
                molecule,"clean_geometry",struct("iterations",5));
            testCase.verifyEqual(result.model.formula,originalFormula);
            testCase.verifyEqual(result.model.properties.topology.bonds, ...
                originalBonds);
            testCase.verifyFalse(result.analysis.isEnergyMinimization);
            testCase.verifyEqual(result.analysis.geometryParameterSet, ...
                "kssolv-generic-mm-parameters-v2");
            testCase.verifyTrue(contains(result.message, ...
                "not an energy minimization"));
        end

        function fragmentLibraryIsVersionedPersistentAndRobust(testCase)
            store = string(tempname) + " fragment's store.json";
            cleanup = onCleanup(@()deleteIfPresent(store));
            fragment = testCase.blankWithAtoms(["C","H"], ...
                [0,0,0;1.09,0,0],[1,2,1]);
            customPort = struct("id", "carbon", ...
                "label", "Carbon connection", "headIndices", 1, ...
                "leavingAtomIndices", 2, "defaultBondOrders", 1, ...
                "orientation", [-1,0,0], "mode", "covalent", ...
                "bondOverrides", zeros(0,3));
            kssolv.modeling.fragments.FragmentLibrary.saveUser( ...
                "Persistent Test", fragment, ports = customPort, ...
                storePath = store);
            loaded = kssolv.modeling.fragments.FragmentLibrary. ...
                loadStore(store);
            testCase.verifyEqual(loaded.schemaVersion,2);
            testCase.verifyEqual(string(loaded.fragments(1).name), ...
                "Persistent Test");
            testCase.verifyEqual(loaded.fragments(1).bonds,[1,2,1]);
            testCase.verifyEqual(string(loaded.fragments(1).ports.id), ...
                "carbon");
            testCase.verifyEqual( ...
                loaded.fragments(1).ports.leavingAtomIndices, 2);
            testCase.verifyEmpty(dir(store+".*.tmp"));

            names = string({kssolv.modeling.fragments. ...
                FragmentLibrary.list().name});
            for sample = 1:100
                host = testCase.blankWithAtoms("C",[0,0,0]);
                name = names(mod(sample-1,numel(names))+1);
                [assembled,metadata] = kssolv.modeling.fragments. ...
                    FragmentLibrary.attach(host,name,1);
                bonds = assembled.properties.topology.bonds;
                testCase.verifyTrue(all(bonds(:,1:2)>=1,"all"));
                testCase.verifyTrue(all(bonds(:,1:2)<=assembled.num_sites,"all"));
                testCase.verifyEqual(size(unique(sort(bonds(:,1:2),2), ...
                    "rows"),1),size(bonds,1));
                testCase.verifyEqual(numel(metadata.fragmentIndices), ...
                    assembled.num_sites-1);
            end
        end

        function carboxylPortsSupportCovalentAndBidentateModes(testCase)
            ports = kssolv.modeling.fragments.FragmentLibrary. ...
                ports("Carboxyl");
            testCase.verifyEqual(string({ports.id}), ...
                ["carbon","oxygen-single","oxygen-bidentate", ...
                "noncovalent"]);

            host = testCase.blankWithAtoms("C", [0,0,0]);
            [single, singleMetadata] = kssolv.modeling.fragments. ...
                FragmentLibrary.attach(host, "Carboxyl", 1, ...
                portId = "oxygen-single");
            testCase.verifyEqual(single.num_sites, 4);
            testCase.verifyEqual(singleMetadata.portMode, "monodentate");
            testCase.verifyEqual(singleMetadata.leavingAtomIndices, 4);
            testCase.verifyFalse(any(arrayfun(@(index) ...
                string(single(index).specie.symbol) == "H", ...
                1:single.num_sites)));

            separation = norm([1.23,0,0] - [-.65,1.12,0]);
            host = testCase.blankWithAtoms(["Cu","Cu"], ...
                [0,0,0;0,separation,0]);
            [bidentate, metadata] = kssolv.modeling.fragments. ...
                FragmentLibrary.attach(host, "Carboxyl", [1,2], ...
                portId = "oxygen-bidentate");
            testCase.verifyEqual(bidentate.num_sites, 5);
            testCase.verifyEqual(metadata.portMode, "bidentate");
            testCase.verifyEqual(numel(metadata.connectionHead), 2);
            bonds = bidentate.properties.topology.bonds;
            fragmentBonds = bonds(all(bonds(:,1:2) > 2, 2), :);
            testCase.verifyEqual(sort(fragmentBonds(:,3)), [1.5;1.5]);
            connectionBonds = bonds(any(bonds(:,1:2) <= 2, 2), :);
            testCase.verifyEqual(size(connectionBonds, 1), 2);
        end

        function fragmentAttachmentRejectsSaturatedHostsBeforeCommit(testCase)
            saturated = testCase.blankWithAtoms(["H","O","O","H"], ...
                [-1.55,.55,0;-.72,0,0;.72,0,0;1.55,-.15,.78], ...
                [1,2,1;2,3,1;3,4,1]);
            originalCoordinates = saturated.cart_coords;
            originalBonds = saturated.properties.topology.bonds;

            testCase.verifyError(@() ...
                kssolv.modeling.fragments.FragmentLibrary.attach( ...
                saturated,"Carboxyl",3,portId="carbon"), ...
                "KSSOLV:Modeling:FragmentHostValence");
            testCase.verifyEqual(saturated.num_sites,4);
            testCase.verifyEqual(saturated.cart_coords,originalCoordinates);
            testCase.verifyEqual( ...
                saturated.properties.topology.bonds,originalBonds);
        end

        function sketchRejectsShortBondsAndOverlappingAtoms(testCase)
            oxygen = testCase.blankWithAtoms("O",[0,0,0]);
            originalCoordinates = oxygen.cart_coords;
            originalBonds = oxygen.properties.topology.bonds;

            testCase.verifyError(@()execute(oxygen,"sketch_atom",struct( ...
                "species","O","coordinates",[.81,0,0], ...
                "connectTo",1,"bondOrder",1)), ...
                "KSSOLV:Modeling:SketchBondTooShort");
            testCase.verifyError(@()execute(oxygen,"sketch_atom",struct( ...
                "species","C","coordinates",[.1,0,0])), ...
                "KSSOLV:Modeling:SketchCollision");
            testCase.verifyEqual(oxygen.num_sites,1);
            testCase.verifyEqual(oxygen.cart_coords,originalCoordinates);
            testCase.verifyEqual(oxygen.properties.topology.bonds,originalBonds);

            valid = execute(oxygen,"sketch_atom",struct( ...
                "species","O","coordinates",[1.48,0,0], ...
                "connectTo",1,"bondOrder",1));
            testCase.verifyEqual(valid.num_sites,2);
            testCase.verifyEqual(valid.properties.topology.bonds,[1,2,1]);
        end

        function fragmentCommandsUseTheSameVersionedLibrary(testCase)
            store=string(tempname)+".json";
            cleanup=onCleanup(@()deleteIfPresent(store));
            fragment=testCase.blankWithAtoms(["O","H"], ...
                [0,0,0;.96,0,0],[1,2,1]);
            saved=kssolv.modeling.CommandExecutor.execute(fragment, ...
                "save_user_fragment",struct("fragmentName","COMMAND_POLAR", ...
                "storePath",store));
            testCase.verifyFalse(saved.changed);
            host=testCase.blankWithAtoms("C",[0,0,0]);
            attached=kssolv.modeling.CommandExecutor.execute(host, ...
                "attach_fragment",struct("indices",1, ...
                "fragmentName","COMMAND_POLAR","storePath",store));
            testCase.verifyTrue(attached.changed);
            testCase.verifyEqual(attached.model.num_sites,3);
            testCase.verifyEqual(attached.analysis.name,"COMMAND_POLAR");
            testCase.verifyError(@() ...
                kssolv.modeling.fragments.FragmentCommands.execute( ...
                host,"unsupported",struct()), ...
                "KSSOLV:Modeling:FragmentCommand");
        end

        function commandsAreIndependentlyTransactional(testCase)
            molecule = testCase.blankWithAtoms(["C","C"], ...
                [0,0,0;1.5,0,0],[1,2,1]);
            commands = {
                "set_bond_order",struct("indices",[1,2],"bondOrder",2)
                "set_distance",struct("indices",[1,2],"value",1.3,"scope","atom")
                "add_hydrogens",struct("indices",[1,2])
                "sketch_ring",struct("ringSize",3,"center",[4,0,0],"aromatic",false)
                };
            for row = 1:size(commands,1)
                transaction = kssolv.modeling.contracts.EditTransaction( ...
                    molecule,7,commands{row,1},commands{row,2});
                preview = transaction.preview();
                testCase.verifyEqual(molecule.num_sites,2);
                committed = transaction.commit(7);
                testCase.verifyTrue(committed.changed);
                testCase.verifyEqual(committed.model,preview.model);
            end
        end
    end

    methods (Access=private)
        function molecule = blank(~)
            properties = struct("topology",struct("bonds",zeros(0,3), ...
                "origin","source","schemaVersion",1));
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                cell(1,0),zeros(0,3),charge_spin_check=false, ...
                properties=properties);
        end
        function molecule = blankWithAtoms(testCase,species,coordinates,bonds)
            if nargin<4, bonds=zeros(0,3); end
            molecule = testCase.blank();
            species = reshape(string(species),1,[]);
            for index=1:numel(species)
                molecule = execute(molecule,"sketch_atom",struct( ...
                    "species",species(index), ...
                    "coordinates",coordinates(index,:)));
            end
            for row=1:size(bonds,1)
                molecule = execute(molecule,"add_bond",struct( ...
                    "indices",bonds(row,1:2),"bondOrder",bonds(row,3)));
            end
        end
        function verifyFormula(testCase,molecule,expected)
            actual = elementCounts(molecule);
            names = fieldnames(expected);
            for index=1:numel(names)
                testCase.verifyEqual(actual.(names{index}),expected.(names{index}));
            end
            values = struct2cell(actual);
            testCase.verifyEqual(sum(cell2mat(values)),molecule.num_sites);
        end
    end
end

function model = execute(model,command,parameters)
result = kssolv.modeling.CommandExecutor.execute(model,command,parameters);
model = result.model;
end
function model = addHydrogens(model)
model = execute(model,"add_hydrogens",struct("indices",1:model.num_sites));
end
function value = measurement(model,indices)
result = kssolv.modeling.CommandExecutor.execute( ...
    model,"measure_geometry",struct("indices",indices));
value = result.analysis.value;
end
function counts = elementCounts(molecule)
counts = struct();
for index=1:molecule.num_sites
    name = char(molecule(index).specie.symbol);
    if ~isfield(counts,name), counts.(name)=0; end
    counts.(name)=counts.(name)+1;
end
end
function deleteIfPresent(path)
if isfile(path), delete(path); end
end
