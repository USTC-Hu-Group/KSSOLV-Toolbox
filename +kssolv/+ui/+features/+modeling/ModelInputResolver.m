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
