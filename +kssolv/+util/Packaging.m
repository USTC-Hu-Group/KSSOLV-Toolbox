classdef Packaging
    %PACKAGING Shared release-file boundaries and required license notices.
    methods (Static)
        function matches = isNoticeFile(paths)
            [~, names, extensions] = fileparts(string(paths));
            names = lower(names + extensions);
            matches = contains(names, ["license", "licence", "notice", ...
                "copying", "copyright"]) | endsWith(names, ".rights");
            matches = matches & ~endsWith(names, [".m", ".p"]);
        end

        function matches = isDevelopmentFile(paths)
            paths = "/" + strip(replace(string(paths), "\", "/"), 'both', '/');
            [~, names, extensions] = fileparts(paths);
            names = lower(names + extensions);
            matches = ismember(names, [".git", ".gitignore", ".gitattributes", ...
                ".ds_store", "agents.md", "claude.md", "buildfile.m", ...
                "buildfile.p", "buildinstaller.m", "buildinstaller.p"]) | ...
                endsWith(names, [".prj", ".prj.bak", ".mlx", ".asv", ...
                ".m~", ".swp", ".pyc", ".pyo"]) | ...
                endsWith(paths, ["/kssolv-3o/startup.m", ...
                "/kssolv-3o/startup.p", "/docs/development-layout.md"]);
            % Keep third-party notices even when stored alongside authoring docs.
            internalDocs = contains(paths, "/+kssolv/") & ...
                contains(paths, ["/docs/", "/doc/"]);
            matches = matches | ...
                (internalDocs & ~kssolv.util.Packaging.isNoticeFile(paths));
        end

        function files = rootLicenseFiles(root)
            files = fullfile(string(root), ...
                ["LICENSE"; "THIRD-PARTY-LICENSES.md"; "COMMERCIAL-LICENSE.md"]);
            missing = files(~isfile(files));
            if ~isempty(missing)
                error('KSSOLV:Packaging:MissingLicense', ...
                    'Required release notices were not found:\n%s', ...
                    char(join(missing, newline)));
            end
        end

        function files = licenseFiles(root)
            files = kssolv.util.Packaging.rootLicenseFiles(root);
            entries = dir(fullfile(root, '+kssolv', '**', '*'));
            entries = entries(~[entries.isdir]);
            candidates = string(fullfile({entries.folder}, {entries.name}));
            normalized = "/" + replace(candidates, "\", "/") + "/";
            isTest = false(size(candidates));
            for segment = ["+test", "+tests", "test", "tests"]
                isTest = isTest | contains(normalized, "/" + segment + "/");
            end
            notices = candidates(kssolv.util.Packaging.isNoticeFile(candidates) & ~isTest);
            files = unique([files(:); notices(:)], 'stable');
        end
    end
end
