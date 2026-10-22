classdef Crypto
    %CRYPTO Native RSA/AES operations backed by MATLAB's bundled OpenSSL.
    % DER encodings, OAEP parameters and GCM tag layout retain the existing
    % credential format. No secrets are passed to external processes.
    methods (Static)
        function bytes = random(count)
            arguments
                count (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            if count == 0, bytes = zeros(1,0,'uint8'); return; end
            output = libpointer('uint8Ptr', zeros(1,count,'uint8'));
            check(calllib(backend(), 'RAND_bytes', output, count));
            bytes = output.Value;
        end

        function [privateBytes, publicBytes] = rsaKeyPair(bits)
            arguments
                bits (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(bits,2048)} = 3072
            end
            lib = backend();
            context = calllib(lib, 'EVP_PKEY_CTX_new_id', 6, []);
            checkPointer(context);
            contextCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_CTX_free',context));
            check(calllib(lib,'EVP_PKEY_keygen_init',context));
            check(calllib(lib,'EVP_PKEY_CTX_set_rsa_keygen_bits',context,bits));
            holder = libpointer('voidPtrPtr');
            check(calllib(lib,'EVP_PKEY_keygen',context,holder));
            key = holder.Value;
            keyCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_free',key));
            info = calllib(lib,'EVP_PKEY2PKCS8',key);
            checkPointer(info);
            infoCleanup = onCleanup(@()calllib(lib,'PKCS8_PRIV_KEY_INFO_free',info));
            privateBytes = encodeDER(lib,'i2d_PKCS8_PRIV_KEY_INFO',info);
            publicBytes = encodeDER(lib,'i2d_PUBKEY',key);
        end

        function output = rsaEncrypt(publicBytes, input, padding)
            arguments
                publicBytes
                input
                padding (1,1) string {mustBeMember(padding,["oaep","pkcs1"])} = "oaep"
            end
            output = rsaOperation(publicBytes,input,padding,false);
        end

        function output = rsaDecrypt(privateBytes, input)
            output = rsaOperation(privateBytes,input,"oaep",true);
        end

        function validateRsaKeyPair(privateBytes, publicBytes)
            lib = backend();
            private = decodeDER(lib,privateBytes,true);
            privateCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_free',private));
            public = decodeDER(lib,publicBytes,false);
            publicCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_free',public));
        end

        function ciphertext = aesEncrypt(key, nonce, plaintext, associatedData)
            ciphertext = aesOperation(key,nonce,plaintext,associatedData,false);
        end

        function plaintext = aesDecrypt(key, nonce, ciphertext, associatedData)
            plaintext = aesOperation(key,nonce,ciphertext,associatedData,true);
        end
    end
end

function lib = backend()
lib = 'kssolv_native_crypto';
if libisloaded(lib), return; end
folder = fullfile(matlabroot,'bin',computer('arch'));
if ispc
    pattern = 'libcrypto*.dll';
elseif ismac
    pattern = 'libcrypto*.dylib';
else
    pattern = 'libcrypto*.so*';
end
files = dir(fullfile(folder,pattern));
if isempty(files)
    files = dir(fullfile(matlabroot,'sys','os',computer('arch'),pattern));
end
if isempty(files)
    error('KSSOLV:Crypto:BackendMissing', ...
        'MATLAB native cryptography library is missing from %s.',folder);
end
% Prefer the versioned library over symlinks/other OpenSSL versions.
names = string({files.name});
preferred = find(contains(names,'3'),1);
if isempty(preferred), preferred = 1; end
loadlibrary(fullfile(files(preferred).folder,files(preferred).name), ...
    @kssolv.util.cryptoPrototype,'alias',lib);
end

function bytes = encodeDER(lib, method, key)
count = calllib(lib,method,key,[]);
check(count);
output = libpointer('uint8Ptr',zeros(1,count,'uint8'));
cursor = libpointer('uint8PtrPtr',output + 0);
actual = calllib(lib,method,key,cursor);
check(actual == count);
bytes = output.Value;
end

function key = decodeDER(lib, bytes, isPrivate)
bytes = reshape(uint8(bytes),1,[]);
input = libpointer('uint8Ptr',bytes);
cursor = libpointer('uint8PtrPtr',input + 0);
if isPrivate
    info = calllib(lib,'d2i_PKCS8_PRIV_KEY_INFO',[],cursor,numel(bytes));
    checkPointer(info);
    cleanup = onCleanup(@()calllib(lib,'PKCS8_PRIV_KEY_INFO_free',info));
    key = calllib(lib,'EVP_PKCS82PKEY',info);
else
    key = calllib(lib,'d2i_PUBKEY',[],cursor,numel(bytes));
end
checkPointer(key);
end

function output = rsaOperation(keyBytes,input,padding,decrypt)
lib = backend();
key = decodeDER(lib,keyBytes,decrypt);
keyCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_free',key));
context = calllib(lib,'EVP_PKEY_CTX_new',key,[]);
checkPointer(context);
contextCleanup = onCleanup(@()calllib(lib,'EVP_PKEY_CTX_free',context));
if decrypt, method = 'EVP_PKEY_decrypt'; else, method = 'EVP_PKEY_encrypt'; end
check(calllib(lib,[method '_init'],context));
if padding == "oaep"
    check(calllib(lib,'EVP_PKEY_CTX_set_rsa_padding',context,4));
    check(calllib(lib,'EVP_PKEY_CTX_set_rsa_oaep_md',context,calllib(lib,'EVP_sha256')));
    % Existing SunJCE OAEP ciphertext uses SHA-256 with MGF1-SHA1.
    check(calllib(lib,'EVP_PKEY_CTX_set_rsa_mgf1_md',context,calllib(lib,'EVP_sha1')));
else
    check(calllib(lib,'EVP_PKEY_CTX_set_rsa_padding',context,1));
end
input = reshape(uint8(input),1,[]);
sizePointer = libpointer('uint64Ptr',uint64(0));
check(calllib(lib,method,context,[],sizePointer,input,numel(input)));
buffer = libpointer('uint8Ptr',zeros(1,double(sizePointer.Value),'uint8'));
check(calllib(lib,method,context,buffer,sizePointer,input,numel(input)));
output = buffer.Value(1:double(sizePointer.Value));
end

function result = aesOperation(key,nonce,input,aad,decrypt)
key = reshape(uint8(key),1,[]); nonce = reshape(uint8(nonce),1,[]);
input = reshape(uint8(input),1,[]); aad = reshape(uint8(aad),1,[]);
if numel(key) ~= 32 || numel(nonce) ~= 12
    error('KSSOLV:Crypto:InvalidAESParameters','AES-256-GCM requires a 32-byte key and 12-byte nonce.');
end
lib = backend(); context = calllib(lib,'EVP_CIPHER_CTX_new');
checkPointer(context);
cleanup = onCleanup(@()calllib(lib,'EVP_CIPHER_CTX_free',context));
if decrypt
    method = 'EVP_Decrypt';
    if numel(input) < 16, error('KSSOLV:Crypto:AuthenticationFailed','Invalid authenticated ciphertext.'); end
    tag = input(end-15:end); input = input(1:end-16);
else
    method = 'EVP_Encrypt';
end
check(calllib(lib,[method 'Init_ex'],context,calllib(lib,'EVP_aes_256_gcm'),[],key,nonce));
lengthPointer = libpointer('int32Ptr',int32(0));
if ~isempty(aad)
    check(calllib(lib,[method 'Update'],context,[],lengthPointer,aad,numel(aad)));
end
buffer = libpointer('uint8Ptr',zeros(1,numel(input)+16,'uint8'));
check(calllib(lib,[method 'Update'],context,buffer,lengthPointer,input,numel(input)));
count = double(lengthPointer.Value);
if decrypt
    tagPointer = libpointer('uint8Ptr',tag);
    check(calllib(lib,'EVP_CIPHER_CTX_ctrl',context,17,16,tagPointer));
end
finalBuffer = libpointer('uint8Ptr',zeros(1,16,'uint8'));
status = calllib(lib,[method 'Final_ex'],context,finalBuffer,lengthPointer);
if status <= 0
    error('KSSOLV:Crypto:AuthenticationFailed','Authenticated decryption failed.');
end
result = [buffer.Value(1:count), finalBuffer.Value(1:double(lengthPointer.Value))];
if ~decrypt
    tagPointer = libpointer('uint8Ptr',zeros(1,16,'uint8'));
    check(calllib(lib,'EVP_CIPHER_CTX_ctrl',context,16,16,tagPointer));
    result = [result,tagPointer.Value];
end
end

function check(status)
if status <= 0
    error('KSSOLV:Crypto:OperationFailed','Native cryptography operation failed.');
end
end

function checkPointer(pointer)
if isNull(pointer)
    error('KSSOLV:Crypto:InvalidKey','Native cryptography could not read or allocate the key/context.');
end
end
