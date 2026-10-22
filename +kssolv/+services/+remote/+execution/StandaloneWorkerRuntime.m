classdef StandaloneWorkerRuntime
    %STANDALONEWORKERRUNTIME Portable P-Code for remote MATLAB workers.
    properties (Constant)
        ArchiveName = 'kssolv-remote-worker.zip'
    end

    methods (Static)
        function [archive, cleanup] = stage(sourceRoot, stagingParent)
            if ~isfolder(stagingParent), mkdir(stagingParent); end
            stageRoot = string(tempname(stagingParent));
            mkdir(stageRoot);
            cleanup = onCleanup(@()removeFolder(stageRoot));
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                fullfile(stageRoot, 'sources'), RuntimeRoot=sourceRoot);
            sourceArchive = builder.build();
            runtime = fullfile(stageRoot, 'runtime');
            unzip(sourceArchive, runtime);
            sources = dir(fullfile(runtime, '**', '*.m'));
            paths = string(fullfile({sources.folder}, {sources.name}));
            if ~isempty(paths)
                files = cellstr(paths);
                pcode(files{:}, '-inplace', '-R2022a');
                for path = paths, delete(path); end
            end
            % Rebuild the manifest from the protected files actually shipped.
            builder = kssolv.services.remote.execution.CodeBundleBuilder( ...
                fullfile(stageRoot, 'protected'), RuntimeRoot=runtime);
            protectedArchive = builder.build();
            archive = fullfile(stageRoot, ...
                kssolv.services.remote.execution.StandaloneWorkerRuntime.ArchiveName);
            movefile(protectedArchive, archive);
        end

        function root = resolve(options)
            arguments
                options.Archive (1,1) string = ""
                options.CacheRoot (1,1) string = ...
                    fullfile(prefdir, 'KSSOLV', 'remote', 'worker-runtime')
            end
            archive = options.Archive;
            if archive == ""
                entries = dir(fullfile(ctfroot, '**', ...
                    kssolv.services.remote.execution.StandaloneWorkerRuntime.ArchiveName));
                if numel(entries) ~= 1
                    error('KSSOLV:Remote:WorkerRuntimeMissing', ...
                        'Reinstall KSSOLV Toolbox: the remote worker archive is missing or ambiguous.');
                end
                archive = string(fullfile(entries.folder, entries.name));
            end
            if ~isfile(archive)
                error('KSSOLV:Remote:WorkerRuntimeMissing', ...
                    'The remote worker archive does not exist: %s', archive);
            end
            hash = kssolv.util.Hash.file(archive);
            root = fullfile(options.CacheRoot, hash);
            if validRuntime(root), return; end
            if ~isfolder(options.CacheRoot), mkdir(options.CacheRoot); end
            temporary = string(tempname(options.CacheRoot));
            cleanup = onCleanup(@()removeFolder(temporary));
            unzip(archive, temporary);
            if ~validRuntime(temporary) || ...
                    ~isempty(dir(fullfile(temporary, '**', '*.m')))
                error('KSSOLV:Remote:WorkerRuntimeInvalid', ...
                    'The protected remote worker runtime is incomplete. Reinstall KSSOLV Toolbox.');
            end
            if isfolder(root) && ~validRuntime(root), rmdir(root, 's'); end
            if ~isfolder(root)
                [moved, detail] = movefile(temporary, root);
                if ~moved && ~validRuntime(root)
                    error('KSSOLV:Remote:WorkerRuntimeExtractFailed', '%s', detail);
                end
            end
            clear cleanup
        end
    end
end

function valid = validRuntime(root)
valid = isfile(fullfile(root, 'KSSOLV_Toolbox.p')) && ...
    isfile(fullfile(root, 'remote-bundle-manifest.json')) && ...
    isfile(fullfile(root, '+kssolv', '+services', '+remote', ...
    '+bridge', 'RemoteMatlabBridgeEntrypoint.p')) && ...
    isfile(fullfile(root, '+kssolv', '+services', '+remote', ...
    '+execution', 'RemoteWorkflowRunner.p'));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
