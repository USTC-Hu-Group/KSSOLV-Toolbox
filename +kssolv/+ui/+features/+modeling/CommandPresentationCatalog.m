classdef CommandPresentationCatalog
    %COMMANDPRESENTATIONCATALOG Modeling toolstrip presentation metadata.
    %
    % Keep visual metadata out of kssolv.modeling.CommandCatalog so the
    % command layer remains usable without a desktop. Every Modeling
    % control uses a project-owned semantic SVG master through a vector data
    % URL, keeping the complete tab visually coherent and high-DPI safe.
    % PNG assets remain available as release-safe fallbacks.

    methods (Static)
        function icon = icon(commandId, size)
            arguments
                commandId
                size (1,1) double {mustBeMember(size, [16, 24])} = 16
            end
            name = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                iconName(commandId);
            icon = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                projectIcon(name, size);
        end

        function name = iconName(commandId)
            commandId = string(commandId);
            ids = kssolv.ui.features.modeling.CommandPresentationCatalog.iconIds();
            names = kssolv.ui.features.modeling.CommandPresentationCatalog.iconNames();
            position = find(ids == commandId, 1);
            if isempty(position)
                error("KSSOLV:Modeling:MissingPresentation", ...
                    "No Modeling icon is registered for command '%s'.", ...
                    commandId);
            end
            name = names(position);
        end

        function path = commandIconPath(commandId, size)
            arguments
                commandId
                size (1,1) double {mustBeMember(size, [16, 24])} = 16
            end
            name = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.iconName( ...
                commandId);
            path = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.assetPath( ...
                name, size);
        end

        function validate()
            commandIds = sort( ...
                kssolv.modeling.CommandCatalog.commandIds());
            presentationIds = sort( ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.iconIds());
            if ~isequal(commandIds, presentationIds)
                missing = setdiff(commandIds, presentationIds);
                extra = setdiff(presentationIds, commandIds);
                error("KSSOLV:Modeling:PresentationCatalogMismatch", ...
                    "Modeling presentation mismatch. Missing: %s. Extra: %s.", ...
                    join(missing, ", "), join(extra, ", "));
            end
            assetIds = [
                presentationIds
                "category_" + ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    categoryIds()
                "history_" + ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    utilityIds()
                ];
            for size = [16, 24]
                for index = 1:numel(assetIds)
                    path = ...
                        kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                        assetPath(assetIds(index), size);
                    if ~isfile(path)
                        error("KSSOLV:Modeling:MissingIconAsset", ...
                            "Modeling icon asset is missing: %s", path);
                    end
                    sourcePath = ...
                        kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                        sourceAssetPath(assetIds(index), size);
                    if ~isfile(sourcePath)
                        error("KSSOLV:Modeling:MissingIconSource", ...
                            "Modeling icon SVG source is missing: %s", ...
                            sourcePath);
                    end
                end
            end
            for index = 1:numel(assetIds)
                masterPath = ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    sourceAssetPath(assetIds(index), 64);
                if ~isfile(masterPath)
                    error("KSSOLV:Modeling:MissingIconSource", ...
                        "Modeling SVG master is missing: %s", ...
                        masterPath);
                end
            end
        end

        function icon = projectIcon(assetId, size)
            arguments
                assetId
                size (1,1) double {mustBeMember(size, [16, 24])}
            end
            import matlab.ui.internal.toolstrip.Icon

            masterPath = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                sourceAssetPath(assetId, 64);
            icon = Icon(char( ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                svgDataUrl(masterPath, size)));
        end

        function dataUrl = svgDataUrl(path, size)
            arguments
                path
                size (1,1) double {mustBeMember(size, [16, 24])}
            end
            markup = string(fileread(path));
            markup = replace(markup, 'width="64"', ...
                'width="' + string(size) + '"');
            markup = replace(markup, 'height="64"', ...
                'height="' + string(size) + '"');
            encoded = matlab.net.base64encode( ...
                unicode2native(char(markup), 'UTF-8'));
            dataUrl = "data:image/svg+xml;base64," + string(encoded);
        end

        function ids = iconIds()
            ids = [
                "add_atom"
                "center_atoms"
                "delete_atoms"
                "merge_atoms"
                "fix_atoms"
                "mirror_atoms"
                "move_atoms"
                "perturb_atoms"
                "sort_atoms"
                "rotate_atoms"
                "substitute_atoms"
                "translate_atoms"
                "apply_strain"
                "edit_lattice"
                "mirror_lattice"
                "rotate_lattice"
                "swap_axes"
                "build_supercell"
                "redefine_lattice"
                "orthogonalize_cell"
                "strain_structure"
                "perturb_structure"
                "create_point_defects"
                "generate_sqs_model"
                "roll_nanotube"
                "cut_nanoribbon"
                "cut_nanowire"
                "quantum_dot_void"
                "build_slab"
                "add_vacuum"
                "insert_structure"
                "stack_heterostructure"
                "twist_moire"
                "interpolate_neb"
                "find_adsorption_sites"
                "passivate_surface"
                "add_solvent_layer"
                "find_symmetry"
                "primitive_cell"
                "conventional_cell"
                "wigner_seitz_cell"
                ];
        end

        function names = iconNames()
            names = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog.iconIds();
        end

        function icon = categoryIcon(categoryId, size)
            arguments
                categoryId
                size (1,1) double {mustBeMember(size, [16, 24])} = 24
            end
            categoryId = string(categoryId);
            if ~any( ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    categoryIds() == categoryId)
                error("KSSOLV:Modeling:MissingPresentation", ...
                    "No Modeling category icon is registered for '%s'.", ...
                    categoryId);
            end
            icon = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                projectIcon("category_" + categoryId, size);
        end

        function icon = utilityIcon(name, size)
            arguments
                name
                size (1,1) double {mustBeMember(size, [16, 24])} = 16
            end
            name = string(name);
            if ~any( ...
                    kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                    utilityIds() == name)
                error("KSSOLV:Modeling:MissingPresentation", ...
                    "No Modeling utility icon is registered for '%s'.", ...
                    name);
            end
            icon = ...
                kssolv.ui.features.modeling.CommandPresentationCatalog. ...
                projectIcon("history_" + name, size);
        end

        function ids = categoryIds()
            ids = [
                "atomic_editor"
                "lattice_editor"
                "supercell_lattice"
                "defects_alloys"
                "nanostructures"
                "surface_modeling"
                "interface_modeling"
                "symmetry_tools"
                ];
        end

        function ids = utilityIds()
            ids = ["undo"; "redo"];
        end

        function path = assetPath(assetId, size)
            arguments
                assetId
                size (1,1) double {mustBeMember(size, [16, 24])}
            end
            assetId = string(assetId);
            if ~isscalar(assetId) || assetId == "" || ...
                    ~isempty(regexp(assetId, "[/\\]", "once"))
                error("KSSOLV:Modeling:IconAssetId", ...
                    "A simple Modeling icon asset identifier is required.");
            end
            path = fullfile( ...
                KSSOLV_Toolbox.UIResourcesDirectory, "icons", ...
                "modeling", size + "x" + size, assetId + ".png");
        end

        function path = sourceAssetPath(assetId, size)
            arguments
                assetId
                size (1,1) double {mustBeMember(size, [16, 24, 64])}
            end
            assetId = string(assetId);
            if ~isscalar(assetId) || assetId == "" || ...
                    ~isempty(regexp(assetId, "[/\\]", "once"))
                error("KSSOLV:Modeling:IconAssetId", ...
                    "A simple Modeling icon asset identifier is required.");
            end
            path = fullfile( ...
                KSSOLV_Toolbox.UIResourcesDirectory, "icons", ...
                "modeling", size + "x" + size, assetId + ".svg");
        end
    end

end
