classdef VolumeFileReader
    %VOLUMEFILEREADER UI-facing format router with stable error semantics.

    methods (Static)
        function [datasets, format] = read(filePath, format)
            arguments
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
            end
            try
                [datasets, format] = ...
                    kssolv.services.fileparser.VolumeIO.read( ...
                    filePath, format);
            catch exception
                wrapper = MException( ...
                    "KSSOLV:UI:Volume:ReadFailed", ...
                    "Unable to open volume data '%s': %s", ...
                    filePath, exception.message);
                throw(addCause(wrapper, exception))
            end
        end

        function value = fileFilters()
            value = kssolv.services.fileparser.VolumeIO.fileFilters();
        end
    end
end
