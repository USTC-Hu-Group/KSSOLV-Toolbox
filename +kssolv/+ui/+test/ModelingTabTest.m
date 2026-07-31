classdef ModelingTabTest < matlab.unittest.TestCase
    %MODELINGTABTEST Contextual toolstrip lifecycle contract.

    methods (Test)
        function analysisResultsCreateVisualFigures(testCase)
            previous = get(groot, "defaultFigureVisible");
            set(groot, "defaultFigureVisible", "off");
            cleanup = onCleanup(@()restoreFigures(previous));
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
                "Wigner-Seitz cell"));
            testCase.verifyGreaterThanOrEqual( ...
                numel(findall(groot, "Type", "figure")), 2);
            clear cleanup

            function restoreFigures(value)
                close(findall(groot, "Type", "figure"));
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
