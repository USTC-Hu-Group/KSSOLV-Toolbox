classdef DerivedStructureService
    %DERIVEDSTRUCTURESERVICE Publish multi-model results into the project.

    methods (Static)
        function items = publish(models, labels)
            if ~iscell(models)
                models = num2cell(models);
            end
            if nargin < 2 || isempty(labels)
                labels = "Modeled structure " + string(1:numel(models));
            end
            labels = reshape(string(labels), 1, []);
            if numel(labels) ~= numel(models)
                error("KSSOLV:Modeling:DerivedLabels", ...
                    "A label is required for every modeled structure.");
            end
            project = kssolv.ui.util.DataStorage.getData("Project");
            hasProject = ~isempty(project) && isvalid(project);
            if hasProject
                folder = project.findChildrenItem("Structure");
            else
                folder = [];
            end
            items = cell(1, numel(models));
            for index = 1:numel(models)
                model = models{index};
                if hasProject && ~isempty(folder)
                    item = kssolv.services.filemanager.Structure( ...
                        labels(index));
                    item.data = ...
                        kssolv.services.fileparser. ...
                        ModeledStructureData(model, labels(index));
                    folder.addChildrenItem(item);
                    tag = string(item.name);
                    items{index} = item;
                else
                    tag = "";
                end
                display = ...
                    kssolv.ui.components.figuredocument. ...
                    MoleculeDisplay(model, "", tag);
                display.Display();
            end
            if hasProject
                project.isDirty = true;
                browser = kssolv.ui.util.DataStorage.getData( ...
                    "ProjectBrowser");
                if ~isempty(browser) && isvalid(browser)
                    browser.reBuildUI();
                end
            end
        end
    end
end
