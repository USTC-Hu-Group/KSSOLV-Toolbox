classdef MoleculeDisplayStartupTest < matlab.unittest.TestCase
    methods (Test)
        function opensDocumentBeforeStartingViewerAndEventuallyRenders(testCase)
            app = createApp(testCase);
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            display = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                model.to("", "json"), "json");
            testCase.addTeardown(@()delete(display));
            started = tic;
            display.Display();
            fprintf('Document open returned in %.1f ms\n', toc(started) * 1000);
            html = findall(display.Document.Figure, '-isa', 'matlab.ui.control.HTML');
            testCase.assertNumElements(html, 1);
            testCase.verifyEmpty(html.HTMLSource);
            testCase.verifyEmpty(display.getModel());
            testCase.verifyNotEmpty(app.getDocument('Structure', display.Document.Tag));
            original = html.HTMLEventReceivedFcn;
            rendered = false;
            completed = false;
            frames = {};
            errors = strings(1, 0);
            html.HTMLEventReceivedFcn = @receive;
            started = tic;
            while ~completed && toc(started) < 30
                drawnow;
                pause(0.01);
            end
            testCase.verifyTrue(rendered, join(errors, newline));
            testCase.verifyTrue(completed, join(errors, newline));
            testCase.assertNumElements(frames, 2);
            testCase.verifyTrue(startsWith(string(frames{1}.requestId), "initial-"));
            testCase.verifyGreaterThan(frames{1}.atomCount, 0);
            testCase.verifyEqual(frames{1}.bondCount, 0);
            testCase.verifyEmpty(errors);
            testCase.verifyEqual(display.getModel().frac_coords, model.frac_coords);
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal Viewer initialization'));
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal initial connectivity'));

            function receive(src, event)
                original(src, event);
                if string(event.HTMLEventName) == "viewer:sceneRendered"
                    rendered = true;
                    data = event.HTMLEventData;
                    if ischar(data) || isstring(data), data = jsondecode(data); end
                    frames{end + 1} = data;
                    completed = ~startsWith(string(data.requestId), "initial-");
                elseif string(event.HTMLEventName) == "viewer:error"
                    errors(end + 1) = string(jsonencode(event.HTMLEventData));
                end
            end
        end

        function closingAfterFirstFrameCancelsConnectivity(testCase)
            createApp(testCase);
            model = kssolv.analysis.matgenlab.core.Structure(eye(3)*4, {'Si'}, [0 0 0]);
            display = kssolv.ui.components.figuredocument.MoleculeDisplay(model);
            testCase.addTeardown(@()delete(display));
            display.Display();
            html = findall(display.Document.Figure, '-isa', 'matlab.ui.control.HTML');
            original = html.HTMLEventReceivedFcn;
            stopped = false;
            html.HTMLEventReceivedFcn = @receive;
            started = tic;
            while ~stopped && toc(started) < 30, pause(.01); end
            testCase.verifyTrue(stopped);
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal initial connectivity'));

            function receive(src, event)
                original(src, event);
                if string(event.HTMLEventName) == "viewer:sceneRendered"
                    display.prepareForShutdown();
                    stopped = true;
                end
            end
        end

        function closingBeforeInitializationCancelsParsing(testCase)
            createApp(testCase);
            display = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                "deliberately invalid input", "cif");
            testCase.addTeardown(@()delete(display));
            display.Display();
            display.prepareForShutdown();
            pause(0.05);
            drawnow;
            testCase.verifyEmpty(display.getModel());
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal Viewer initialization'));
        end

        function selectsExistingDocumentWithoutReadingStructureData(testCase)
            app = createApp(testCase);
            group = matlab.ui.internal.FigureDocumentGroup();
            group.Tag = 'Structure';
            app.add(group);
            item = kssolv.services.filemanager.Structure();
            document = matlab.ui.internal.FigureDocument(struct( ...
                'DocumentGroupTag', 'Structure', 'Tag', char(item.name)));
            app.add(document);
            % The item deliberately has no parser/data object. Reopening an
            % existing document must only select the document.
            testCase.verifyWarningFree(@()item.showMoleculeDisplay());
            testCase.verifyTrue(document.Selected);
        end
    end
end

function app = createApp(testCase)
previous = kssolv.ui.util.DataStorage.getData('AppContainer');
app = matlab.ui.container.internal.AppContainer(struct('Title', 'Viewer Startup Test'));
testCase.addTeardown(@()kssolv.ui.util.DataStorage.setData('AppContainer', previous));
testCase.addTeardown(@()delete(app));
registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
testCase.addTeardown(@()registry.clear());
kssolv.ui.util.DataStorage.setData('AppContainer', app);
app.Visible = true;
drawnow;
end
