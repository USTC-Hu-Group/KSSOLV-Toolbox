classdef FileDialog
    %FILEDIALOG File selection boundary for desktop and Online sessions.
    methods (Static)
        function [file, folder, index] = open(varargin)
            if isKSSOLVOnline()
                [file, folder, index] = ...
                    kssolv.ui.browser.OnlineFileTransfer.choose('open', varargin{:});
            else
                [file, folder, index] = uigetfile(varargin{:});
            end
        end

        function [file, folder, index] = save(varargin)
            if isKSSOLVOnline()
                [file, folder, index] = ...
                    kssolv.ui.browser.OnlineFileTransfer.choose('save', varargin{:});
            else
                [file, folder, index] = uiputfile(varargin{:});
            end
        end

        function [completed, path] = downloadProject(project, path)
            % A cancelled browser save must keep the project unsaved.
            [completed, name] = kssolv.ui.util.FileDialog.download(path, isKSSOLVOnline());
            if ~completed, project.isDirty = true; end
            [~, base, ext] = fileparts(path);
            if completed && isKSSOLVOnline() && name ~= string(base) + string(ext)
                % Keep the selected browser name without renaming a saved
                % project in a persistent volume. This is a private work copy.
                folder = string(tempname); mkdir(folder);
                target = fullfile(folder, name);
                copyfile(path, target);
                path = target;
            end
        end

        function [completed, name] = download(path, waitForConfirmation)
            % Call after the writer has closed the completed file.
            if nargin < 2, waitForConfirmation = false; end
            completed = true;
            [~, base, ext] = fileparts(path);
            name = string(base) + string(ext);
            if isKSSOLVOnline()
                [completed, name] = kssolv.ui.browser.OnlineFileTransfer.download( ...
                    path, waitForConfirmation);
            end
        end
    end
end
