classdef CrystalViewerRuntimeTest < matlab.unittest.TestCase
    %CRYSTALVIEWERRUNTIMETEST Runtime build identity and tamper checks.

    methods (Test)
        function computesKnownSha256(testCase)
            directory = string(tempname);
            mkdir(directory);
            cleanup = onCleanup(@()rmdir(directory, "s")); %#ok<NASGU>
            entry = fullfile(directory, "index.html");
            writeBytes(entry, uint8('abc'));

            testCase.verifyEqual( ...
                kssolv.ui.util.CrystalViewerRuntime.sha256(entry), ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        end

        function verifiesManifestAndRejectsTampering(testCase)
            directory = string(tempname);
            mkdir(directory);
            cleanup = onCleanup(@()rmdir(directory, "s")); %#ok<NASGU>
            entry = fullfile(directory, "index.html");
            writeBytes(entry, uint8('<!doctype html>'));
            digest = kssolv.ui.util.CrystalViewerRuntime.sha256(entry);
            manifest = struct( ...
                "schemaVersion", 1, ...
                "application", "crystal-viewer", ...
                "applicationVersion", "test", ...
                "sourceRevision", "test", ...
                "builtAtUtc", "2026-08-11T00:00:00.000Z", ...
                "entryFile", "index.html", ...
                "entrySha256", digest);
            writeBytes(fullfile(directory, "build-manifest.json"), ...
                unicode2native(jsonencode(manifest), "UTF-8"));

            actual = kssolv.ui.util.CrystalViewerRuntime.verify(entry);
            testCase.verifyEqual(string(actual.entrySha256), digest);

            writeBytes(entry, uint8('tampered'));
            testCase.verifyError( ...
                @()kssolv.ui.util.CrystalViewerRuntime.verify(entry), ...
                "KSSOLV:CrystalViewer:RuntimeHashMismatch");
        end

        function bootstrapSetupPrecedesModuleBundle(testCase)
            entry = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", ...
                "+ui", "+components", "+figuredocument", ...
                "@MoleculeDisplay", "CrystalViewer", "index.html");
            html = string(fileread(entry));
            setupIndex = strfind(html, "window.setup = function");
            moduleIndex = strfind(html, "type=""module""");

            testCase.verifyNotEmpty(setupIndex, ...
                "The synchronous MATLAB setup proxy is missing.");
            testCase.verifyNotEmpty(moduleIndex, ...
                "The Crystal Viewer module bundle is missing.");
            testCase.verifyLessThan(setupIndex(1), moduleIndex(1), ...
                "MATLAB setup must be defined before the module bundle.");
            testCase.verifyNotEmpty(strfind(html, "viewer:bootstrap"), ...
                "The early CEF bootstrap diagnostic event is missing.");
        end
    end
end

function writeBytes(path, bytes)
file = fopen(path, "wb");
if file < 0
    error("KSSOLV:Test:Write", "Cannot create test fixture: %s", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, bytes, "uint8");
clear cleanup
end
