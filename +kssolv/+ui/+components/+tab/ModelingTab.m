classdef ModelingTab < handle
    %MODELINGTAB Contextual structure-modeling toolstrip tab.

    properties (SetAccess = private)
        Tab
        Tag string = "ModelingTab"
        Title string
        Items containers.Map
    end

    properties (Access = private)
        TabGroup
        Registry
        Attached (1,1) logical = false
        RegistryListener
        AppListener
        DisplayListeners cell = {}
        CurrentDisplay = []
        UndoButton
        RedoButton
        Executing (1,1) logical = false
    end

    methods
        function this = ModelingTab(tabGroup)
            arguments
                tabGroup matlab.ui.internal.toolstrip.TabGroup
            end
            this.TabGroup = tabGroup;
            this.Registry = ...
                kssolv.ui.features.modeling.SessionRegistry.getInstance();
            this.Title = kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingTab");
            this.Items = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.buildTab();
            this.RegistryListener = addlistener( ...
                this.Registry, "SessionCountChanged", ...
                @(~, ~)this.syncVisibility());
            appContainer = ...
                kssolv.ui.util.DataStorage.getData("AppContainer");
            if ~isempty(appContainer) && isvalid(appContainer)
                this.AppListener = addlistener( ...
                    appContainer, "PropertyChanged", ...
                    @(~, ~)this.syncContext());
            end
            this.syncVisibility();
            kssolv.ui.util.DataStorage.setData("ModelingTab", this);
        end

        function delete(this)
            if ~isempty(this.RegistryListener) && ...
                    isvalid(this.RegistryListener)
                delete(this.RegistryListener);
            end
            if ~isempty(this.AppListener) && isvalid(this.AppListener)
                delete(this.AppListener);
            end
            this.clearDisplayListeners();
            stored = kssolv.ui.util.DataStorage.getData("ModelingTab");
            if ~isempty(stored) && isequal(stored, this)
                kssolv.ui.util.DataStorage.removeData("ModelingTab");
            end
        end
    end

    methods (Access = private)
        function buildTab(this)
            import matlab.ui.internal.toolstrip.*

            kssolv.ui.features.modeling.CommandPresentationCatalog.validate();
            this.Tab = Tab(this.Title);
            this.Tab.Tag = char(this.Tag);

            this.buildHistorySection();
            this.buildEditorsSection();
            this.buildSupercellSection();
            this.buildDefectsSection();
            this.buildNanostructuresSection();
            this.buildSurfacesSection();
            this.buildSymmetrySection();
        end

        function buildHistorySection(this)
            import matlab.ui.internal.toolstrip.*

            historySection = Section( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:History"));
            historySection.Tag = "ModelingHistorySection";
            column = Column();
            this.UndoButton = Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Undo"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("undo"));
            this.RedoButton = Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Redo"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("redo"));
            this.UndoButton.Tag = "ModelingUndo";
            this.RedoButton.Tag = "ModelingRedo";
            this.UndoButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:UndoTooltip");
            this.RedoButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RedoTooltip");
            column.add(this.UndoButton);
            column.add(this.RedoButton);
            historySection.add(column);
            this.Tab.add(historySection);
            addlistener(this.UndoButton, "ButtonPushed", ...
                @(~, ~)this.undo());
            addlistener(this.RedoButton, "ButtonPushed", ...
                @(~, ~)this.redo());
        end

        function buildEditorsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = Section( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:EditorsSection"));
            section.Tag = "ModelingEditorsSection";

            atomicColumn = Column();
            atomicButton = DropDownButton( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:AtomicEditor"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                categoryIcon("atomic_editor"));
            atomicButton.Tag = "ModelingCategory_atomic_editor";
            atomicButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:AtomicEditorTooltip");
            atomicButton.Popup = this.createGroupedPopup([
                this.popupGroup("SitesSpeciesGroup", [
                    "add_atom", "delete_atoms", "merge_atoms", ...
                    "substitute_atoms"])
                this.popupGroup("PositionTransformGroup", [
                    "center_atoms", "move_atoms", "mirror_atoms", ...
                    "rotate_atoms", "translate_atoms", "perturb_atoms"])
                this.popupGroup("ConstraintsOrderingGroup", [
                    "fix_atoms", "sort_atoms"])
                ]);
            atomicColumn.add(atomicButton);

            latticeColumn = Column();
            latticeButton = DropDownButton( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:LatticeEditor"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                categoryIcon("lattice_editor"));
            latticeButton.Tag = "ModelingCategory_lattice_editor";
            latticeButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:LatticeEditorTooltip");
            latticeButton.Popup = this.createGroupedPopup([
                this.popupGroup("EditGroup", [
                    "edit_lattice", "apply_strain"])
                this.popupGroup("TransformGroup", [
                    "mirror_lattice", "rotate_lattice", "swap_axes"])
                ]);
            latticeColumn.add(latticeButton);

            section.add(atomicColumn);
            section.add(latticeColumn);
            this.Tab.add(section);
        end

        function buildSupercellSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "SupercellLattice", "ModelingSupercellSection");
            column = Column();
            button = this.createCategoryDropDown( ...
                "SupercellLattice", "SupercellLatticeTooltip", ...
                "supercell_lattice");
            button.Popup = this.createGroupedPopup([
                this.popupGroup("CellConstructionGroup", [
                    "build_supercell", "redefine_lattice", ...
                    "orthogonalize_cell"])
                this.popupGroup("StructureDeformationGroup", [
                    "strain_structure", "perturb_structure"])
                ]);
            column.add(button);
            section.add(column);
            this.Tab.add(section);
        end

        function buildDefectsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "DefectsAlloys", "ModelingDefectsSection");
            defectsColumn = Column();
            defectsButton = this.createCommandButton( ...
                "create_point_defects", "split", 24);
            defectsButton.Popup = this.createDefectPopup();
            defectsColumn.add(defectsButton);

            sqsColumn = Column();
            sqsColumn.add(this.createCommandButton( ...
                "generate_sqs_model", "push", 24));
            section.add(defectsColumn);
            section.add(sqsColumn);
            this.Tab.add(section);
        end

        function buildNanostructuresSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "Nanostructures", "ModelingNanostructuresSection");
            column = Column();
            button = this.createCategoryDropDown( ...
                "Nanostructures", "NanostructuresTooltip", ...
                "nanostructures");
            button.Popup = this.createNanostructuresPopup();
            column.add(button);
            section.add(column);
            this.Tab.add(section);
        end

        function buildSurfacesSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "SurfacesInterfaces", "ModelingSurfacesSection");
            surfaceColumn = Column();
            surfaceButton = this.createCategoryDropDown( ...
                "SurfaceModeling", "SurfaceModelingTooltip", ...
                "surface_modeling");
            surfaceButton.Popup = this.createGroupedPopup([
                this.popupGroup("SurfaceConstructionGroup", [
                    "build_slab", "add_vacuum"])
                this.popupGroup("SurfaceChemistryGroup", [
                    "find_adsorption_sites", "passivate_surface", ...
                    "add_solvent_layer"])
                ]);
            surfaceColumn.add(surfaceButton);

            interfaceColumn = Column();
            interfaceButton = this.createCategoryDropDown( ...
                "InterfaceModeling", "InterfaceModelingTooltip", ...
                "interface_modeling");
            interfaceButton.Popup = this.createGroupedPopup([
                this.popupGroup("InterfaceAssemblyGroup", [
                    "insert_structure", "stack_heterostructure", ...
                    "twist_moire"])
                this.popupGroup("TransitionPathGroup", ...
                    "interpolate_neb")
                ]);
            interfaceColumn.add(interfaceButton);

            section.add(surfaceColumn);
            section.add(interfaceColumn);
            this.Tab.add(section);
        end

        function buildSymmetrySection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "SymmetryTools", "ModelingSymmetrySection");
            column = Column();
            button = this.createCategoryDropDown( ...
                "SymmetryTools", "SymmetryToolsTooltip", ...
                "symmetry_tools");
            button.Popup = this.createGroupedPopup( ...
                this.popupGroup("SymmetryAnalysisGroup", [
                "find_symmetry", "primitive_cell", ...
                "conventional_cell", "wigner_seitz_cell"]));
            column.add(button);
            section.add(column);
            this.Tab.add(section);
        end

        function section = createSection(~, labelKey, tag)
            import matlab.ui.internal.toolstrip.Section

            section = Section(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(labelKey)));
            section.Tag = char(tag);
        end

        function button = createCategoryDropDown( ...
                ~, labelKey, tooltipKey, categoryId)
            import matlab.ui.internal.toolstrip.DropDownButton

            button = DropDownButton( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(labelKey)), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                categoryIcon(categoryId));
            button.Tag = "ModelingCategory_" + string(categoryId);
            button.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(tooltipKey));
        end

        function value = popupGroup(~, titleKey, commandIds)
            value = struct( ...
                "titleKey", string(titleKey), ...
                "commandIds", reshape(string(commandIds), 1, []));
        end

        function popup = createGroupedPopup(this, groups)
            import matlab.ui.internal.toolstrip.*

            popup = PopupList();
            for groupIndex = 1:numel(groups)
                if groupIndex > 1
                    popup.addSeparator();
                end
                popup.add(PopupListHeader( ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:" + ...
                    groups(groupIndex).titleKey)));
                commandIds = groups(groupIndex).commandIds;
                for commandIndex = 1:numel(commandIds)
                    popup.add(this.createCommandItem( ...
                        commandIds(commandIndex)));
                end
            end
        end

        function button = createCommandButton( ...
                this, commandId, type, iconSize)
            import matlab.ui.internal.toolstrip.*

            if nargin < 4
                iconSize = 16;
            end
            commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
            label = kssolv.ui.util.Localizer.message( ...
                commandInfo.labelKey);
            icon = kssolv.ui.features.modeling.CommandPresentationCatalog.icon( ...
                commandId, iconSize);
            switch string(type)
                case "push"
                    button = Button(label, icon);
                case "split"
                    button = SplitButton(label, icon);
                case "dropdown"
                    button = DropDownButton(label, icon);
                otherwise
                    error("KSSOLV:Modeling:ButtonType", ...
                        "Unsupported Modeling button type '%s'.", type);
            end
            button.Tag = "ModelingCommand_" + string(commandId);
            button.Description = ...
                kssolv.ui.util.Localizer.message( ...
                commandInfo.tooltipKey);
            button.Enabled = ...
                kssolv.modeling.CommandExecutor.supports(commandId);
            if string(type) ~= "dropdown" && button.Enabled
                addlistener(button, "ButtonPushed", ...
                    @(~, ~)this.executeCommand(commandId));
            end
            this.Items(char(commandId)) = button;
        end

        function item = createCommandItem(this, commandId)
            import matlab.ui.internal.toolstrip.ListItem

            commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
            item = ListItem( ...
                kssolv.ui.util.Localizer.message(commandInfo.labelKey), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.icon( ...
                commandId, 24));
            item.Tag = "ModelingCommand_" + string(commandId);
            item.Description = ...
                kssolv.ui.util.Localizer.message( ...
                commandInfo.tooltipKey);
            item.Enabled = ...
                kssolv.modeling.CommandExecutor.supports(commandId);
            if item.Enabled
                addlistener(item, "ItemPushed", ...
                    @(~, ~)this.executeCommand(commandId));
            end
            this.Items(char(commandId)) = item;
        end

        function popup = createDefectPopup(this)
            import matlab.ui.internal.toolstrip.*

            popup = PopupList();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:DefectTypeGroup")));
            popup.add(this.createPresetItem( ...
                "create_point_defects", "Vacancy", ...
                struct("defectType", "vacancy"), false));
            popup.add(this.createPresetItem( ...
                "create_point_defects", "Substitution", ...
                struct("defectType", "substitution"), false));
            popup.add(this.createPresetItem( ...
                "create_point_defects", "Interstitial", ...
                struct("defectType", "interstitial"), false));
            popup.add(this.createPresetItem( ...
                "create_point_defects", "Antisite", ...
                struct("defectType", "antisite"), false));
        end

        function popup = createNanostructuresPopup(this)
            import matlab.ui.internal.toolstrip.*

            popup = PopupList();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:OneDimensionalGroup")));
            popup.add(this.createCommandItem("roll_nanotube"));
            popup.add(this.createCommandItem("cut_nanoribbon"));
            popup.add(this.createCommandItem("cut_nanowire"));
            popup.addSeparator();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ZeroDimensionalGroup")));
            popup.add(this.createCommandItem("quantum_dot_void"));
        end

        function item = createPresetItem( ...
                this, commandId, labelKey, preset, includeIcon)
            import matlab.ui.internal.toolstrip.ListItem

            if nargin < 5
                includeIcon = true;
            end
            label = kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(labelKey));
            if includeIcon
                item = ListItem(label, ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    icon(commandId, 24));
            else
                item = ListItem(label);
            end
            item.Tag = "ModelingPreset_" + string(commandId) + ...
                "_" + string(labelKey);
            item.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(labelKey) + ...
                "Description");
            addlistener(item, "ItemPushed", ...
                @(~, ~)this.executeCommand(commandId, preset));
        end

        function syncVisibility(this)
            shouldAttach = this.Registry.hasSessions();
            if shouldAttach && ~this.Attached
                this.TabGroup.add(this.Tab);
                this.Attached = true;
            elseif ~shouldAttach && this.Attached
                this.TabGroup.remove(this.Tab);
                this.Attached = false;
            end
            this.syncContext();
            this.refreshHistoryButtons();
        end

        function syncContext(this)
            display = this.Registry.getCurrentDisplay();
            if ~isempty(this.CurrentDisplay) && ...
                    isvalid(this.CurrentDisplay) && ...
                    isequal(this.CurrentDisplay, display)
                this.refreshHistoryButtons();
                return
            end
            this.clearDisplayListeners();
            this.CurrentDisplay = display;
            if ~isempty(display) && isvalid(display)
                this.DisplayListeners = {
                    addlistener(display, "HistoryChanged", ...
                    @(~, ~)this.refreshHistoryButtons())
                    };
            end
            this.refreshHistoryButtons();
        end

        function clearDisplayListeners(this)
            for index = 1:numel(this.DisplayListeners)
                listener = this.DisplayListeners{index};
                if ~isempty(listener) && isvalid(listener)
                    delete(listener);
                end
            end
            this.DisplayListeners = {};
            this.CurrentDisplay = [];
        end

        function executeCommand(this, commandId, preset)
            if nargin < 3
                preset = struct();
            end
            if this.Executing
                return
            end
            this.setExecuting(true);
            cleanup = onCleanup(@()this.setExecuting(false));
            try
                display = this.requireCurrentDisplay();
                commandInfo = ...
                    kssolv.modeling.CommandCatalog.find(commandId);
                commandLabel = kssolv.ui.util.Localizer.message( ...
                    commandInfo.labelKey);
                this.updateStatus(sprintf( ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:RunningCommand"), ...
                    commandLabel));
                appContainer = ...
                    kssolv.ui.util.DataStorage.getData("AppContainer");
                [parameters, cancelled] = ...
                    kssolv.ui.features.modeling.ParameterDialog.prompt( ...
                    commandInfo, display, preset, appContainer);
                if cancelled
                    this.updateStatus("");
                    return
                end
                parameters = ...
                    kssolv.ui.features.modeling.ModelInputResolver.enrich( ...
                    commandId, parameters);
                result = kssolv.modeling.CommandExecutor.execute( ...
                    display.getModel(), commandId, parameters);
                if isfield(result, "models") && ~isempty(result.models)
                    kssolv.ui.features.modeling.DerivedStructureService.publish( ...
                        result.models, result.labels);
                    kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                        commandId, display.getModel(), result, ...
                        kssolv.ui.util.Localizer.message( ...
                        commandInfo.labelKey), appContainer);
                elseif result.changed
                    display.applyModel(result.model, ...
                        commandLabel);
                else
                    kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                        commandId, display.getModel(), result, ...
                        kssolv.ui.util.Localizer.message( ...
                        commandInfo.labelKey), appContainer);
                end
                this.refreshHistoryButtons();
                this.updateStatus(sprintf( ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:CompletedCommand"), ...
                    commandLabel));
            catch exception
                this.updateStatus(exception.message);
                appContainer = ...
                    kssolv.ui.util.DataStorage.getData("AppContainer");
                if ~isempty(appContainer) && isvalid(appContainer)
                    uialert(appContainer, exception.message, ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:ModelingError"), ...
                        "Icon", "error");
                else
                    warning("KSSOLV:Modeling:CommandFailed", ...
                        "%s", exception.message);
                end
            end
            clear cleanup
        end

        function display = requireCurrentDisplay(this)
            display = this.Registry.getCurrentDisplay();
            if isempty(display)
                error("KSSOLV:Modeling:NoActiveStructure", ...
                    "Select an open structure document before modeling.");
            end
            if ~display.isCrystal()
                error("KSSOLV:Modeling:CrystalRequired", ...
                    "The selected command requires a crystal structure.");
            end
        end

        function undo(this)
            display = this.requireCurrentDisplay();
            display.undo();
            this.refreshHistoryButtons();
        end

        function redo(this)
            display = this.requireCurrentDisplay();
            display.redo();
            this.refreshHistoryButtons();
        end

        function refreshHistoryButtons(this)
            display = this.Registry.getCurrentDisplay();
            if this.Executing || isempty(display)
                this.UndoButton.Enabled = false;
                this.RedoButton.Enabled = false;
            else
                this.UndoButton.Enabled = display.canUndo();
                this.RedoButton.Enabled = display.canRedo();
            end
        end

        function setExecuting(this, value)
            this.Executing = logical(value);
            keys = this.Items.keys;
            for index = 1:numel(keys)
                control = this.Items(keys{index});
                if isempty(control) || ~isvalid(control)
                    continue
                end
                if this.Executing
                    control.Enabled = false;
                else
                    control.Enabled = ...
                        kssolv.modeling.CommandExecutor.supports( ...
                        string(keys{index}));
                end
            end
            this.refreshHistoryButtons();
        end

        function updateStatus(~, text)
            footer = kssolv.ui.util.DataStorage.getData("FooterBar");
            if ~isempty(footer) && isvalid(footer)
                footer.setLabelText(string(text));
            end
        end
    end
end
