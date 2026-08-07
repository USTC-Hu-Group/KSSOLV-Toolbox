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

            modeling = kssolv.ui.components.tab.ModelingTab(tabGroup);
            registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
            testCase.verifyEmpty(tabGroup.contains("ModelingTab"));
            testCase.verifyEqual(double(modeling.Items.Count), 41);
            testCase.verifyEqual( ...
                sort(string(modeling.Items.keys)), ...
                sort(kssolv.modeling.CommandCatalog.commandIds().'));
            sections = modeling.Tab.Children;
            testCase.verifyEqual(numel(sections), 7);
            testCase.verifyEqual(string({sections.Tag}), [
                "ModelingHistorySection"
                "ModelingEditorsSection"
                "ModelingSupercellSection"
                "ModelingDefectsSection"
                "ModelingNanostructuresSection"
                "ModelingSurfacesSection"
                "ModelingSymmetrySection"
                ].');
            for sectionIndex = 1:numel(sections)
                columns = sections(sectionIndex).Children;
                for columnIndex = 1:numel(columns)
                    testCase.verifyLessThanOrEqual( ...
                    numel(columns(columnIndex).Children), 3);
                end
            end
            testCase.verifyEqual( ...
                arrayfun(@(section)numel(section.Children), sections), ...
                [1, 2, 1, 2, 1, 2, 1]);
            supercellButton = sections(3).Children(1).Children(1);
            nanoButton = sections(5).Children(1).Children(1);
            surfaceButton = sections(6).Children(1).Children(1);
            interfaceButton = sections(6).Children(2).Children(1);
            symmetryButton = sections(7).Children(1).Children(1);
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
                countPopupHeaders(symmetryButton.Popup), 1);

            defectButton = sections(4).Children(1).Children(1);
            defectItems = defectButton.Popup.Children(2:end);
            defectDescriptionKeys = [
                "VacancyDescription"
                "SubstitutionDescription"
                "InterstitialDescription"
                "AntisiteDescription"
                ];
            for itemIndex = 1:numel(defectItems)
                testCase.verifyEmpty(defectItems(itemIndex).Icon);
                testCase.verifyTrue(endsWith( ...
                    string(defectItems(itemIndex).Text), "..."));
                testCase.verifyEqual( ...
                    string(defectItems(itemIndex).Description), ...
                    string(kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:" + ...
                    defectDescriptionKeys(itemIndex))));
            end

            symmetryItems = symmetryButton.Popup.Children(2:end);
            testCase.verifyEqual(string({symmetryItems.Tag}), [
                "ModelingCommand_find_symmetry"
                "ModelingCommand_primitive_cell"
                "ModelingCommand_conventional_cell"
                "ModelingCommand_wigner_seitz_cell"
                ].');
            commandIds = kssolv.modeling.CommandCatalog.commandIds();
            for commandIndex = 1:numel(commandIds)
                commandId = commandIds(commandIndex);
                control = modeling.Items(char(commandId));
                testCase.verifyTrue(control.Enabled);
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
                if any(commandId == [
                        "generate_sqs_model", ...
                        "wigner_seitz_cell"])
                    testCase.verifyFalse(endsWith( ...
                        string(control.Text), "..."));
                else
                    testCase.verifyTrue(endsWith( ...
                        string(control.Text), "..."));
                end
                testCase.verifyEqual(string(control.Tag), ...
                    "ModelingCommand_" + commandId);
            end

            structure = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
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

            delete(document);
            drawnow
            testCase.verifyEmpty(tabGroup.contains("ModelingTab"));
            delete(modeling);
            delete(registry);
            clear cleanup

            function count = countPopupHeaders(popup)
                count = 0;
                children = popup.Children;
                for childIndex = 1:numel(children)
                    count = count + isa(children(childIndex), ...
                        "matlab.ui.internal.toolstrip.PopupListHeader");
                end
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
