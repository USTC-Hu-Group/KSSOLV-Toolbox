classdef ModelingTab < handle
    %MODELINGTAB Contextual structure-modeling toolstrip tab.

    properties (SetAccess = private)
        Tab
        Tag string = "ModelingTab"
        Title string
        Profile string = "crystal"
        Items containers.Map
    end

    properties (Access = private)
        TabGroup
        Registry
        Attached (1,1) logical = false
        RegistryListener
        ActiveRegistryListener
        AppListener
        DisplayListeners cell = {}
        CurrentDisplay = []
        UndoButton
        RedoButton
        ResetButton
        SelectionSetButton
        RecorderStartButton
        RecorderSaveButton
        JobsButton
        JobsWindow
        LibraryButton
        LibraryWindow
        GuideButton
        FragmentBrowserButton
        FragmentBrowserWindow
        FragmentBrowserHostIndices (1,:) double = zeros(1, 0)
        PresetItems cell = {}
        Executing (1,1) logical = false
        IsShuttingDown (1,1) logical = false
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
                "KSSOLV:modeling:CrystalModelingTab");
            this.Items = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.buildTab();
            this.RegistryListener = addlistener( ...
                this.Registry, "SessionCountChanged", ...
                @(~, ~)this.syncVisibility());
            this.ActiveRegistryListener = addlistener( ...
                this.Registry, "ActiveSessionChanged", ...
                @(~, ~)this.syncContext());
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
            this.prepareForShutdown();
            stored = kssolv.ui.util.DataStorage.getData("ModelingTab");
            if ~isempty(stored) && isequal(stored, this)
                kssolv.ui.util.DataStorage.removeData("ModelingTab");
            end
        end

        function prepareForShutdown(this)
            %PREPAREFORSHUTDOWN Stop all callbacks that mutate the toolstrip.
            if this.IsShuttingDown
                return
            end
            this.IsShuttingDown = true;
            if ~isempty(this.RegistryListener) && ...
                    isvalid(this.RegistryListener)
                delete(this.RegistryListener);
            end
            if ~isempty(this.ActiveRegistryListener) && ...
                    isvalid(this.ActiveRegistryListener)
                delete(this.ActiveRegistryListener);
            end
            if ~isempty(this.AppListener) && isvalid(this.AppListener)
                delete(this.AppListener);
            end
            this.clearDisplayListeners();
            if ~isempty(this.FragmentBrowserWindow) && ...
                    isvalid(this.FragmentBrowserWindow)
                delete(this.FragmentBrowserWindow);
            end
            if ~isempty(this.JobsWindow) && isvalid(this.JobsWindow)
                delete(this.JobsWindow);
            end
            if ~isempty(this.LibraryWindow) && isvalid(this.LibraryWindow)
                delete(this.LibraryWindow);
            end
        end
    end

    methods (Access = private)
        function buildTab(this)
            import matlab.ui.internal.toolstrip.*

            kssolv.ui.features.modeling.CommandPresentationCatalog.validate();
            this.Tab = Tab(this.Title);
            this.Tab.Tag = char(this.Tag);

            this.buildProfileSections();
        end

        function buildProfileSections(this)
            this.buildHistorySection();
            if this.Profile == "molecule"
                this.buildMoleculeEditorsSection();
                this.buildMoleculeSection();
                this.buildSoftMatterSection();
            else
                this.buildCrystalEditorsSection();
                this.buildCrystalCellSection();
                this.buildCrystalMaterialsSection();
                this.buildSurfacesSection();
                this.buildMolecularComponentsSection();
            end
        end

        function rebuildProfile(this, profile)
            profile = string(profile);
            if profile == this.Profile
                return
            end
            sections = this.Tab.Children;
            for sectionIndex = numel(sections):-1:1
                section = sections(sectionIndex);
                this.Tab.remove(section);
                if isvalid(section)
                    delete(section);
                end
            end
            this.resetProfileControls();
            this.Profile = profile;
            if profile == "molecule"
                this.Title = kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:MoleculeModelingTab");
            else
                this.Title = kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:CrystalModelingTab");
            end
            this.Tab.Title = char(this.Title);
            this.buildProfileSections();
        end

        function resetProfileControls(this)
            this.Items = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.PresetItems = {};
            this.UndoButton = [];
            this.RedoButton = [];
            this.ResetButton = [];
            this.SelectionSetButton = [];
            this.RecorderStartButton = [];
            this.RecorderSaveButton = [];
            this.JobsButton = [];
            this.LibraryButton = [];
            this.GuideButton = [];
            this.FragmentBrowserButton = [];
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
            this.ResetButton = Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Reset"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("reset"));
            this.UndoButton.Tag = "ModelingUndo";
            this.RedoButton.Tag = "ModelingRedo";
            this.ResetButton.Tag = "ModelingReset";
            this.UndoButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:UndoTooltip");
            this.RedoButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RedoTooltip");
            this.ResetButton.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ResetStructureTooltip");
            column.add(this.UndoButton);
            column.add(this.RedoButton);
            column.add(this.ResetButton);
            historySection.add(column);
            recorderColumn=Column();
            this.RecorderStartButton=Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:StartRecording"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("record_start"));
            this.RecorderSaveButton=Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SaveRecording"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("record_save"));
            this.JobsButton=Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingJobs"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("jobs"));
            this.LibraryButton=Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingLibraries"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("library"));
            this.RecorderStartButton.Tag="ModelingStartRecording";
            this.RecorderSaveButton.Tag="ModelingSaveRecording";
            this.JobsButton.Tag="ModelingJobs";
            this.LibraryButton.Tag="ModelingLibraries";
            this.RecorderStartButton.Description= ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:StartRecordingTooltip");
            this.RecorderSaveButton.Description= ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SaveRecordingTooltip");
            recorderColumn.add(this.RecorderStartButton);
            recorderColumn.add(this.RecorderSaveButton);
            recorderColumn.add(this.JobsButton);
            libraryColumn=Column(); libraryColumn.add(this.LibraryButton);
            this.GuideButton=Button( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingGuide"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                utilityIcon("guide",24));
            this.GuideButton.Tag="ModelingGuide";
            this.GuideButton.Description= ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingGuideTooltip");
            libraryColumn.add(this.GuideButton);
            historySection.add(recorderColumn);
            historySection.add(libraryColumn);
            this.Tab.add(historySection);
            addlistener(this.UndoButton, "ButtonPushed", ...
                @(~, ~)this.runUiAction(@()this.undo()));
            addlistener(this.RedoButton, "ButtonPushed", ...
                @(~, ~)this.runUiAction(@()this.redo()));
            addlistener(this.ResetButton, "ButtonPushed", ...
                @(~, ~)this.runUiAction(@()this.reset()));
            addlistener(this.RecorderStartButton,"ButtonPushed", ...
                @(~,~)this.runUiAction(@()this.startRecording()));
            addlistener(this.RecorderSaveButton,"ButtonPushed", ...
                @(~,~)this.runUiAction(@()this.saveRecording()));
            addlistener(this.JobsButton,"ButtonPushed", ...
                @(~,~)this.runUiAction(@()this.openJobs()));
            addlistener(this.LibraryButton,"ButtonPushed", ...
                @(~,~)this.runUiAction(@()this.openLibraries()));
            addlistener(this.GuideButton,"ButtonPushed", ...
                @(~,~)this.runUiAction(@()this.openModelingGuide()));
        end

        function openModelingGuide(~)
            locale=string(kssolv.ui.util.Localizer. ...
                getInstance().currentLocale);
            if locale=="zh_CN"
                filename="modeling-user-guide.zh-CN.md";
            else
                filename="modeling-user-guide.md";
            end
            path=fullfile(KSSOLV_Toolbox.RootDirectory,"docs", ...
                filename);
            if ~isfile(path)
                error("KSSOLV:Modeling:GuideMissing", ...
                    "The installed modeling user guide is missing: %s",path);
            end
            kssolv.ui.util.openWithSystemDefault(path);
        end

        function openJobs(this)
            if isempty(this.JobsWindow) || ~isvalid(this.JobsWindow) || ...
                    isempty(this.JobsWindow.Figure) || ...
                    ~isvalid(this.JobsWindow.Figure)
                this.JobsWindow= ...
                    kssolv.ui.features.modeling.ModelingJobsBrowser();
            else
                this.JobsWindow.refresh();
                this.JobsWindow.Figure.Visible="on";
                figure(this.JobsWindow.Figure);
            end
        end

        function openLibraries(this)
            if isempty(this.LibraryWindow) || ~isvalid(this.LibraryWindow) || ...
                    isempty(this.LibraryWindow.Figure) || ...
                    ~isvalid(this.LibraryWindow.Figure)
                this.LibraryWindow= ...
                    kssolv.ui.features.modeling.ModelingLibraryBrowser();
            else
                this.LibraryWindow.refresh();
                this.LibraryWindow.Figure.Visible="on";
                figure(this.LibraryWindow.Figure);
            end
        end

        function buildCrystalEditorsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "EditorsSection", "ModelingEditorsSection");
            atomicColumn = Column();
            atomicButton = this.createCategoryDropDown( ...
                "AtomicEditor", "AtomicEditorTooltip", "atomic_editor");
            atomicButton.Popup = this.createGroupedPopup([
                this.popupGroup("SitesSpeciesGroup", [ ...
                    "add_atom", "delete_atoms", "merge_atoms", ...
                    "substitute_atoms"])
                this.popupGroup("ConstraintsOrderingGroup", [ ...
                    "fix_atoms", "sort_atoms"])
                ]);
            atomicColumn.add(atomicButton);

            selectionColumn = Column();
            this.SelectionSetButton = this.createSelectionSetButton();
            selectionColumn.add(this.SelectionSetButton);
            section.add(atomicColumn);
            section.add(selectionColumn);
            this.Tab.add(section);
        end

        function buildMoleculeEditorsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "EditorsSection", "ModelingEditorsSection");
            atomicColumn = Column();
            atomicButton = this.createCategoryDropDown( ...
                "AtomicEditor", "AtomicEditorTooltip", "atomic_editor");
            atomicButton.Popup = this.createGroupedPopup([
                this.popupGroup("SitesSpeciesGroup", [ ...
                    "add_atom", "delete_atoms", "substitute_atoms"])
                this.popupGroup("PositionTransformGroup", [ ...
                    "center_atoms", "move_atoms", "mirror_atoms", ...
                    "rotate_atoms", "translate_atoms", "perturb_atoms"])
                ]);
            atomicColumn.add(atomicButton);

            geometryColumn = Column();
            geometryButton = this.createCategoryDropDown( ...
                "GeometryEditor", "GeometryEditorTooltip", ...
                "molecule_builder");
            geometryButton.Popup = this.createGroupedPopup([
                this.popupGroup("MoleculeGeometryGroup", [ ...
                    "measure_geometry", "set_distance", "set_angle", ...
                    "set_dihedral", "align_geometry"])
                this.popupGroup("CleanupGroup", [ ...
                    "clean_geometry", "optimize_geometry"])
                ]);
            geometryColumn.add(geometryButton);

            selectionColumn = Column();
            this.SelectionSetButton = this.createSelectionSetButton();
            selectionColumn.add(this.SelectionSetButton);
            section.add(atomicColumn);
            section.add(geometryColumn);
            section.add(selectionColumn);
            this.Tab.add(section);
        end

        function button = createSelectionSetButton(~)
            import matlab.ui.internal.toolstrip.DropDownButton

            button = DropDownButton( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SelectionSets"), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                categoryIcon("selection_sets"));
            button.Tag = "ModelingSelectionSets";
            button.Description = ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SelectionSetsTooltip");
        end

        function buildCrystalCellSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "CrystalCellSection", "ModelingCrystalCellSection");

            latticeColumn = Column();
            latticeButton = this.createCategoryDropDown( ...
                "LatticeEditor", "LatticeEditorTooltip", "lattice_editor");
            latticeButton.Popup = this.createGroupedPopup([
                this.popupGroup("EditGroup", [ ...
                    "edit_lattice", "apply_strain"])
                this.popupGroup("TransformGroup", [ ...
                    "mirror_lattice", "rotate_lattice", "swap_axes"])
                ]);
            latticeColumn.add(latticeButton);

            supercellColumn = Column();
            supercellButton = this.createCategoryDropDown( ...
                "SupercellLattice", "SupercellLatticeTooltip", ...
                "supercell_lattice");
            supercellButton.Popup = this.createGroupedPopup([
                this.popupGroup("CellConstructionGroup", [ ...
                    "build_supercell", "redefine_lattice", ...
                    "orthogonalize_cell"])
                this.popupGroup("StructureDeformationGroup", [ ...
                    "strain_structure", "perturb_structure"])
                ]);
            supercellColumn.add(supercellButton);

            symmetryColumn = Column();
            symmetryButton = this.createCategoryDropDown( ...
                "SymmetryTools", "SymmetryToolsTooltip", "symmetry_tools");
            symmetryButton.Popup = this.createGroupedPopup([
                this.popupGroup("CrystalConstructionGroup", [ ...
                    "build_from_spacegroup", "make_p1"])
                this.popupGroup("SymmetryAnalysisGroup", [ ...
                    "find_symmetry", "primitive_cell", ...
                    "conventional_cell", "wigner_seitz_cell"])
                ]);
            symmetryColumn.add(symmetryButton);

            section.add(latticeColumn);
            section.add(supercellColumn);
            section.add(symmetryColumn);
            this.Tab.add(section);
        end

        function buildCrystalMaterialsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "CrystalMaterialsSection", "ModelingCrystalMaterialsSection");
            defectColumn = Column();
            defectButton = this.createCategoryDropDown( ...
                "DefectsAlloys", "DefectsAlloysTooltip", "defects_alloys");
            defectButton.Popup = this.createDefectsAlloysPopup();
            defectColumn.add(defectButton);

            nanoColumn = Column();
            nanoButton = this.createCategoryDropDown( ...
                "Nanostructures", "NanostructuresTooltip", "nanostructures");
            nanoButton.Popup = this.createNanostructuresPopup();
            nanoColumn.add(nanoButton);
            section.add(defectColumn);
            section.add(nanoColumn);
            this.Tab.add(section);
        end

        function buildMolecularComponentsSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "MolecularComponentsSection", ...
                "ModelingMolecularComponentsSection");

            transformColumn = Column();
            transformButton = this.createCategoryDropDown( ...
                "ComponentTransform", "ComponentTransformTooltip", ...
                "atomic_editor");
            transformButton.Popup = this.createGroupedPopup( ...
                this.popupGroup("PositionTransformGroup", [ ...
                "center_atoms", "move_atoms", "mirror_atoms", ...
                "rotate_atoms", "translate_atoms", "perturb_atoms", ...
                "align_geometry"]));
            transformColumn.add(transformButton);

            geometryColumn = Column();
            geometryButton = this.createCategoryDropDown( ...
                "ComponentGeometry", "ComponentGeometryTooltip", ...
                "molecule_builder");
            geometryButton.Popup = this.createGroupedPopup( ...
                this.popupGroup("MoleculeGeometryGroup", [ ...
                "measure_geometry", "set_distance", "set_angle", ...
                "set_dihedral"]));
            geometryColumn.add(geometryButton);

            packingColumn = Column();
            packingButton = this.createCategoryDropDown( ...
                "HostPacking", "HostPackingTooltip", "amorphous_builder");
            packingButton.Popup = this.createGroupedPopup( ...
                this.popupGroup("PackingConstructionGroup", [ ...
                "pack_into_existing_box", "pack_around_nanoparticle"]));
            packingColumn.add(packingButton);

            section.add(transformColumn);
            section.add(geometryColumn);
            section.add(packingColumn);
            this.Tab.add(section);
        end

        function buildMoleculeSection(this)
            import matlab.ui.internal.toolstrip.*

            section = this.createSection( ...
                "MoleculeBuilder", "ModelingMoleculeSection");
            sketchColumn = Column();
            sketchButton = this.createCategoryDropDown( ...
                "MoleculeBuilder", "MoleculeBuilderTooltip", ...
                "molecule_builder");
            sketchButton.Popup = this.createGroupedPopup([
                this.popupGroup("MoleculeSketchGroup", [ ...
                    "sketch_atom", "add_bond", "delete_bond", ...
                    "set_bond_order", "sketch_ring"])
                this.popupGroup("MoleculeChemistryGroup", [ ...
                    "set_atom_chemistry", "add_hydrogens", ...
                    "remove_hydrogens", "diagnose_molecule"])
                this.popupGroup("MoleculeFragmentGroup", [ ...
                    "attach_fragment", "save_user_fragment"])
                ]);
            sketchColumn.add(sketchButton);
            section.add(sketchColumn);
            this.FragmentBrowserButton = ...
                this.Items(char("attach_fragment"));
            this.Tab.add(section);
        end

        function buildSoftMatterSection(this)
            import matlab.ui.internal.toolstrip.*
            section=this.createSection("SoftMatter", ...
                "ModelingSoftMatterSection");
            polymerColumn=Column();
            polymerButton=this.createCategoryDropDown( ...
                "PolymerBuilder","PolymerBuilderTooltip","polymer_builder");
            polymerButton.Popup=this.createGroupedPopup( ...
                this.popupGroup("PolymerConstructionGroup",[ ...
                "build_homopolymer","build_block_copolymer", ...
                "build_random_copolymer","build_branched_polymer", ...
                "build_dendrimer", ...
                "save_user_repeat_unit"]));
            polymerColumn.add(polymerButton);
            packingColumn=Column();
            packingButton=this.createCategoryDropDown( ...
                "AmorphousBuilder","AmorphousBuilderTooltip", ...
                "amorphous_builder");
            packingButton.Popup=this.createGroupedPopup( ...
                this.popupGroup("PackingConstructionGroup",[ ...
                "construct_amorphous","pack_mixture", ...
                "build_confined_layer"]));
            packingColumn.add(packingButton);
            section.add(polymerColumn); section.add(packingColumn);
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
                    "find_adsorption_sites", "locate_adsorbate", ...
                    "place_adsorbate", ...
                    "passivate_surface", ...
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
                this, commandId, type, iconSize, indicateDialog)
            import matlab.ui.internal.toolstrip.*

            if nargin < 4
                iconSize = 16;
            end
            if nargin < 5
                indicateDialog = true;
            end
            commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
            label = kssolv.ui.util.Localizer.message( ...
                commandInfo.labelKey);
            if indicateDialog
                label = this.dialogLabel(label);
            end
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
            isFragmentSketcher = strcmp(string(commandId), ...
                "attach_fragment");
            if isFragmentSketcher
                label = kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:FragmentBrowser");
            else
                label = kssolv.ui.util.Localizer.message( ...
                    commandInfo.labelKey);
            end
            if this.usesParameterDialog(commandId)
                label = this.dialogLabel(label);
            end
            item = ListItem( ...
                label, ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.icon( ...
                commandId, 24));
            item.Tag = "ModelingCommand_" + string(commandId);
            if isFragmentSketcher
                item.Description = ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:FragmentBrowserTooltip");
            else
                item.Description = ...
                    kssolv.ui.util.Localizer.message( ...
                    commandInfo.tooltipKey);
            end
            item.Enabled = ...
                kssolv.modeling.CommandExecutor.supports(commandId);
            if item.Enabled
                if isFragmentSketcher
                    addlistener(item, "ItemPushed", ...
                        @(~, ~)this.runUiAction( ...
                        @()this.openFragmentBrowser()));
                else
                    addlistener(item, "ItemPushed", ...
                        @(~, ~)this.executeCommand(commandId));
                end
            end
            this.Items(char(commandId)) = item;
        end

        function popup = createDefectsAlloysPopup(this)
            import matlab.ui.internal.toolstrip.*

            popup = PopupList();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:PointDefectsGroup")));
            defectTypePopup = PopupList();
            defectTypePopup.add(this.createPresetItem( ...
                "create_point_defects", "Vacancy", ...
                struct("defectType", "vacancy"), false));
            defectTypePopup.add(this.createPresetItem( ...
                "create_point_defects", "Substitution", ...
                struct("defectType", "substitution"), false));
            defectTypePopup.add(this.createPresetItem( ...
                "create_point_defects", "Interstitial", ...
                struct("defectType", "interstitial"), false));
            defectTypePopup.add(this.createPresetItem( ...
                "create_point_defects", "Antisite", ...
                struct("defectType", "antisite"), false));
            createDefectItem = ...
                this.createCommandPopupItem("create_point_defects");
            createDefectItem.Popup = defectTypePopup;
            popup.add(createDefectItem);
            popup.add(this.createCommandItem("enumerate_point_defects"));
            popup.addSeparator();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:AlloyGroup")));
            popup.add(this.createCommandItem("generate_sqs_model"));
        end

        function item = createCommandPopupItem(this, commandId)
            import matlab.ui.internal.toolstrip.ListItemWithPopup

            commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
            item = ListItemWithPopup( ...
                kssolv.ui.util.Localizer.message(commandInfo.labelKey), ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    icon(commandId, 24));
            item.Tag = "ModelingCommand_" + string(commandId);
            item.Description = ...
                kssolv.ui.util.Localizer.message(commandInfo.tooltipKey);
            item.Enabled = ...
                kssolv.modeling.CommandExecutor.supports(commandId);
            this.Items(char(commandId)) = item;
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
            label = this.dialogLabel( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:" + string(labelKey)));
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
            item.Enabled = ...
                kssolv.modeling.CommandExecutor.supports(commandId);
            if item.Enabled
                addlistener(item, "ItemPushed", ...
                    @(~, ~)this.executeCommand(commandId, preset));
            end
            this.PresetItems{end+1} = struct( ...
                "item", item, "commandId", string(commandId));
        end

        function label = dialogLabel(~, label)
            label = string(label);
            if ~endsWith(label, "...")
                label = label + "...";
            end
        end

        function value = usesParameterDialog(~, commandId)
            value = ~any(string(commandId) == ["wigner_seitz_cell", "make_p1"]);
        end

        function syncVisibility(this)
            if this.IsShuttingDown
                return
            end
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
            if this.IsShuttingDown
                return
            end
            display = this.Registry.getCurrentDisplay();
            requestedProfile = this.profileForDisplay(display);
            profileChanged = requestedProfile ~= this.Profile;
            this.rebuildProfile(requestedProfile);
            if ~isempty(this.CurrentDisplay) && ...
                    isvalid(this.CurrentDisplay) && ...
                    isequal(this.CurrentDisplay, display)
                this.refreshCommandAvailability();
                if profileChanged
                    this.refreshSelectionSets();
                end
                this.refreshHistoryButtons();
                return
            end
            this.clearDisplayListeners();
            this.CurrentDisplay = display;
            if ~isempty(display) && isvalid(display)
                this.DisplayListeners = {
                    addlistener(display, "HistoryChanged", ...
                    @(~, ~)this.refreshDocumentState())
                    addlistener(display, "SelectionChanged", ...
                    @(~, ~)this.refreshSelectionSets())
                    };
            end
            this.refreshCommandAvailability();
            this.refreshSelectionSets();
            this.refreshHistoryButtons();
        end

        function profile = profileForDisplay(this, display)
            profile = this.Profile;
            if isempty(display) || ~isvalid(display)
                return
            end
            if isa(display.getModel(), ...
                    "kssolv.analysis.matgenlab.core.IMolecule")
                profile = "molecule";
            else
                profile = "crystal";
            end
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

        function executeCommand(this, commandId, preset, promptForParameters)
            if nargin < 3
                preset = struct();
            end
            if nargin < 4
                promptForParameters = true;
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
                if this.usesParameterDialog(commandId) && ...
                        promptForParameters
                    [parameters, cancelled] = ...
                        kssolv.ui.features.modeling.ParameterDialog.prompt( ...
                        commandInfo, display, preset, appContainer);
                    if cancelled
                        this.updateStatus("");
                        return
                    end
                elseif this.usesParameterDialog(commandId)
                    parameters = preset;
                else
                    parameters = struct();
                end
                parameters = ...
                    kssolv.ui.features.modeling.ModelInputResolver.enrich( ...
                    commandId, parameters);
                capability = kssolv.modeling.contracts.CommandCapability. ...
                    forCommand(commandId);
                if capability.resultKind == "model"
                    transaction = display.previewModelingCommand( ...
                        commandId, parameters);
                    result = display.commitModelingTransaction( ...
                        transaction, commandLabel);
                else
                    result = kssolv.modeling.CommandExecutor.execute( ...
                        display.getModel(), commandId, parameters);
                end
                if isfield(result, "models") && ~isempty(result.models)
                    kssolv.ui.features.modeling.DerivedStructureService.publish( ...
                        result.models, result.labels);
                    kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                        commandId, display.getModel(), result, ...
                        kssolv.ui.util.Localizer.message( ...
                        commandInfo.labelKey), appContainer);
                elseif any(commandId == ...
                        ["build_from_spacegroup", "build_slab", ...
                        "stack_heterostructure"]) && ...
                        isfield(result, "analysis")
                    kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                        commandId, display.getModel(), result, ...
                        commandLabel, appContainer);
                elseif ~result.changed
                    presentationArguments = {appContainer};
                    if commandId == "locate_adsorbate"
                        presentationArguments = {appContainer, display, ...
                            parameters.adsorbateModel};
                    end
                    kssolv.ui.features.modeling.AnalysisResultPresenter.present( ...
                        commandId, display.getModel(), result, ...
                        kssolv.ui.util.Localizer.message( ...
                        commandInfo.labelKey), presentationArguments{:});
                end
                if isfield(result, "changed") && result.changed && ...
                        commandId == "attach_fragment"
                    display.resetViewerCamera();
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
                    "Select an open crystal or molecule document before modeling.");
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

        function reset(this)
            display = this.requireCurrentDisplay();
            display.reset();
            this.refreshHistoryButtons();
        end

        function startRecording(this)
            display=this.requireCurrentDisplay();
            display.startOperationRecording();
            this.refreshHistoryButtons();
            this.updateStatus(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RecordingStarted"));
        end

        function saveRecording(this)
            display=this.requireCurrentDisplay();
            recipe=display.stopOperationRecording();
            name="recording-"+string(datetime("now",Format="yyyyMMdd-HHmmss"));
            path=kssolv.modeling.provenance.RecipeLibrary.save(name,recipe);
            this.refreshHistoryButtons();
            this.updateStatus(sprintf(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RecordingSaved"),path));
        end

        function refreshHistoryButtons(this)
            if this.IsShuttingDown
                return
            end
            display = this.Registry.getCurrentDisplay();
            if this.Executing || isempty(display)
                this.UndoButton.Enabled = false;
                this.RedoButton.Enabled = false;
                this.ResetButton.Enabled = false;
                this.RecorderStartButton.Enabled=false;
                this.RecorderSaveButton.Enabled=false;
            else
                this.UndoButton.Enabled = display.canUndo();
                this.RedoButton.Enabled = display.canRedo();
                this.ResetButton.Enabled = display.canReset();
                this.RecorderStartButton.Enabled= ...
                    ~display.isOperationRecording();
                this.RecorderSaveButton.Enabled= ...
                    display.isOperationRecording();
            end
        end

        function refreshDocumentState(this)
            if this.IsShuttingDown
                return
            end
            this.refreshCommandAvailability();
            this.refreshSelectionSets();
            this.refreshHistoryButtons();
        end

        function refreshSelectionSets(this)
            if this.IsShuttingDown
                return
            end
            import matlab.ui.internal.toolstrip.*
            display = this.Registry.getCurrentDisplay();
            popup = PopupList();
            popup.add(PopupListHeader( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SelectionSets")));
            saveItem = ListItem(this.dialogLabel( ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SaveSelectionSet")));
            saveItem.Tag = "ModelingSaveSelectionSet";
            saveItem.Enabled = ~this.Executing && ...
                ~isempty(display) && isvalid(display) && ...
                ~isempty(display.getSelectedSiteIndices());
            if saveItem.Enabled
                addlistener(saveItem, "ItemPushed", ...
                    @(~, ~)this.saveSelectionSet());
            end
            popup.add(saveItem);

            hasDisplay = ~isempty(display) && isvalid(display);
            if hasDisplay
                sets = display.getSelectionSets();
                if ~isempty(sets)
                    popup.addSeparator();
                    popup.add(PopupListHeader( ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:RecallSelectionSet")));
                    for setIndex = 1:numel(sets)
                        setName = string(sets(setIndex).name);
                        label = sprintf("%s (%d/%d)", setName, ...
                            sets(setIndex).resolvedCount, ...
                            sets(setIndex).siteCount);
                        item = ListItem(label);
                        item.Tag = "ModelingSelectionSet_" + ...
                            matlab.lang.makeValidName(setName);
                        item.Enabled = ~this.Executing && ...
                            sets(setIndex).resolvedCount > 0;
                        if item.Enabled
                            addlistener(item, "ItemPushed", ...
                                @(~, ~)this.recallSelectionSet(setName));
                        end
                        popup.add(item);
                    end
                end
            end
            this.SelectionSetButton.Popup = popup;
            this.SelectionSetButton.Enabled = ...
                ~this.Executing && hasDisplay;
        end

        function saveSelectionSet(this)
            display = this.requireCurrentDisplay();
            count = numel(display.getSelectionSets()) + 1;
            [name, cancelled] = ...
                kssolv.ui.features.modeling.SelectionSetNameDialog.prompt( ...
                sprintf(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:DefaultSelectionSetName"),count));
            if cancelled, return, end
            try
                display.saveSelectionSet(name);
                this.refreshDocumentState();
            catch exception
                this.showModelingError(exception);
            end
        end

        function recallSelectionSet(this, name)
            display = this.requireCurrentDisplay();
            try
                [~, missing] = display.recallSelectionSet(name);
                if ~isempty(missing)
                    this.updateStatus(sprintf( ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:SelectionSitesMissing"), ...
                        numel(missing)));
                end
            catch exception
                this.showModelingError(exception);
            end
        end

        function showModelingError(this, exception)
            if this.IsShuttingDown
                return
            end
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

        function runUiAction(this,action)
            if this.IsShuttingDown
                return
            end
            try
                action();
            catch exception
                this.showModelingError(exception);
            end
        end

        function setExecuting(this, value)
            this.Executing = logical(value);
            if this.IsShuttingDown
                return
            end
            this.refreshCommandAvailability();
            this.refreshSelectionSets();
            this.refreshHistoryButtons();
        end

        function refreshCommandAvailability(this)
            if this.IsShuttingDown
                return
            end
            display = this.Registry.getCurrentDisplay();
            keys = this.Items.keys;
            for index = 1:numel(keys)
                control = this.Items(keys{index});
                if isempty(control) || ~isvalid(control)
                    continue
                end
                if this.Executing
                    control.Enabled = false;
                    continue
                end
                commandId = string(keys{index});
                commandInfo = kssolv.modeling.CommandCatalog.find(commandId);
                baseDescription = kssolv.ui.util.Localizer.message( ...
                    commandInfo.tooltipKey);
                if isempty(display) || ~isvalid(display)
                    control.Enabled = false;
                    control.Description = baseDescription;
                else
                    [supported, reason] = ...
                        kssolv.modeling.CommandExecutor.supportsForModel( ...
                        commandId, display.getModel());
                    control.Enabled = supported;
                    if supported
                        control.Description = baseDescription;
                    else
                        control.Description = string(baseDescription) + newline + ...
                            string(reason);
                    end
                end
            end
            for presetIndex = 1:numel(this.PresetItems)
                entry = this.PresetItems{presetIndex};
                if isempty(entry.item) || ~isvalid(entry.item)
                    continue
                end
                if this.Executing || isempty(display) || ~isvalid(display)
                    entry.item.Enabled = false;
                else
                    entry.item.Enabled = ...
                        kssolv.modeling.CommandExecutor.supportsForModel( ...
                            entry.commandId, display.getModel());
                end
            end
            if ~isempty(this.FragmentBrowserButton) && ...
                    isvalid(this.FragmentBrowserButton)
                isMolecule = ~isempty(display) && isvalid(display) && ...
                    isa(display.getModel(), ...
                    "kssolv.analysis.matgenlab.core.IMolecule");
                this.FragmentBrowserButton.Enabled = ...
                    ~this.Executing && isMolecule;
            end
        end

        function openFragmentBrowser(this)
            display = this.requireCurrentDisplay();
            indices = display.getSelectedSiteIndices();
            if isempty(indices)
                error("KSSOLV:Modeling:FragmentSelection", ...
                    "Select the host atoms required by the fragment port.");
            end
            this.FragmentBrowserHostIndices = reshape(double(indices), 1, []);
            if ~isempty(this.FragmentBrowserWindow) && ...
                    isvalid(this.FragmentBrowserWindow)
                this.FragmentBrowserWindow.Figure.Visible = "on";
                figure(this.FragmentBrowserWindow.Figure);
                return
            end
            this.FragmentBrowserWindow = ...
                kssolv.ui.features.modeling.FragmentBrowser( ...
                @(name, portId, head)this.attachFragmentFromBrowser( ...
                name, portId, head));
        end

        function attachFragmentFromBrowser(this, name, portId, head)
            indices = this.FragmentBrowserHostIndices;
            if isempty(indices)
                error("KSSOLV:Modeling:FragmentSelection", ...
                    "Select the host atoms required by the fragment port.");
            end
            this.executeCommand("attach_fragment", struct( ...
                "indices", indices, ...
                "fragmentName", name, ...
                "portId", portId, ...
                "fragmentIndex", head), false);
        end

        function updateStatus(~, text)
            footer = kssolv.ui.util.DataStorage.getData("FooterBar");
            if ~isempty(footer) && isvalid(footer)
                footer.setLabelText(string(text));
            end
        end
    end
end
