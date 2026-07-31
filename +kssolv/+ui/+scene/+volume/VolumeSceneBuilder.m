classdef VolumeSceneBuilder
    %VOLUMESCENEBUILDER Build a JSON manifest plus detached voxel payloads.

    methods (Static)
        function [scene, payloads] = build(dataset, options)
            arguments
                dataset (1,1) kssolv.services.fileparser.VolumeDataset
                options.requestId (1,1) string = ""
                options.transportNamespace (1,1) string = ""
                options.atomicOverlay = []
                options.encoding (1,1) string {mustBeMember( ...
                    options.encoding, [ ...
                    "float32-le", "float64-le", ...
                    "uint16-linear-le"])} = ...
                    "float32-le"
            end
            if options.requestId == ""
                options.requestId = string(char(java.util.UUID. ...
                    randomUUID()));
            end
            if options.transportNamespace == ""
                options.transportNamespace = options.requestId;
            end
            channels = dataset.channels;
            payloads = repmat(emptyPayload(), 1, numel(channels));
            metadata = repmat(emptyChannel(), 1, numel(channels));
            for index = 1:numel(channels)
                channel = channels(index);
                transferId = options.transportNamespace + ":" + ...
                    string(channel.id);
                switch options.encoding
                    case "float32-le"
                        values = single(channel.values);
                        bytesPerValue = 4;
                        scale = [];
                        offset = [];
                    case "float64-le"
                        values = double(channel.values);
                        bytesPerValue = 8;
                        scale = [];
                        offset = [];
                    case "uint16-linear-le"
                        offset = double(channel.minimum);
                        span = double(channel.maximum) - offset;
                        if span <= eps(max(1, abs(offset)))
                            scale = 1;
                            values = zeros(size(channel.values), "uint16");
                        else
                            scale = span / 65535;
                            values = uint16(round( ...
                                (double(channel.values) - offset) / scale));
                        end
                        bytesPerValue = 2;
                end
                payloads(index) = struct( ...
                    "transferId", transferId, ...
                    "channelId", string(channel.id), ...
                    "encoding", options.encoding, ...
                    "values", values);
                channelMetadata = rmfield(channel, "values");
                if isempty(channelMetadata.integral)
                    % jsonencode maps NaN to JSON null, the protocol's
                    % explicit representation for an unavailable integral.
                    channelMetadata.integral = NaN;
                end
                transport = struct( ...
                    "transferId", transferId, ...
                    "valueEncoding", options.encoding, ...
                    "elementCount", numel(values), ...
                    "byteLength", numel(values) * bytesPerValue, ...
                    "crc32", double(fullChecksum(values)));
                if options.encoding == "uint16-linear-le"
                    transport.scale = scale;
                    transport.offset = offset;
                end
                channelMetadata.transport = transport;
                metadata(index) = channelMetadata;
            end
            scene = dataset.manifest();
            if isfield(scene.source, "path")
                scene.source = rmfield(scene.source, "path");
            end
            scene.requestId = options.requestId;
            scene.channels = metadata;
            scene.atomicOverlay = options.atomicOverlay;
            scene.transport = struct( ...
                "protocol", "chunked-binary", ...
                "chunkBytes", ...
                kssolv.services.fileparser.volume.VolumeLimits. ...
                DefaultChunkBytes);
            kssolv.ui.scene.volume.VolumeSceneValidator.validate(scene);
        end
    end
end

function checksum = fullChecksum(values)
values = values(:);
[~, ~, endian] = computer;
if endian ~= "L", values = swapbytes(values); end
bytes = typecast(values, "uint8");
checksum = kssolv.ui.scene.volume.VolumeChunkEncoder.crc32(bytes);
end

function value = emptyPayload()
value = struct("transferId", "", "channelId", "", ...
    "encoding", "", "values", []);
end

function value = emptyChannel()
value = struct("id", "", "label", "", "units", "", ...
    "signed", false, "minimum", 0, "maximum", 0, "mean", 0, ...
    "standardDeviation", 0, "integral", [], ...
    "transport", struct());
end
