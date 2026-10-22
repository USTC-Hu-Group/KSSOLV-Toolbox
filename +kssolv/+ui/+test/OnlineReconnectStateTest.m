classdef OnlineReconnectStateTest < matlab.unittest.TestCase
    methods (Test)
        function preservesModelWorkspaceAndUnsavedState(testCase)
            import kssolv.ui.util.DataStorage
            keys = {'Project','ProjectFilename','CommandWindow','ModelingSessionRegistry'};
            previous = cellfun(@(key) DataStorage.getData(key), keys, UniformOutput=false);
            cleanup = onCleanup(@() restore(keys, previous));
            project = kssolv.services.filemanager.Project();
            project.isDirty = true;
            commands = struct('Workspace',struct('marker',20261018),'ChatBot',[], ...
                'RemoteExecutionEnabled',false);
            commands.Transcript = kssolv.ui.util.CommandTranscript();
            commands.Transcript.recordCommand('marker=20261018');
            commands.Transcript.append('result','20261018');
            DataStorage.setData('Project', project);
            DataStorage.setData('ProjectFilename', '/data/work/unsaved.ks');
            DataStorage.setData('CommandWindow',struct('captureBrowserSession',@() commands));
            DataStorage.setData('ModelingSessionRegistry', []);
            container = struct('DocumentMap',containers.Map(), ...
                'LastSelectedDocument',struct(),'RightCollapsed',true,'BottomCollapsed',false);
            app = struct('getAppContainer',@() container);
            state = kssolv.ui.browser.OnlineReconnectState.capture(app);
            testCase.verifyEqual(state.Project,project);
            testCase.verifyTrue(project.isDirty);
            testCase.verifyEqual(state.Filename,'/data/work/unsaved.ks');
            testCase.verifyEqual(state.Commands.Workspace.marker,20261018);
            transcript=state.Commands.Transcript.snapshot();
            testCase.verifyEqual(transcript.Commands,{'marker=20261018'});
            testCase.verifyEqual(transcript.Records{2}.Data,'20261018');
            testCase.verifyEmpty(state.Documents);
            testCase.verifyTrue(state.RightCollapsed);
            testCase.verifyFalse(state.BottomCollapsed);
        end

        function waitsForTheClientBeforeOpeningDocuments(testCase)
            import kssolv.ui.util.DataStorage
            previous = DataStorage.getData('ProjectBrowser');
            cleanup = onCleanup(@() DataStorage.setData('ProjectBrowser',previous));
            DataStorage.setData('ProjectBrowser',struct('IsClientReady',false));
            container = struct('State',matlab.ui.container.internal.appcontainer.AppState.INITIALIZING);
            app = struct('getAppContainer',@() container);
            testCase.verifyFalse(kssolv.ui.browser.OnlineReconnectState.restoreWhenReady(app,struct()));
            container.State = matlab.ui.container.internal.appcontainer.AppState.RUNNING;
            app.getAppContainer = @() container;
            testCase.verifyFalse(kssolv.ui.browser.OnlineReconnectState.restoreWhenReady(app,struct()));
        end
    end
end

function restore(keys, values)
for index = 1:numel(keys)
    kssolv.ui.util.DataStorage.setData(keys{index},values{index});
end
end
