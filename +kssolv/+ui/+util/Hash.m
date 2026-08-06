classdef Hash
    %HASH Deterministic hashing helpers that work without MATLAB Java.

    methods (Static)
        function value = sha256Text(text)
            bytes = unicode2native(char(string(text)), "UTF-8");
            value = kssolv.ui.util.Hash.sha256Bytes(bytes);
        end

        function value = sha256Bytes(bytes)
            bytes = uint8(bytes(:));
            try
                engine = java.security.MessageDigest.getInstance("SHA-256");
                engine.update(bytes);
                digest = typecast(engine.digest(), "uint8");
                value = lower(reshape(dec2hex(digest, 2).', 1, []));
                return
            catch exception
                if ~strcmp(exception.identifier, "MATLAB:Java:JavaNotFound")
                    rethrow(exception);
                end
            end

            try
                engine = System.Security.Cryptography.SHA256Managed;
                digest = uint8(engine.ComputeHash(bytes));
                value = lower(reshape(dec2hex(digest, 2).', 1, []));
                return
            catch
            end

            value = kssolv.ui.util.Hash.fnv1a64(bytes);
        end
    end

    methods (Static, Access = private)
        function value = fnv1a64(bytes)
            hash = uint64(14695981039346656037);
            prime = uint64(1099511628211);
            for byte = reshape(uint8(bytes), 1, [])
                hash = bitxor(hash, uint64(byte));
                hash = hash * prime;
            end
            value = lower(dec2hex(hash, 16));
        end
    end
end
