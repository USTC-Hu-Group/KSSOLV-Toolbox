classdef VolumeDataset
    %VOLUMEDATASET Canonical scalar-grid dataset used by KSSOLV viewers.

    properties (SetAccess = private)
        source (1,1) struct
        structure = []
        dimensionality (1,1) double
        dimensions (1,3) double
        origin (1,3) double
        voxelVectors (3,3) double
        periodic (1,3) logical
        sampling (1,1) string
        channels (1,:) struct
        warnings (1,:) string
    end

    properties (Dependent, SetAccess = private)
        numChannels
    end

    methods
        function obj = VolumeDataset(options)
            arguments
                options.source (1,1) struct
                options.structure = []
                options.dimensionality (1,1) double {mustBeMember( ...
                    options.dimensionality, [2, 3])}
                options.dimensions (1,3) double
                options.origin (1,3) double
                options.voxelVectors (3,3) double
                options.periodic (1,3) logical
                options.sampling (1,1) string
                options.channels (1,:) struct
                options.warnings (1,:) string = strings(1, 0)
            end
            obj.source = options.source;
            obj.structure = options.structure;
            obj.dimensionality = options.dimensionality;
            obj.dimensions = options.dimensions;
            obj.origin = options.origin;
            obj.voxelVectors = options.voxelVectors;
            obj.periodic = options.periodic;
            obj.sampling = options.sampling;
            obj.channels = options.channels;
            obj.warnings = options.warnings;
            obj.validate();
        end

        function value = get.numChannels(obj)
            value = numel(obj.channels);
        end

        function value = getChannel(obj, identifier)
            identifier = string(identifier);
            matches = string({obj.channels.id}) == identifier;
            if nnz(matches) ~= 1
                error("KSSOLV:FileParser:VolumeDataset:Channel", ...
                    "Expected one channel named '%s', found %d.", ...
                    identifier, nnz(matches));
            end
            value = obj.channels(matches);
        end

        function value = manifest(obj)
            metadata = obj.channels;
            if ~isempty(metadata)
                metadata = rmfield(metadata, "values");
            end
            value = struct( ...
                "schemaVersion", "1.0", ...
                "kind", "volume", ...
                "source", obj.source, ...
                "grid", struct( ...
                    "dimensionality", obj.dimensionality, ...
                    "dimensions", obj.dimensions, ...
                    "origin", obj.origin, ...
                    "voxelVectors", obj.voxelVectors, ...
                    "periodic", obj.periodic, ...
                    "indexOrder", "x-fastest", ...
                    "sampling", obj.sampling), ...
                "channels", metadata, ...
                "warnings", obj.warnings);
            if ~isempty(obj.structure)
                value.structure = struct( ...
                    "formula", string(obj.structure.reduced_formula), ...
                    "numSites", obj.structure.num_sites);
            end
        end
    end

    methods (Access = private)
        function validate(obj)
            if any(~isfinite(obj.dimensions)) || ...
                    any(obj.dimensions < 1) || ...
                    any(obj.dimensions ~= fix(obj.dimensions))
                error("KSSOLV:FileParser:VolumeDataset:Dimensions", ...
                    "Grid dimensions must be positive finite integers.");
            end
            if any(~isfinite(obj.origin), "all") || ...
                    any(~isfinite(obj.voxelVectors), "all")
                error("KSSOLV:FileParser:VolumeDataset:Geometry", ...
                    "Grid origin and voxel vectors must be finite.");
            end
            if rank(obj.voxelVectors(1:obj.dimensionality, :)) < ...
                    obj.dimensionality
                error("KSSOLV:FileParser:VolumeDataset:Geometry", ...
                    "Grid voxel vectors must span the declared dimensions.");
            end
            if ~any(obj.sampling == ["cell-periodic", "point-inclusive"])
                error("KSSOLV:FileParser:VolumeDataset:Sampling", ...
                    "Unsupported grid sampling convention '%s'.", ...
                    obj.sampling);
            end
            if isempty(obj.channels)
                error("KSSOLV:FileParser:VolumeDataset:Channels", ...
                    "A volume dataset requires at least one channel.");
            end
            identifiers = string({obj.channels.id});
            if any(strlength(identifiers) == 0) || ...
                    numel(unique(identifiers)) ~= numel(identifiers)
                error("KSSOLV:FileParser:VolumeDataset:Channels", ...
                    "Channel identifiers must be nonempty and unique.");
            end
            for index = 1:numel(obj.channels)
                channel = obj.channels(index);
                if ~isequal(size3(channel.values), obj.dimensions)
                    error("KSSOLV:FileParser:VolumeDataset:ChannelShape", ...
                        "Channel '%s' does not match grid dimensions.", ...
                        channel.id);
                end
                if any(~isfinite(channel.values), "all")
                    error("KSSOLV:FileParser:VolumeDataset:ChannelValues", ...
                        "Channel '%s' contains NaN or Inf.", channel.id);
                end
            end
        end
    end
end

function value = size3(array)
value = size(array);
if numel(value) < 3, value(3) = 1; end
value = value(1:3);
end
