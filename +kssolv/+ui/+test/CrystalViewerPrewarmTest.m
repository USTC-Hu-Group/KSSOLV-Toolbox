classdef CrystalViewerPrewarmTest < matlab.unittest.TestCase
    methods (Test)
        function toolboxWarmsInItsExistingSidebarAndDisposesWork(testCase)
            previousProject = kssolv.ui.util.DataStorage.getData('Project');
            previousFilename = kssolv.ui.util.DataStorage.getData('ProjectFilename');
            kssolv.ui.util.DataStorage.setData('Project', kssolv.services.filemanager.Project());
            kssolv.ui.util.DataStorage.setData('ProjectFilename', "");
            testCase.addTeardown(@()kssolv.ui.util.DataStorage.setData('Project', previousProject));
            testCase.addTeardown(@()kssolv.ui.util.DataStorage.setData('ProjectFilename', previousFilename));
            app = kssolv.KSSOLVToolbox();
            testCase.addTeardown(@()deleteIfValid(app));
            app.show();
            prewarm = kssolv.ui.util.DataStorage.getData('CrystalViewerPrewarm');
            testCase.assertClass(prewarm, 'kssolv.ui.util.CrystalViewerPrewarm');
            started = tic;
            while ~prewarm.IsReady && prewarm.LastError == "" && toc(started) < 30
                pause(.01);
            end
            testCase.verifyTrue(prewarm.IsReady, prewarm.LastError);
            registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
            testCase.verifyEqual(registry.count(), 0);
            app.prepareForShutdown();
            delete(app);
            testCase.verifyFalse(isvalid(prewarm));
            testCase.verifyEmpty(kssolv.ui.util.DataStorage.getData('CrystalViewerPrewarm'));
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal Viewer prewarm'));
        end

        function warmsRealWebGLWithoutOpeningADocument(testCase)
            host = uifigure('Visible', 'on', 'Name', 'Crystal Prewarm Test');
            testCase.addTeardown(@()delete(host));
            prewarm = kssolv.ui.util.CrystalViewerPrewarm(host);
            testCase.addTeardown(@()delete(prewarm));
            started = tic;
            while ~prewarm.IsReady && prewarm.LastError == "" && toc(started) < 30
                pause(0.01);
                drawnow;
            end
            testCase.verifyTrue(prewarm.IsReady, prewarm.LastError);
            testCase.verifyEmpty(findall(host, 'Tag', 'KSSOLVCrystalPrewarm'));
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal Viewer prewarm'));
        end

        function shutdownCancelsIdleWork(testCase)
            host = uifigure('Visible', 'off');
            testCase.addTeardown(@()delete(host));
            prewarm = kssolv.ui.util.CrystalViewerPrewarm(host);
            testCase.addTeardown(@()delete(prewarm));
            prewarm.shutdown();
            pause(0.6);
            testCase.verifyFalse(prewarm.IsReady);
            testCase.verifyEmpty(timerfindall('Name', 'KSSOLV Crystal Viewer prewarm'));
            testCase.verifyEmpty(findall(host, 'Tag', 'KSSOLVCrystalPrewarm'));
        end

        function previewsFollowContentAndViewOptions(testCase)
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {'Si'}, [.1 .2 .3]);
            options = struct('algorithm', "CrystalNN", 'cell', "input", 'repeat', [1 1 1]);
            first = kssolv.ui.scene.atomic.AtomicPreviewCache.build(model, options, "first");
            second = kssolv.ui.scene.atomic.AtomicPreviewCache.build(model, options, "second");
            testCase.verifyEqual(second.requestId, "second");
            first.requestId = "second";
            testCase.verifyEqual(first, second);
            changed = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {'Si'}, [.4 .2 .3]);
            updated = kssolv.ui.scene.atomic.AtomicPreviewCache.build(changed, options, "changed");
            testCase.verifyNotEqual(updated.sites.cartesian, second.sites.cartesian);
            options.repeat = [2 1 1];
            repeated = kssolv.ui.scene.atomic.AtomicPreviewCache.build(model, options, "repeat");
            testCase.verifyEqual(repeated.structure.repeat, [2 1 1]);
            testCase.verifyGreaterThan(numel(repeated.atomInstances), numel(second.atomInstances));
            testCase.verifyEmpty(repeated.bondInstances);
            molecule = kssolv.analysis.matgenlab.core.Molecule({'H','H'}, [0 0 0; 0 0 .74]);
            options.algorithm = "Auto";
            molecular = kssolv.ui.scene.atomic.AtomicPreviewCache.build(molecule, options, "molecule");
            testCase.verifyEqual(molecular.kind, "molecule");
            testCase.verifyEmpty(molecular.bondInstances);
        end
    end
end

function deleteIfValid(value)
if isvalid(value), delete(value); end
end
