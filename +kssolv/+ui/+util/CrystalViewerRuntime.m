classdef CrystalViewerRuntime
    %CRYSTALVIEWERRUNTIME Verify the embedded viewer build identity.

    methods (Static)
        function manifest = verify(entryPath)
            arguments
                entryPath (1,1) string
            end
            if ~isfile(entryPath)
                error("KSSOLV:CrystalViewer:RuntimeEntryMissing", ...
                    "CrystalViewer runtime entry is missing: %s", entryPath);
            end
            manifestPath = fullfile(fileparts(entryPath), ...
                "build-manifest.json");
            if ~isfile(manifestPath)
                error("KSSOLV:CrystalViewer:BuildManifestMissing", ...
                    "CrystalViewer build manifest is missing: %s", ...
                    manifestPath);
            end
            try
                manifest = jsondecode(fileread(manifestPath));
            catch exception
                error("KSSOLV:CrystalViewer:BuildManifestInvalid", ...
                    "Cannot read CrystalViewer build manifest '%s': %s", ...
                    manifestPath, exception.message);
            end
            required = ["schemaVersion", "application", ...
                "applicationVersion", "sourceRevision", "builtAtUtc", ...
                "entryFile", "entrySha256"];
            if ~isstruct(manifest) || ...
                    ~all(arrayfun(@(name)isfield(manifest, name), required)) || ...
                    manifest.schemaVersion ~= 1 || ...
                    string(manifest.application) ~= "crystal-viewer" || ...
                    string(manifest.entryFile) ~= string( ...
                    extractAfter(entryPath, fileparts(entryPath) + filesep)) || ...
                    isempty(regexp(char(string(manifest.entrySha256)), ...
                    '^[a-f0-9]{64}$', 'once'))
                error("KSSOLV:CrystalViewer:BuildManifestInvalid", ...
                    "CrystalViewer build manifest is incomplete or incompatible: %s", ...
                    manifestPath);
            end
            kssolv.ui.util.CrystalViewerRuntime.assertEntry( ...
                entryPath, string(manifest.entrySha256));
        end

        function assertEntry(entryPath, expectedSha256)
            arguments
                entryPath (1,1) string
                expectedSha256 (1,1) string
            end
            actual = kssolv.ui.util.CrystalViewerRuntime.sha256(entryPath);
            if actual ~= lower(expectedSha256)
                error("KSSOLV:CrystalViewer:RuntimeHashMismatch", ...
                    "CrystalViewer runtime hash mismatch for '%s'. " + ...
                    "Expected %s, got %s. Rebuild and sync the runtime.", ...
                    entryPath, expectedSha256, actual);
            end
        end

        function value = sha256(path)
            arguments
                path (1,1) string
            end
            file = fopen(path, "rb");
            if file < 0
                error("KSSOLV:CrystalViewer:RuntimeRead", ...
                    "Cannot read CrystalViewer runtime file: %s", path);
            end
            cleanup = onCleanup(@()fclose(file));
            bytes = fread(file, Inf, "*uint8");
            clear cleanup
            engine = java.security.MessageDigest.getInstance("SHA-256");
            engine.update(typecast(bytes, "int8"));
            digest = typecast(engine.digest(), "uint8");
            value = lower(string(reshape(dec2hex(digest, 2).', 1, [])));
        end
    end
end
