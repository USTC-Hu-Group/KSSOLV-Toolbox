function [methodinfo, structs, enuminfo, thunk] = cryptoPrototype
%CRYPTOPROTOTYPE Compiler-free signatures for MATLAB's OpenSSL library.
% Only stable C interfaces and primitive/pointer types are used.
if ispc, longType = 'int32'; else, longType = 'int64'; end
definitions = {
    'RAND_bytes', 'int32', {'uint8Ptr', 'int32'};
    'EVP_PKEY_CTX_new_id', 'voidPtr', {'int32', 'voidPtr'};
    'EVP_PKEY_CTX_new', 'voidPtr', {'voidPtr', 'voidPtr'};
    'EVP_PKEY_CTX_free', '', {'voidPtr'};
    'EVP_PKEY_keygen_init', 'int32', {'voidPtr'};
    'EVP_PKEY_CTX_set_rsa_keygen_bits', 'int32', {'voidPtr', 'int32'};
    'EVP_PKEY_keygen', 'int32', {'voidPtr', 'voidPtrPtr'};
    'EVP_PKEY_free', '', {'voidPtr'};
    'EVP_PKEY2PKCS8', 'voidPtr', {'voidPtr'};
    'PKCS8_PRIV_KEY_INFO_free', '', {'voidPtr'};
    'i2d_PKCS8_PRIV_KEY_INFO', 'int32', {'voidPtr', 'uint8PtrPtr'};
    'i2d_PUBKEY', 'int32', {'voidPtr', 'uint8PtrPtr'};
    'd2i_PKCS8_PRIV_KEY_INFO', 'voidPtr', {'voidPtrPtr', 'uint8PtrPtr', longType};
    'EVP_PKCS82PKEY', 'voidPtr', {'voidPtr'};
    'd2i_PUBKEY', 'voidPtr', {'voidPtrPtr', 'uint8PtrPtr', longType};
    'EVP_PKEY_encrypt_init', 'int32', {'voidPtr'};
    'EVP_PKEY_decrypt_init', 'int32', {'voidPtr'};
    'EVP_PKEY_CTX_set_rsa_padding', 'int32', {'voidPtr', 'int32'};
    'EVP_PKEY_CTX_set_rsa_oaep_md', 'int32', {'voidPtr', 'voidPtr'};
    'EVP_PKEY_CTX_set_rsa_mgf1_md', 'int32', {'voidPtr', 'voidPtr'};
    'EVP_sha256', 'voidPtr', {};
    'EVP_sha1', 'voidPtr', {};
    'EVP_PKEY_encrypt', 'int32', {'voidPtr', 'uint8Ptr', 'uint64Ptr', 'uint8Ptr', 'uint64'};
    'EVP_PKEY_decrypt', 'int32', {'voidPtr', 'uint8Ptr', 'uint64Ptr', 'uint8Ptr', 'uint64'};
    'EVP_CIPHER_CTX_new', 'voidPtr', {};
    'EVP_CIPHER_CTX_free', '', {'voidPtr'};
    'EVP_aes_256_gcm', 'voidPtr', {};
    'EVP_EncryptInit_ex', 'int32', {'voidPtr', 'voidPtr', 'voidPtr', 'uint8Ptr', 'uint8Ptr'};
    'EVP_DecryptInit_ex', 'int32', {'voidPtr', 'voidPtr', 'voidPtr', 'uint8Ptr', 'uint8Ptr'};
    'EVP_CIPHER_CTX_ctrl', 'int32', {'voidPtr', 'int32', 'int32', 'voidPtr'};
    'EVP_EncryptUpdate', 'int32', {'voidPtr', 'uint8Ptr', 'int32Ptr', 'uint8Ptr', 'int32'};
    'EVP_DecryptUpdate', 'int32', {'voidPtr', 'uint8Ptr', 'int32Ptr', 'uint8Ptr', 'int32'};
    'EVP_EncryptFinal_ex', 'int32', {'voidPtr', 'uint8Ptr', 'int32Ptr'};
    'EVP_DecryptFinal_ex', 'int32', {'voidPtr', 'uint8Ptr', 'int32Ptr'};
    };
methodinfo = struct('name', {definitions(:,1).'}, ...
    'calltype', {repmat({'cdecl'}, 1, size(definitions,1))}, ...
    'LHS', {definitions(:,2).'}, 'RHS', {definitions(:,3).'}, ...
    'alias', {repmat({''}, 1, size(definitions,1))});
structs = []; enuminfo = []; thunk = '';
end
