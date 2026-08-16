classdef CodeBundleBuilder < handle
    %CODEBUNDLEBUILDER Build a bundle from a development or Toolbox runtime.

    properties (SetAccess = immutable)
        BundleRoot (1, 1) string
        RuntimeRoot (1, 1) string
    end

    properties (Constant, Access = private)
        ExcludedNames = [".git", "dev", "+test", "+tests", "test", ...
            "tests", "acceptance", ".buildtool"]
    end

    methods
        function this = CodeBundleBuilder(bundleRoot, options)
            arguments
                bundleRoot (1, 1) string = ...
                    fullfile(prefdir, "KSSOLV", "remote", "bundles")
                options.RuntimeRoot (1, 1) string = ""
            end
            this.BundleRoot = bundleRoot;
            this.RuntimeRoot = options.RuntimeRoot;
        end

        function [archivePath, manifest] = build(this, mode)
            arguments
                this
                mode (1, 1) string {mustBeMember(mode, ...
                    ["Workflow", "Probe"])} = "Workflow"
            end
            sourceRoot = this.resolveRuntimeRoot();
            bundleId = kssolv.services.remote.config.RemoteConfiguration.newId();
            stagingPath = fullfile(this.BundleRoot, bundleId);
            archivePath = stagingPath + ".zip";
            [created, detail] = mkdir(stagingPath);
            if ~created
                error("KSSOLV:Remote:BundleCreateFailed", ...
                    "Unable to create code bundle %s: %s", ...
                    stagingPath, detail);
            end
            try
                toolboxEntry = this.toolboxEntryPoint(sourceRoot);
                copyfile(toolboxEntry, stagingPath);
                if mode == "Probe"
                    this.copyProbeRuntime(sourceRoot, stagingPath);
                else
                    packageRoot = fullfile(stagingPath, "+kssolv");
                    mkdir(packageRoot);
                    folders = ["+core", "+analysis"];
                    for folder = folders
                        this.copyTree(fullfile(sourceRoot, "+kssolv", ...
                            folder), fullfile(packageRoot, folder));
                    end
                    servicesRoot = fullfile(packageRoot, "+services");
                    mkdir(servicesRoot);
                    serviceFolders = ["+remote", "+workflow"];
                    for folder = serviceFolders
                        this.copyTree(fullfile(sourceRoot, "+kssolv", ...
                            "+services", folder), ...
                            fullfile(servicesRoot, folder));
                    end
                end
                manifest = this.manifest(stagingPath);
                kssolv.services.remote.internal.AtomicJsonFile.write( ...
                    fullfile(stagingPath, "remote-bundle-manifest.json"), ...
                    manifest);
                [~, entryName, entryExtension] = fileparts(toolboxEntry);
                archiveEntries = [entryName + entryExtension, ...
                    "remote-bundle-manifest.json", "+kssolv"];
                zip(archivePath, archiveEntries, stagingPath);
                if ~isfile(archivePath)
                    error("KSSOLV:Remote:BundleArchiveFailed", ...
                        "The worker bundle archive was not created.");
                end
                rmdir(stagingPath, "s");
            catch exception
                removeOnFailure(stagingPath);
                removeOnFailure(archivePath);
                rethrow(exception)
            end
        end
    end

    methods (Access = private)
        function sourceRoot = resolveRuntimeRoot(this)
            if strlength(this.RuntimeRoot) > 0
                sourceRoot = this.RuntimeRoot;
                this.validateRuntimeRoot(sourceRoot);
                return
            end
            candidates = string(KSSOLV_Toolbox.RootDirectory);
            definition = string(which("KSSOLV_Toolbox"));
            if strlength(definition) > 0
                candidates(end + 1, 1) = string(fileparts(definition));
            end
            candidates = unique(candidates(strlength(candidates) > 0), ...
                "stable");
            for candidate = candidates(:).'
                if this.isRuntimeRoot(candidate)
                    sourceRoot = candidate;
                    return
                end
            end
            error("KSSOLV:Remote:BundleRuntimeMissing", ...
                ["Unable to locate the distributable KSSOLV runtime. " ...
                "Reinstall the toolbox."]);
        end

        function validateRuntimeRoot(this, sourceRoot)
            if ~this.isRuntimeRoot(sourceRoot)
                error("KSSOLV:Remote:BundleRuntimeMissing", ...
                    "The KSSOLV runtime folder is incomplete: %s", ...
                    sourceRoot);
            end
        end

        function value = isRuntimeRoot(~, sourceRoot)
            value = (isfile(fullfile(sourceRoot, "KSSOLV_Toolbox.m")) || ...
                isfile(fullfile(sourceRoot, "KSSOLV_Toolbox.p"))) && ...
                isfolder(fullfile(sourceRoot, "+kssolv", "+core", ...
                    "kssolv-3o")) && ...
                isfolder(fullfile(sourceRoot, "+kssolv", "+analysis")) && ...
                isfolder(fullfile(sourceRoot, "+kssolv", "+services", ...
                    "+remote")) && ...
                isfolder(fullfile(sourceRoot, "+kssolv", "+services", ...
                    "+workflow"));
        end

        function entry = toolboxEntryPoint(~, sourceRoot)
            entry = fullfile(sourceRoot, "KSSOLV_Toolbox.m");
            if ~isfile(entry)
                entry = fullfile(sourceRoot, "KSSOLV_Toolbox.p");
            end
            if ~isfile(entry)
                error("KSSOLV:Remote:BundleSourceMissing", ...
                    "The KSSOLV Toolbox entry point is missing from %s.", ...
                    sourceRoot);
            end
        end

        function copyProbeRuntime(~, sourceRoot, stagingPath)
            destination = fullfile(stagingPath, "+kssolv", ...
                "+services", "+remote");
            mkdir(destination);
            relativePaths = [ ...
                fullfile("+bridge", ...
                    "RemoteMatlabBridgeEntrypoint"), ...
                fullfile("+diagnostics", "remoteProbe")];
            for relativePath = relativePaths
                source = fullfile(sourceRoot, "+kssolv", "+services", ...
                    "+remote", relativePath + ".m");
                extension = ".m";
                if ~isfile(source)
                    source = fullfile(sourceRoot, "+kssolv", "+services", ...
                        "+remote", relativePath + ".p");
                    extension = ".p";
                end
                target = fullfile(destination, relativePath + extension);
                targetFolder = fileparts(target);
                if ~isfolder(targetFolder)
                    mkdir(targetFolder);
                end
                [copied, detail] = copyfile(source, target);
                if ~copied
                    error("KSSOLV:Remote:BundleCopyFailed", ...
                        "Unable to copy %s: %s", source, detail);
                end
            end
        end

        function copyTree(this, source, destination)
            if ~isfolder(source)
                error("KSSOLV:Remote:BundleSourceMissing", ...
                    "Required bundle source folder %s is missing.", source);
            end
            if ~isfolder(destination)
                mkdir(destination);
            end
            entries = dir(source);
            for index = 1:numel(entries)
                name = string(entries(index).name);
                if any(name == [".", ".."]) || ...
                        any(name == this.ExcludedNames)
                    continue
                end
                sourcePath = fullfile(entries(index).folder, name);
                destinationPath = fullfile(destination, name);
                if entries(index).isdir
                    this.copyTree(sourcePath, destinationPath);
                else
                    [copied, detail] = copyfile(sourcePath, destinationPath);
                    if ~copied
                        error("KSSOLV:Remote:BundleCopyFailed", ...
                            "Unable to copy %s: %s", sourcePath, detail);
                    end
                end
            end
        end

        function value = manifest(this, path)
            files = dir(fullfile(path, "**", "*"));
            files = files(~[files.isdir]);
            relativePaths = strings(numel(files), 1);
            sizes = zeros(numel(files), 1);
            fileHashes = strings(numel(files), 1);
            for index = 1:numel(files)
                absolute = fullfile(files(index).folder, files(index).name);
                relativePaths(index) = erase(string(absolute), path + filesep);
                relativePaths(index) = replace(relativePaths(index), ...
                    filesep, "/");
                sizes(index) = files(index).bytes;
                fileHashes(index) = this.sha256File(absolute);
            end
            [relativePaths, order] = sort(relativePaths);
            sizes = sizes(order);
            fileHashes = fileHashes(order);
            digest = javaMethod("getInstance", ...
                "java.security.MessageDigest", "SHA-256");
            canonical = strjoin(relativePaths + ":" + fileHashes, newline);
            bytes = unicode2native(char(canonical), "UTF-8");
            digest.update(typecast(uint8(bytes), "int8"));
            hash = lower(reshape(dec2hex(typecast( ...
                digest.digest(), "uint8"), 2).', 1, []));
            value = struct( ...
                "Version", 2, ...
                "ToolboxVersion", string(KSSOLV_Toolbox.Version), ...
                "MatlabRelease", string(version("-release")), ...
                "CreatedAt", string(datetime("now", "TimeZone", "UTC", ...
                    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")), ...
                "FileCount", numel(relativePaths), ...
                "TotalBytes", sum(sizes), ...
                "ContentIndexSha256", string(hash), ...
                "Files", relativePaths);
        end

        function hash = sha256File(~, path)
            digest = javaMethod("getInstance", ...
                "java.security.MessageDigest", "SHA-256");
            [file, message] = fopen(path, "rb");
            if file < 0
                error("KSSOLV:Remote:BundleReadFailed", ...
                    "Unable to read bundle source %s: %s", path, message);
            end
            cleanup = onCleanup(@()fclose(file));
            while true
                bytes = fread(file, 1024 * 1024, "*uint8");
                if isempty(bytes)
                    break
                end
                digest.update(typecast(bytes(:), "int8"));
            end
            hash = string(lower(reshape(dec2hex(typecast( ...
                digest.digest(), "uint8"), 2).', 1, [])));
            clear cleanup
        end
    end
end

function removeOnFailure(path)
if isfolder(path)
    rmdir(path, "s");
elseif isfile(path)
    delete(path);
end
end
