classdef ProjectFileValidationTest < matlab.unittest.TestCase
    methods (Test)
        function rejectsDamagedAndUnrelatedFiles(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'invalid.ks');
            writelines('not a MATLAB project', file);
            testCase.verifyError(@() kssolv.services.filemanager.Project.loadKsFile(file), ...
                'KSSOLV:FileManager:Project:FileLoadError');
            data = 42;
            save(file, 'data', '-mat');
            testCase.verifyError(@() kssolv.services.filemanager.Project.loadKsFile(file), ...
                'KSSOLV:FileManager:Project:FileLoadError');
            other = 1;
            save(file, 'other', '-mat');
            testCase.verifyError(@() kssolv.services.filemanager.Project.loadKsFile(file), ...
                'KSSOLV:FileManager:Project:FileLoadError');
        end

        function acceptsValidProjectAfterFailure(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'valid.ks');
            project = kssolv.services.filemanager.Project();
            project.label = 'Round trip';
            project.saveToKsFile(file);
            restored = kssolv.services.filemanager.Project.loadKsFile(file);
            testCase.verifyEqual(restored.label, project.label);
            testCase.verifyEqual(numel(restored.children), 4);
        end
    end
end
