classdef VolumeFormatRegistry
    %VOLUMEFORMATREGISTRY Detect supported scalar-volume file formats.

    methods (Static)
        function format = detect(filePath, requestedFormat)
            arguments
                filePath {mustBeTextScalar}
                requestedFormat {mustBeTextScalar} = ""
            end
            requestedFormat = lower(string(requestedFormat));
            if requestedFormat ~= ""
                aliases = struct( ...
                    "vasp", "chgcar", "chg", "chgcar", ...
                    "cub", "cube", "cube", "cube", ...
                    "xsf", "xsf");
                key = matlab.lang.makeValidName(char(requestedFormat));
                if ~isfield(aliases, key)
                    error("KSSOLV:FileParser:VolumeFormat:Unsupported", ...
                        "Unsupported volume format '%s'.", requestedFormat);
                end
                format = string(aliases.(key));
                return
            end

            sourceName = ...
                kssolv.services.fileparser.volume. ...
                VolumeFormatRegistry.uncompressedName(filePath);
            [~, baseName, extension] = fileparts(sourceName);
            extension = lower(string(extension));
            baseName = upper(string(baseName));
            if any(extension == [".cube", ".cub"])
                format = "cube";
            elseif extension == ".xsf"
                format = "xsf";
            elseif startsWith(baseName, "CHGCAR") || ...
                    startsWith(baseName, "CHG")
                format = "chgcar";
            else
                error("KSSOLV:FileParser:VolumeFormat:Unsupported", ...
                    "Cannot detect a supported volume format for '%s'.", ...
                    filePath);
            end
        end

        function value = supportedFormats()
            value = ["chgcar", "cube", "xsf"];
        end

        function filters = fileFilters()
            filters = { ...
                ['*.cube;*.cub;*.cube.gz;*.cub.gz;' ...
                '*.cube.bz2;*.cub.bz2;*.xsf;*.xsf.gz;' ...
                '*.xsf.bz2;*.gz;*.bz2'], ...
                'Volume data (CHGCAR, Cube, XSF)'; ...
                '*.*', 'VASP charge density (CHGCAR, CHG)'; ...
                ['*.cube;*.cub;*.cube.gz;*.cub.gz;' ...
                '*.cube.bz2;*.cub.bz2'], ...
                'Gaussian Cube (*.cube, *.cub)'; ...
                '*.xsf;*.xsf.gz;*.xsf.bz2', ...
                'XCrySDen scalar grids (*.xsf)'; ...
                '*.*', 'All files (*.*)'};
        end
    end

    methods (Static, Access = private)
        function value = uncompressedName(filePath)
            value = string(filePath);
            [folder, name, extension] = fileparts(value);
            if any(lower(string(extension)) == [".gz", ".bz2"])
                value = fullfile(folder, name);
            end
        end
    end
end
