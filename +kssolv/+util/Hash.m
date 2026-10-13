classdef Hash
    %HASH Byte-exact digests using MATLAB's native crypto implementation.
    methods (Static)
        function value = bytes(bytes, algorithm)
            arguments
                bytes
                algorithm (1,1) string = "SHA256"
            end
            engine = kssolv.util.Hash.engine(algorithm);
            raw = engine.computeDigest(reshape(uint8(bytes), 1, []));
            value = lower(reshape(dec2hex(raw, 2).', 1, []));
        end

        function value = text(text, algorithm)
            arguments
                text
                algorithm (1,1) string = "SHA256"
            end
            value = kssolv.util.Hash.bytes( ...
                unicode2native(char(string(text)), "UTF-8"), algorithm);
        end

        function value = file(path, algorithm)
            arguments
                path (1,1) string
                algorithm (1,1) string = "SHA256"
            end
            engine = kssolv.util.Hash.engine(algorithm);
            raw = engine.computeFileDigest(path);
            value = lower(reshape(dec2hex(raw, 2).', 1, []));
        end

        function raw = hmac(bytes, key, algorithm)
            arguments
                bytes
                key
                algorithm (1,1) string = "SHA1"
            end
            engine = kssolv.util.Hash.engine(algorithm);
            blockSize = 64;
            if ismember(upper(algorithm), ["SHA384", "SHA512"]), blockSize = 128; end
            key = reshape(uint8(key), 1, []);
            if numel(key) > blockSize, key = engine.computeDigest(key); end
            key(end+1:blockSize) = 0;
            inner = engine.computeDigest([bitxor(key,uint8(54)), ...
                reshape(uint8(bytes),1,[])]);
            raw = engine.computeDigest([bitxor(key,uint8(92)), inner]);
        end
    end
    methods (Static, Access = private)
        function value = engine(algorithm)
            switch upper(algorithm)
                case "MD5"
                    name = "DeprecatedMD5";
                case "SHA1"
                    name = "DeprecatedSHA1";
                case {"SHA224", "SHA256", "SHA384", "SHA512"}
                    name = upper(algorithm);
                otherwise
                    error("KSSOLV:Hash:Algorithm", ...
                        "Unsupported digest algorithm: %s", algorithm);
            end
            value = matlab.internal.crypto.BasicDigester(name);
        end
    end
end
