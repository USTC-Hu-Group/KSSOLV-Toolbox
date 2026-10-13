classdef Hash
    %HASH Deterministic SHA-256 hashing of text and binary data.

    methods (Static)
        function value = sha256Text(text)
            value = kssolv.util.Hash.text(text);
        end

        function value = sha256Bytes(bytes)
            value = kssolv.util.Hash.bytes(bytes);
        end
    end

end
