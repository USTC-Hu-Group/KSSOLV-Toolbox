classdef ModelingTabTest < matlab.unittest.TestCase
    %MODELINGTABTEST Contextual toolstrip lifecycle contract.

    methods (Test)
        function registryResolvesSelectedStructureAmongMultipleSessions( ...
                testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Modeling Selection Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupSelectionApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);

            first = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            second = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 5, {"C"}, [0, 0, 0]);
            firstDisplay = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay(first);
            secondDisplay = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay(second);
            firstDocument = matlab.ui.internal.FigureDocument(struct( ...
                "Title", "First structure", ...
                "DocumentGroupTag", "Structure", ...
                "Tag", "first-structure"));
            secondDocument = matlab.ui.internal.FigureDocument(struct( ...
                "Title", "Second structure", ...
                "DocumentGroupTag", "Structure", ...
                "Tag", "second-structure"));
            app.add(firstDocument);
            app.add(secondDocument);
            app.Visible = true;
            drawnow
            registry = ...
                kssolv.ui.features.modeling.SessionRegistry.getInstance();
            registry.register(firstDocument, firstDisplay);
            registry.register(secondDocument, secondDisplay);

            firstDocument.Selected = true;
            drawnow
            testCase.verifyEqual( ...
                registry.getCurrentDisplay(), firstDisplay);

            secondDocument.Selected = true;
            drawnow
            testCase.verifyEqual( ...
                registry.getCurrentDisplay(), secondDisplay);

            workflowGroup = matlab.ui.internal.FigureDocumentGroup();
            workflowGroup.Tag = "Workflow";
            app.add(workflowGroup);
            workflowDocument = matlab.ui.internal.FigureDocument(struct( ...
                "Title", "Workflow", ...
                "DocumentGroupTag", "Workflow", ...
                "Tag", "workflow"));
            app.add(workflowDocument);
            workflowDocument.Selected = true;
            drawnow
            testCase.verifyEqual( ...
                registry.getCurrentDisplay(), secondDisplay);
            clear cleanup

            function cleanupSelectionApp(value)
                registryValue = ...
                    kssolv.ui.util.DataStorage.getData( ...
                    "ModelingSessionRegistry");
                if ~isempty(registryValue) && isvalid(registryValue)
                    delete(registryValue);
                end
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function analysisResultsCreateVisualFigures(testCase)
            previous = get(groot, "defaultFigureVisible");
            set(groot, "defaultFigureVisible", "off");
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Modeling Plot Test", ...
                "ToolstripEnabled", true));
            app.Visible = true;
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            cleanup = onCleanup(@()restoreFigures(previous, app));
            slab = ...
                kssolv.modeling.test. ...
                ModelingFunctionalTestUtils.surfaceSlab();
            adsorption = ...
                kssolv.modeling.CommandExecutor.execute( ...
                slab, "find_adsorption_sites", ...
                struct("distance", 2));
            testCase.verifyWarningFree(@() ...
                kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                "find_adsorption_sites", slab, adsorption, ...
                "Adsorption sites"));

            crystal = ...
                kssolv.modeling.test. ...
                ModelingFunctionalTestUtils.simpleCubic();
            wigner = ...
                kssolv.modeling.CommandExecutor.execute( ...
                crystal, "wigner_seitz_cell", struct());
            testCase.verifyWarningFree(@() ...
                kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                "wigner_seitz_cell", crystal, wigner, ...
                "Wigner-Seitz cell", app));
            testCase.verifyGreaterThanOrEqual( ...
                numel(findall(groot, "Type", "figure")), 1);
            document = app.getDocument( ...
                "Plot", "ModelingWignerSeitzCell");
            testCase.verifyNotEmpty(document);
            testCase.verifyEqual( ...
                string(document.Title), "Wigner-Seitz cell");
            testCase.verifyWarningFree(@() ...
                kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                "wigner_seitz_cell", crystal, wigner, ...
                "Wigner-Seitz cell", app));
            refreshedDocument = app.getDocument( ...
                "Plot", "ModelingWignerSeitzCell");
            testCase.verifyNotEmpty(refreshedDocument);
            testCase.verifyNotEmpty(findobj( ...
                refreshedDocument.Figure, "Type", "Axes"));
            clear cleanup

            function restoreFigures(value, appContainer)
                close(findall(groot, "Type", "figure"));
                if ~isempty(appContainer) && isvalid(appContainer)
                    delete(appContainer);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
                set(groot, "defaultFigureVisible", value);
            end
        end

        function displayHistoryUsesDefensiveModelCopies(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "History Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupHistoryApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            original = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                original);
            changed = original.translate_sites( ...
                1, [0.1, 0, 0], frac_coords = true);

            display.applyModel(changed, "Translate");
            testCase.verifyTrue(display.canUndo());
            testCase.verifyEqual(display.getModel().frac_coords, ...
                changed.frac_coords, AbsTol = 1e-12);
            display.undo();
            testCase.verifyTrue(display.canRedo());
            testCase.verifyEqual(display.getModel().frac_coords, ...
                original.frac_coords, AbsTol = 1e-12);
            display.redo();
            testCase.verifyEqual(display.getModel().frac_coords, ...
                changed.frac_coords, AbsTol = 1e-12);
            clear cleanup

            function cleanupHistoryApp(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function displayAcceptsEmptyCrystalAndCanUndoDeletion(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Empty Crystal History Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupHistoryApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            original = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                original);
            emptied = kssolv.modeling.CommandExecutor.execute( ...
                original, "delete_atoms", struct("indices", 1));

            display.applyModel(emptied.model, "Delete Atoms");
            testCase.verifyEqual(display.getModel().num_sites, 0);
            testCase.verifyTrue(display.canUndo());
            display.undo();
            restored = display.getModel();
            testCase.verifyEqual(restored.num_sites, 1);
            testCase.verifyEqual(restored(1).species_string, "Si");
            clear cleanup

            function cleanupHistoryApp(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function displayAcceptsEmptyMoleculeAndCanUndoDeletion(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Empty Molecule History Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupHistoryApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            original = kssolv.analysis.matgenlab.core.Molecule( ...
                "He", [0, 0, 0]);
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                original);
            emptied = kssolv.modeling.CommandExecutor.execute( ...
                original, "delete_atoms", struct("indices", 1));

            display.applyModel(emptied.model, "Delete Atom");
            testCase.verifyEqual(display.getModel().num_sites, 0);
            testCase.verifyTrue(display.canUndo());
            display.undo();
            restored = display.getModel();
            testCase.verifyEqual(restored.num_sites, 1);
            testCase.verifyEqual(restored(1).species_string, "He");
            clear cleanup

            function cleanupHistoryApp(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function moleculeHistoryAndParameterSchemaUseCartesianEditing(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Molecule History Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupMoleculeApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                molecule);
            moved = kssolv.modeling.CommandExecutor.execute( ...
                molecule, "move_atoms", struct( ...
                "indices", 2, "coordinates", [1, 2, 3]));
            display.applyModel(moved.model, "Move Atom");
            testCase.verifyTrue(display.canUndo());
            testCase.verifyEqual( ...
                display.getModel().cart_coords(2, :), [1, 2, 3]);
            display.undo();
            testCase.verifyEqual(display.getModel().cart_coords, ...
                molecule.cart_coords, AbsTol = 1e-12);

            moveFields = ...
                kssolv.ui.features.modeling.ParameterSchema.forCommand( ...
                "move_atoms", display);
            translateFields = ...
                kssolv.ui.features.modeling.ParameterSchema.forCommand( ...
                "translate_atoms", display);
            testCase.verifyFalse(any(string({moveFields.name}) == "cartesian"));
            testCase.verifyFalse(any( ...
                string({translateFields.name}) == "fractional"));
            delete(display);
            clear cleanup

            function cleanupMoleculeApp(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function displayPersistsAndRecallsNamedSelectionSets(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Selection Set Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupSelectionSets(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            molecule = ...
                kssolv.modeling.selection.SelectionSetStore.save( ...
                molecule, "Hydrogens", [2, 3]);
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                molecule);
            [indices, missing] = display.recallSelectionSet("Hydrogens");
            testCase.verifyEqual(indices, [2, 3]);
            testCase.verifyEmpty(missing);
            testCase.verifyEqual(display.getSelectedSiteIndices(), [2, 3]);
            display.saveSelectionSet("Hydrogens Copy");
            sets = display.getSelectionSets();
            testCase.verifyEqual(sort(string({sets.name})), ...
                ["Hydrogens", "Hydrogens Copy"]);
            display.removeSelectionSet("Hydrogens Copy");
            testCase.verifyEqual( ...
                string({display.getSelectionSets().name}), "Hydrogens");
            delete(display);
            clear cleanup

            function cleanupSelectionSets(value)
                if ~isempty(value) && isvalid(value), delete(value); end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function structureDraftSavesResetsAndDiscardsTransactionally( ...
                testCase)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Structure Draft Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupDraftApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);

            project = kssolv.services.filemanager.Project();
            folder = project.findChildrenItem("Structure");
            item = kssolv.services.filemanager.Structure("Editable");
            original = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            item.data = ...
                kssolv.services.fileparser.ModeledStructureData( ...
                original, item.label);
            folder.addChildrenItem(item);
            project.isDirty = false;
            kssolv.ui.util.DataStorage.setData("Project", project);

            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                original, "", item.name);
            changed = original.translate_sites( ...
                1, [0.2, 0, 0], frac_coords = true);
            display.applyModel(changed, "Translate");

            testCase.verifyTrue(display.hasUnsavedChanges());
            testCase.verifyFalse(project.isDirty);
            testCase.verifyEqual( ...
                item.data.MatgenlabObject.frac_coords, ...
                original.frac_coords, AbsTol = 1e-12);

            display.reset();
            testCase.verifyFalse(display.hasUnsavedChanges());
            testCase.verifyFalse(display.canUndo());
            testCase.verifyEqual(display.getModel().frac_coords, ...
                original.frac_coords, AbsTol = 1e-12);

            display.applyModel(changed, "Translate");
            display.saveChangesToProject();
            testCase.verifyFalse(display.hasUnsavedChanges());
            testCase.verifyTrue(project.isDirty);
            testCase.verifyEqual( ...
                item.data.MatgenlabObject.frac_coords, ...
                changed.frac_coords, AbsTol = 1e-12);

            changedAgain = changed.translate_sites( ...
                1, [0.1, 0, 0], frac_coords = true);
            display.applyModel(changedAgain, "Translate again");
            display.discardChanges(false);
            testCase.verifyFalse(display.hasUnsavedChanges());
            testCase.verifyEqual(display.getModel().frac_coords, ...
                changed.frac_coords, AbsTol = 1e-12);
            testCase.verifyEqual( ...
                item.data.MatgenlabObject.frac_coords, ...
                changed.frac_coords, AbsTol = 1e-12);
            clear cleanup

            function cleanupDraftApp(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("Project");
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function moleculeDraftPersistsTopologyAndReopens(testCase)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Molecule Persistence Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupMoleculeDraft(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);

            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            molecule.properties.topology = struct( ...
                "bonds", [1, 2, 1; 1, 3, 1], "origin", "source");
            project = kssolv.services.filemanager.Project();
            folder = project.findChildrenItem("Structure");
            item = kssolv.services.filemanager.Structure("Water");
            item.data = ...
                kssolv.services.fileparser.ModeledStructureData( ...
                molecule, item.label);
            folder.addChildrenItem(item);
            project.isDirty = false;
            kssolv.ui.util.DataStorage.setData("Project", project);

            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                molecule, "", item.name);
            edited = kssolv.modeling.CommandExecutor.execute( ...
                molecule, "substitute_atoms", struct( ...
                "indices", 2, "species", "F"));
            display.applyModel(edited.model, "Replace Element");
            display.saveChangesToProject();

            testCase.verifyTrue(project.isDirty);
            saved = item.data.MatgenlabObject;
            testCase.verifyClass(saved, ...
                "kssolv.analysis.matgenlab.core.Molecule");
            testCase.verifyEqual(saved(2).species_string, "F");
            testCase.verifyEqual(saved.properties.topology.bonds, ...
                [1, 2, 1; 1, 3, 1]);
            reopened = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                saved, "", item.name);
            testCase.verifyEqual( ...
                reopened.getModel().properties.topology.bonds, ...
                saved.properties.topology.bonds);
            delete(reopened);
            delete(display);
            clear cleanup

            function cleanupMoleculeDraft(value)
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("Project");
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end

        function tabFollowsOpenStructureDocuments(testCase)
            app = matlab.ui.container.internal.AppContainer( ...
                struct("Title", "Modeling Test", ...
                "ToolstripEnabled", true));
            cleanup = onCleanup(@()cleanupApp(app));
            kssolv.ui.util.DataStorage.setData("AppContainer", app);

            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "kssolvTabGroup";
            home = matlab.ui.internal.toolstrip.Tab("Home");
            home.Tag = "HomeTab";
            workflow = matlab.ui.internal.toolstrip.Tab("Workflow");
            workflow.Tag = "WorkflowTab";
            tabGroup.add(home);
            tabGroup.add(workflow);
            app.add(tabGroup);
            app.Visible = true;
            drawnow

            structure = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            crystalCommands = expectedProfileCommands(structure);
            moleculeCommands = expectedProfileCommands(molecule);

            modeling = kssolv.ui.components.tab.ModelingTab(tabGroup);
            registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
            testCase.verifyEmpty(tabGroup.contains("ModelingTab"));
            testCase.verifyEqual(modeling.Profile, "crystal");
            testCase.verifyEqual(string(modeling.Tab.Title), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:CrystalModelingTab")));
            testCase.verifyEqual( ...
                sort(string(modeling.Items.keys)), sort(crystalCommands));
            sections = modeling.Tab.Children;
            testCase.verifyEqual(numel(sections), 6);
            testCase.verifyEqual(string({sections.Tag}), [
                "ModelingHistorySection"
                "ModelingEditorsSection"
                "ModelingCrystalCellSection"
                "ModelingCrystalMaterialsSection"
                "ModelingSurfacesSection"
                "ModelingMolecularComponentsSection"
                ].');
            historyControls = sections(1).Children(1).Children;
            testCase.verifyEqual(string({historyControls.Tag}), [
                "ModelingUndo"
                "ModelingRedo"
                "ModelingReset"
                ].');
            testCase.verifyEqual(string(historyControls(3).Text), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Reset")));
            guideButton=sections(1).Children(3).Children(2);
            testCase.verifyEqual(string(guideButton.Tag),"ModelingGuide");
            testCase.verifyNotEmpty(guideButton.Description);
            for guideFile = [ ...
                    "modeling-user-guide.md", ...
                    "modeling-user-guide.zh-CN.md"]
                testCase.verifyTrue(isfile(fullfile( ...
                    KSSOLV_Toolbox.RootDirectory,"docs",guideFile)));
            end
            for sectionIndex = 1:numel(sections)
                columns = sections(sectionIndex).Children;
                for columnIndex = 1:numel(columns)
                    testCase.verifyLessThanOrEqual( ...
                    numel(columns(columnIndex).Children), 3);
                end
            end
            testCase.verifyEqual( ...
                arrayfun(@(section)numel(section.Children), sections), ...
                [3, 2, 3, 2, 2, 3]);
            selectionSetButton = sections(2).Children(2).Children(1);
            testCase.verifyEqual(string(selectionSetButton.Tag), ...
                "ModelingSelectionSets");
            testCase.verifyClass(selectionSetButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            latticeButton = sections(3).Children(1).Children(1);
            supercellButton = sections(3).Children(2).Children(1);
            symmetryButton = sections(3).Children(3).Children(1);
            defectButton = sections(4).Children(1).Children(1);
            nanoButton = sections(4).Children(2).Children(1);
            surfaceButton = sections(5).Children(1).Children(1);
            interfaceButton = sections(5).Children(2).Children(1);
            componentTransformButton = sections(6).Children(1).Children(1);
            componentGeometryButton = sections(6).Children(2).Children(1);
            hostPackingButton = sections(6).Children(3).Children(1);
            testCase.verifyClass(latticeButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyClass(supercellButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyClass(nanoButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyClass(surfaceButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyClass(interfaceButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyClass(symmetryButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyEqual( ...
                countPopupHeaders(supercellButton.Popup), 2);
            testCase.verifyEqual(countPopupHeaders(nanoButton.Popup), 2);
            testCase.verifyEqual(countPopupHeaders(surfaceButton.Popup), 2);
            testCase.verifyEqual( ...
                countPopupHeaders(interfaceButton.Popup), 2);
            testCase.verifyEqual( ...
                countPopupHeaders(symmetryButton.Popup), 2);
            testCase.verifyEqual( ...
                countPopupHeaders(componentTransformButton.Popup), 1);
            testCase.verifyEqual( ...
                countPopupHeaders(componentGeometryButton.Popup), 1);
            testCase.verifyEqual( ...
                countPopupHeaders(hostPackingButton.Popup), 1);
            testCase.verifyClass(defectButton, ...
                "matlab.ui.internal.toolstrip.DropDownButton");
            testCase.verifyEqual(string(defectButton.Tag), ...
                "ModelingCategory_defects_alloys");
            testCase.verifyEqual(countPopupHeaders(defectButton.Popup), 2);
            defectChildren = defectButton.Popup.Children;
            defectTags = strings(0, 1);
            defectGroups = zeros(0, 1);
            createDefectItem = [];
            currentDefectGroup = 0;
            for defectChildIndex = 1:numel(defectChildren)
                child = defectChildren(defectChildIndex);
                if isa(child, ...
                        "matlab.ui.internal.toolstrip.PopupListHeader")
                    currentDefectGroup = currentDefectGroup + 1;
                elseif isprop(child, "Tag") && ...
                        startsWith(string(child.Tag), "ModelingCommand_")
                    defectTags(end+1, 1) = string(child.Tag); %#ok<AGROW>
                    defectGroups(end+1, 1) = ...
                        currentDefectGroup; %#ok<AGROW>
                    if string(child.Tag) == ...
                            "ModelingCommand_create_point_defects"
                        createDefectItem = child;
                    end
                end
            end
            testCase.verifyEqual(defectTags, [
                "ModelingCommand_create_point_defects"
                "ModelingCommand_enumerate_point_defects"
                "ModelingCommand_generate_sqs_model"
                ]);
            testCase.verifyEqual(defectGroups, [1; 1; 2], ...
                "SQS must be placed in the alloy popup group.");
            testCase.verifyClass(createDefectItem, ...
                "matlab.ui.internal.toolstrip.ListItemWithPopup");
            presetItems = num2cell( ...
                createDefectItem.Popup.Children(:));
            testCase.verifyEqual(cellfun( ...
                @(item)string(item.Tag), presetItems), [
                "ModelingPreset_create_point_defects_Vacancy"
                "ModelingPreset_create_point_defects_Substitution"
                "ModelingPreset_create_point_defects_Interstitial"
                "ModelingPreset_create_point_defects_Antisite"
                ]);
            defectDescriptionKeys = [
                "VacancyDescription"
                "SubstitutionDescription"
                "InterstitialDescription"
                "AntisiteDescription"
                ];
            for presetIndex = 1:numel(presetItems)
                presetItem = presetItems{presetIndex};
                testCase.verifyFalse(presetItem.Enabled);
                testCase.verifyEmpty(presetItem.Icon);
                testCase.verifyTrue(endsWith( ...
                    string(presetItem.Text), "..."));
                testCase.verifyEqual( ...
                    string(presetItem.Description), ...
                    string(kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:" + ...
                        defectDescriptionKeys(presetIndex))));
            end

            symmetryChildren = symmetryButton.Popup.Children;
            symmetryTags = strings(0,1);
            for symmetryChildIndex = 1:numel(symmetryChildren)
                child = symmetryChildren(symmetryChildIndex);
                if isprop(child,"Tag") && ...
                        startsWith(string(child.Tag),"ModelingCommand_")
                    symmetryTags(end+1,1) = string(child.Tag); %#ok<AGROW>
                end
            end
            testCase.verifyEqual(symmetryTags, [
                "ModelingCommand_build_from_spacegroup"
                "ModelingCommand_make_p1"
                "ModelingCommand_find_symmetry"
                "ModelingCommand_primitive_cell"
                "ModelingCommand_conventional_cell"
                "ModelingCommand_wigner_seitz_cell"
                ]);
            for commandIndex = 1:numel(crystalCommands)
                commandId = crystalCommands(commandIndex);
                control = modeling.Items(char(commandId));
                testCase.verifyFalse(control.Enabled);
                testCase.verifyClass(control.Icon, ...
                    "matlab.ui.internal.toolstrip.Icon");
                if isa(control, ...
                        "matlab.ui.internal.toolstrip.ListItem")
                    expectedIcon = kssolv.ui.features.modeling. ...
                        CommandPresentationCatalog.icon(commandId, 24);
                    testCase.verifyEqual( ...
                        string(control.Icon.getIconClass()), ...
                        string(expectedIcon.getIconClass()));
                end
                testCase.verifyNotEmpty(control.Description);
                if any(commandId == [ ...
                        "create_point_defects", ...
                        "wigner_seitz_cell", "make_p1"])
                    testCase.verifyFalse(endsWith( ...
                        string(control.Text), "..."));
                else
                    testCase.verifyTrue(endsWith( ...
                        string(control.Text), "..."));
                end
                testCase.verifyEqual(string(control.Tag), ...
                    "ModelingCommand_" + commandId);
            end

            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                structure);
            document = matlab.ui.internal.FigureDocument(struct( ...
                "Title", "Structure", ...
                "DocumentGroupTag", "Structure", ...
                "Tag", "modeling-test"));
            app.add(document);
            registry.register(document, display);
            drawnow

            testCase.verifyNotEmpty(tabGroup.contains("ModelingTab"));
            testCase.verifyEqual(registry.count(), 1);
            testCase.verifyEqual(registry.getCurrentDisplay(), display);
            testCase.verifyEqual(modeling.Profile, "crystal");
            testCase.verifyEqual( ...
                sort(string(modeling.Items.keys)), sort(crystalCommands));
            for commandIndex = 1:numel(crystalCommands)
                commandId = crystalCommands(commandIndex);
                testCase.verifyTrue( ...
                    modeling.Items(char(commandId)).Enabled, commandId);
            end
            defectPresetsSupported = ...
                kssolv.modeling.contracts.CommandCapability.supportsModel( ...
                    "create_point_defects", structure);
            for presetIndex = 1:numel(presetItems)
                testCase.verifyEqual( ...
                    presetItems{presetIndex}.Enabled, ...
                    defectPresetsSupported);
            end

            moleculeDisplay = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                molecule);
            moleculeDocument = matlab.ui.internal.FigureDocument(struct( ...
                "Title", "Molecule", ...
                "DocumentGroupTag", "Structure", ...
                "Tag", "modeling-molecule-test"));
            app.add(moleculeDocument);
            drawnow
            registry.register(moleculeDocument, moleculeDisplay);
            document.Selected = false;
            moleculeDocument.Selected = true;
            drawnow
            testCase.verifyEqual( ...
                registry.getCurrentDisplay(), moleculeDisplay);
            testCase.verifyEqual(modeling.Profile, "molecule");
            testCase.verifyEqual(string(modeling.Tab.Title), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:MoleculeModelingTab")));
            testCase.verifyEqual( ...
                sort(string(modeling.Items.keys)), sort(moleculeCommands));
            moleculeSections = modeling.Tab.Children;
            testCase.verifyEqual(string({moleculeSections.Tag}), [
                "ModelingHistorySection"
                "ModelingEditorsSection"
                "ModelingMoleculeSection"
                "ModelingSoftMatterSection"
                ].');
            moleculeButton = moleculeSections(3).Children(1).Children(1);
            testCase.verifyEqual(countPopupHeaders(moleculeButton.Popup), 3);
            fragmentSketcherItem = modeling.Items("attach_fragment");
            testCase.verifyClass(fragmentSketcherItem, ...
                "matlab.ui.internal.toolstrip.ListItem");
            testCase.verifyTrue(startsWith( ...
                string(fragmentSketcherItem.Text), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:FragmentBrowser"))));
            testCase.verifyFalse(isKey(modeling.Items, "build_supercell"));
            for commandIndex = 1:numel(moleculeCommands)
                commandId = moleculeCommands(commandIndex);
                testCase.verifyTrue( ...
                    modeling.Items(char(commandId)).Enabled, commandId);
            end

            moleculeDocument.Selected = false;
            document.Selected = true;
            drawnow
            testCase.verifyEqual(modeling.Profile, "crystal");
            testCase.verifyEqual( ...
                sort(string(modeling.Items.keys)), sort(crystalCommands));

            delete(moleculeDocument);
            delete(document);
            drawnow
            testCase.verifyEmpty(tabGroup.contains("ModelingTab"));
            delete(modeling);
            delete(registry);
            clear cleanup

            function count = countPopupHeaders(popup)
                count = 0;
                children = popup.Children;
                for popupChildIndex = 1:numel(children)
                    count = count + isa(children(popupChildIndex), ...
                        "matlab.ui.internal.toolstrip.PopupListHeader");
                end
            end

            function ids = expectedProfileCommands(model)
                ids = kssolv.modeling.CommandCatalog.commandIds();
                keep = false(size(ids));
                for commandPosition = 1:numel(ids)
                    keep(commandPosition) = kssolv.modeling.contracts. ...
                        CommandCapability.supportsModel( ...
                        ids(commandPosition), model);
                end
                ids = reshape(ids(keep), 1, []);
            end

            function cleanupApp(value)
                registryValue = ...
                    kssolv.ui.util.DataStorage.getData( ...
                    "ModelingSessionRegistry");
                if ~isempty(registryValue) && isvalid(registryValue)
                    delete(registryValue);
                end
                if ~isempty(value) && isvalid(value)
                    delete(value);
                end
                kssolv.ui.util.DataStorage.removeData("AppContainer");
            end
        end
    end
end
