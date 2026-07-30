classdef VolumeChunkEncoder
    %VOLUMECHUNKENCODER Encode detached numeric payloads for uihtml events.

    methods (Static)
        function chunks = encode(requestId, payload, chunkBytes)
            arguments
                requestId (1,1) string
                payload (1,1) struct
                chunkBytes (1,1) double = ...
                    kssolv.services.fileparser.volume.VolumeLimits. ...
                    DefaultChunkBytes
            end
            validateattributes(chunkBytes, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            values = payload.values(:);
            [~, ~, endian] = computer;
            if endian ~= "L", values = swapbytes(values); end
            bytes = typecast(values, "uint8");
            count = max(1, ceil(numel(bytes) / chunkBytes));
            chunks = repmat(emptyChunk(), 1, count);
            for index = 1:count
                first = (index - 1) * chunkBytes + 1;
                last = min(first + chunkBytes - 1, numel(bytes));
                if isempty(bytes)
                    part = zeros(1, 0, "uint8");
                else
                    part = bytes(first:last);
                end
                chunks(index) = struct( ...
                    "requestId", requestId, ...
                    "transferId", string(payload.transferId), ...
                    "chunkIndex", index - 1, ...
                    "chunkCount", count, ...
                    "byteOffset", first - 1, ...
                    "data", string(matlab.net.base64encode(part)), ...
                    "crc32", ...
                    double(kssolv.ui.volume.VolumeChunkEncoder. ...
                    crc32(part)));
            end
        end

        function checksum = crc32(bytes)
            bytes = uint8(bytes);
            checksum = uint32(hex2dec("FFFFFFFF"));
            polynomial = uint32(hex2dec("EDB88320"));
            for index = 1:numel(bytes)
                byte = bytes(index);
                checksum = bitxor(checksum, uint32(byte));
                for bit = 1:8
                    if bitand(checksum, uint32(1))
                        checksum = bitxor(bitshift(checksum, -1), ...
                            polynomial);
                    else
                        checksum = bitshift(checksum, -1);
                    end
                end
            end
            checksum = bitxor(checksum, uint32(hex2dec("FFFFFFFF")));
        end
    end
end

function value = emptyChunk()
value = struct("requestId", "", "transferId", "", ...
    "chunkIndex", 0, "chunkCount", 0, "byteOffset", 0, ...
    "data", "", "crc32", 0);
end
