classdef OnlineReconnectState
    % Rebuild browser views without restarting the Runtime or discarding data.
    methods (Static)
        function state = capture(app)
            import kssolv.ui.util.DataStorage
            registry = DataStorage.getData('ModelingSessionRegistry');
            if ~isempty(registry) && isvalid(registry)
                registry.saveAllChangesToProject();
            end
            state.Project = DataStorage.getData('Project');
            state.Filename = DataStorage.getData('ProjectFilename');
            state.Commands = DataStorage.getData('CommandWindow').captureBrowserSession();
            container = app.getAppContainer();
            % The cached map is essential here: public getDocuments waits for
            % acknowledgements from the client which has just disconnected.
            warnings = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnings));
            native = struct(container);
            documents = native.DocumentMap.values();
            state.Documents = strings(0);
            for index = 1:numel(documents)
                document = documents{index};
                if isvalid(document) && document.Visible
                    state.Documents(end+1) = document.Tag;
                end
            end
            state.Selected = container.LastSelectedDocument;
            state.RightCollapsed = container.RightCollapsed;
            state.BottomCollapsed = container.BottomCollapsed;
            % Task widgets belong to the old figures. Their private options
            % remain in the model and setupUI recreates the widgets on demand.
            folder = state.Project.findChildrenItem('Workflow');
            for index = 1:numel(folder.children)
                workflow = folder.children{index};
                if ~isempty(workflow.graph)
                    nodes = workflow.graph.Nodes.values();
                    for node = 1:numel(nodes)
                        nodes{node}.task.taskUICreated = false;
                    end
                end
            end
        end

        function app = create(state)
            import kssolv.ui.util.DataStorage
            oldCommands = DataStorage.getData('CommandWindow');
            if ~isempty(oldCommands) && isvalid(oldCommands)
                delete(oldCommands);
            end
            DataStorage.setData('Project', state.Project);
            DataStorage.setData('ProjectFilename', state.Filename);
            app = kssolv.KSSOLVToolbox();
            try
                app.HostInBrowser = true;
                DataStorage.setData('KSSOLVToolbox', app);
                app.show();
                DataStorage.getData('CommandWindow').restoreBrowserSession(state.Commands);
            catch exception
                delete(app);
                rethrow(exception)
            end
        end

        function restored = restoreWhenReady(app, state)
            import kssolv.ui.util.DataStorage
            container = app.getAppContainer();
            browser = DataStorage.getData('ProjectBrowser');
            restored = false;
            if kssolv.ui.browser.BrowserReconnectMonitor.pollCurrent(), return, end
            if container.State ~= matlab.ui.container.internal.appcontainer.AppState.RUNNING || ...
                    ~browser.IsClientReady
                return
            end
            for tag = state.Documents
                if kssolv.ui.browser.BrowserReconnectMonitor.pollCurrent(), return, end
                item = state.Project.findChildrenItem(tag);
                if isempty(item), continue, end
                switch class(item)
                    case 'kssolv.services.filemanager.Workflow'
                        item.showWorkflowDisplay();
                    case 'kssolv.services.filemanager.Structure'
                        item.showMoleculeDisplay();
                    case 'kssolv.services.filemanager.Volume'
                        item.showVolumeDisplay();
                    otherwise
                        if strcmp(item.type, 'Plot')
                            item.data.replot();
                            plot = kssolv.ui.components.figuredocument.DataPlot(item.data, item.name);
                            plot.Display(item.label);
                        end
                end
            end
            if kssolv.ui.browser.BrowserReconnectMonitor.pollCurrent(), return, end
            if isstruct(state.Selected) && ...
                    isfield(state.Selected, 'documentGroupTag') && ...
                    isfield(state.Selected, 'documentTag')
                document = container.getDocument(state.Selected.documentGroupTag, ...
                    state.Selected.documentTag);
                if ~isempty(document), document.Selected = true; end
            end
            container.RightCollapsed = state.RightCollapsed;
            container.BottomCollapsed = state.BottomCollapsed;
            restored = true;
        end
    end
end
