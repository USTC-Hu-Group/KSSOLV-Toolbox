classdef RemoteBundleBootstrap
    %REMOTEBUNDLEBOOTSTRAP Unpack and enter an attached worker bundle.

    methods (Static)
        function envelope = execute(snapshot, archiveName)
            arguments
                snapshot struct
                archiveName (1, 1) string
            end
            if strlength(archiveName) == 0 || ...
                    ~endsWith(lower(archiveName), ".zip") || ...
                    contains(archiveName, "/") || contains(archiveName, "\")
                error("KSSOLV:Remote:InvalidBundleName", ...
                    "The attached worker bundle name is invalid.");
            end
            attachedFolder = string(getAttachedFilesFolder(archiveName));
            if ~isscalar(attachedFolder) || strlength(attachedFolder) == 0
                error("KSSOLV:Remote:BundleUnavailable", ...
                    "The attached worker bundle is unavailable.");
            end
            archivePath = fullfile(attachedFolder, archiveName);
            if ~isfile(archivePath)
                error("KSSOLV:Remote:BundleUnavailable", ...
                    "The attached worker bundle %s was not found.", ...
                    archiveName);
            end
            executionRoot = string(tempname);
            [created, detail] = mkdir(executionRoot);
            if ~created
                error("KSSOLV:Remote:BundleExtractionFailed", ...
                    "Unable to create the worker bundle directory: %s", ...
                    detail);
            end
            cleanup = onCleanup(@()removeExecutionRoot(executionRoot));
            unzip(archivePath, executionRoot);
            toolboxFiles = fullfile(executionRoot, ...
                ["KSSOLV_Toolbox.m", "KSSOLV_Toolbox.p"]);
            if ~any(isfile(toolboxFiles))
                error("KSSOLV:Remote:InvalidBundle", ...
                    "The attached worker bundle has no KSSOLV entry point.");
            end
            addpath(executionRoot, "-begin");
            runner = str2func( ...
                "kssolv.services.remote.execution.RemoteWorkflowRunner.execute");
            envelope = runner(snapshot);
        end
    end
end

function removeExecutionRoot(executionRoot)
try
    rmpath(executionRoot);
catch
end
if isfolder(executionRoot)
    rmdir(executionRoot, "s");
end
end
