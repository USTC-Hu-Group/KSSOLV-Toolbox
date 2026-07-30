classdef VolumeIO < handle
    %VOLUMEIO Public FileParser bridge for CHGCAR, Cube, and XSF grids.

    properties (SetAccess = private)
        filePath (1,1) string
        fileType (1,1) string
        Datasets (1,:) cell
    end

    properties (Dependent, SetAccess = private)
        Dataset
    end

    methods
        function obj = VolumeIO(filePath, format)
            arguments
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
            end
            obj.filePath = string(filePath);
            if ~isfile(obj.filePath)
                error("KSSOLV:FileParser:VolumeIO:MissingFile", ...
                    "Volume file '%s' does not exist.", obj.filePath);
            end
            kssolv.services.fileparser.volume.VolumeLimits. ...
                validateSource(obj.filePath);
            obj.fileType = ...
                kssolv.services.fileparser.volume. ...
                VolumeFormatRegistry.detect(obj.filePath, format);
            try
                obj.Datasets = ...
                    kssolv.services.fileparser.VolumeIO. ...
                    readDatasets(obj.filePath, obj.fileType);
            catch exception
                wrapper = MException( ...
                    "KSSOLV:FileParser:VolumeIO:ParseFileError", ...
                    "Error extracting volume data from %s: %s", ...
                    obj.filePath, exception.message);
                wrapper = addCause(wrapper, exception);
                throw(wrapper)
            end
        end

        function value = get.Dataset(obj)
            value = obj.Datasets{1};
        end

        function value = toInfoStruct(obj)
            manifests = cellfun(@(dataset) dataset.manifest(), ...
                obj.Datasets, UniformOutput = false);
            value = struct( ...
                "filePath", obj.filePath, ...
                "fileType", obj.fileType, ...
                "datasets", {manifests});
        end
    end

    methods (Static)
        function [datasets, format] = read(filePath, format)
            arguments
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
            end
            reader = kssolv.services.fileparser.VolumeIO(filePath, format);
            datasets = reader.Datasets;
            format = reader.fileType;
        end

        function value = supportedFormats()
            value = ...
                kssolv.services.fileparser.volume. ...
                VolumeFormatRegistry.supportedFormats();
        end

        function value = fileFilters()
            value = ...
                kssolv.services.fileparser.volume. ...
                VolumeFormatRegistry.fileFilters();
        end
    end

    methods (Static, Access = private)
        function datasets = readDatasets(filePath, format)
            switch format
                case "chgcar"
                    datasets = ...
                        kssolv.services.fileparser.volume. ...
                        VaspVolumeAdapter.read(filePath);
                case "cube"
                    datasets = ...
                        kssolv.services.fileparser.volume. ...
                        CubeVolumeAdapter.read(filePath);
                case "xsf"
                    datasets = ...
                        kssolv.services.fileparser.volume. ...
                        XSFVolumeAdapter.read(filePath);
                otherwise
                    error("KSSOLV:FileParser:VolumeIO:UnsupportedFormat", ...
                        "Unsupported volume format '%s'.", format);
            end
        end
    end
end
