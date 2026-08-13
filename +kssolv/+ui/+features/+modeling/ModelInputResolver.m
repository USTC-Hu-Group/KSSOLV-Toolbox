classdef ModelInputResolver
    %MODELINPUTRESOLVER Resolve project structure names to model copies.

    methods (Static)
        function parameters = enrich(commandId, parameters)
            commandId = string(commandId);
            switch commandId
                case {"insert_structure", "stack_heterostructure", ...
                        "twist_moire"}
                    if ~isfield(parameters, "otherModel")
                        parameters.otherModel = ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolve(parameters.otherStructureName);
                    end
                case "interpolate_neb"
                    if ~isfield(parameters, "endModel")
                        parameters.endModel = ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolve(parameters.endStructureName);
                    end
                case "add_solvent_layer"
                    if ~isfield(parameters, "solventModel")
                        parameters.solventModel = ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolve(parameters.solventStructureName);
                    end
                case {"place_adsorbate", "locate_adsorbate"}
                    if ~isfield(parameters,"adsorbateModel")
                        if isfield(parameters, "adsorbateStructureNames")
                            reference = parameters.adsorbateStructureNames;
                        else
                            reference = parameters.adsorbateStructureName;
                        end
                        offsets = zeros(0, 3);
                        if isfield(parameters, "adsorbateComponentOffsets")
                            offsets = double( ...
                                parameters.adsorbateComponentOffsets);
                        end
                        parameters.adsorbateModel = ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolveAdsorbate(reference, offsets);
                    end
                case "pack_mixture"
                    if ~isfield(parameters,"otherComponents")
                        parameters.otherComponents = { ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolve(parameters.mixtureStructureName)};
                    end
                case {"pack_into_existing_box","pack_around_nanoparticle"}
                    if ~isfield(parameters,"otherComponents")
                        parameters.otherComponents={ ...
                            kssolv.ui.features.modeling.ModelInputResolver. ...
                            resolve(parameters.componentStructureName)};
                    end
            end
        end

        function model = resolve(nameOrId)
            nameOrId = string(nameOrId);
            if nameOrId == ""
                error("KSSOLV:Modeling:StructureReference", ...
                    "A project structure name or identifier is required.");
            end
            project = kssolv.ui.util.DataStorage.getData("Project");
            if isempty(project) || ~isvalid(project)
                error("KSSOLV:Modeling:ProjectRequired", ...
                    "Open a project containing the referenced structure.");
            end
            item = project.findChildrenItem(nameOrId);
            if isempty(item) || string(item.type) ~= "Structure" || ...
                    isempty(item.data) || ...
                    ~isprop(item.data, "MatgenlabObject") || ...
                    isempty(item.data.MatgenlabObject)
                error("KSSOLV:Modeling:StructureNotFound", ...
                    "Project structure '%s' was not found.", nameOrId);
            end
            model = item.data.MatgenlabObject.copy();
        end

        function model = resolveAdsorbate(namesOrIds, offsets)
            arguments
                namesOrIds
                offsets double = zeros(0, 3)
            end
            values = reshape(string(namesOrIds), 1, []);
            if isscalar(values)
                values = strip(split(values, [",", ";"]));
                values = reshape(values(values ~= ""), 1, []);
            end
            if isempty(values)
                error("KSSOLV:Modeling:StructureReference", ...
                    "At least one project adsorbate reference is required.");
            end
            components = arrayfun(@(value) ...
                kssolv.ui.features.modeling.ModelInputResolver. ...
                resolve(value), values, "UniformOutput", false);
            if isscalar(components)
                model = components{1};
                return
            end
            model = kssolv.modeling.adsorption.AdsorbateAssembly. ...
                combine(components, Offsets = offsets);
        end

        function value = suggestOther(display)
            value = "";
            values = ...
                kssolv.ui.features.modeling.ModelInputResolver.available(display);
            if ~isempty(values)
                value = values(1);
            end
        end

        function values = available(display)
            values = strings(0, 1);
            project = kssolv.ui.util.DataStorage.getData("Project");
            if isempty(project) || ~isvalid(project)
                return
            end
            folder = project.findChildrenItem("Structure");
            if isempty(folder)
                return
            end
            for index = 1:numel(folder.children)
                item = folder.children{index};
                if string(item.name) ~= string(display.tag) && ...
                        string(item.type) == "Structure"
                    values(end + 1, 1) = string(item.label); %#ok<AGROW>
                end
            end
            values = unique(values, "stable");
        end
    end
end
