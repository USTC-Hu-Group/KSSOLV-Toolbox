classdef NativeUtilitiesTest < matlab.unittest.TestCase
    %NATIVEUTILITIESTEST Digest vectors and legacy credential compatibility.
    methods (Test)
        function digestVectors(testCase)
            testCase.verifyEqual(kssolv.util.Hash.text('abc'), ...
                'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
            testCase.verifyEqual(kssolv.util.Hash.text('abc','MD5'), ...
                '900150983cd24fb0d6963f7d28e17f72');
            testCase.verifyEqual(kssolv.util.Hash.text('abc','SHA1'), ...
                'a9993e364706816aba3e25717850c26c9cd0d89d');
            testCase.verifyError(@()kssolv.util.Hash.text('abc','invalid'), ...
                'KSSOLV:Hash:Algorithm');
        end

        function hmacVectors(testCase)
            % RFC 2202 case 1 and RFC 4231 case 6 (key exceeds block size).
            actual = kssolv.util.Hash.hmac(uint8('Hi There'),repmat(uint8(11),1,20));
            testCase.verifyEqual(actual,hexBytes('b617318655057264e28bc0b6fb378c8ef146be00'));
            actual = kssolv.util.Hash.hmac( ...
                uint8('Test Using Larger Than Block-Size Key - Hash Key First'), ...
                repmat(uint8(170),1,131),'SHA256');
            testCase.verifyEqual(actual,hexBytes( ...
                '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54'));
        end

        function fileDigestPreservesBytes(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture()).Folder;
            file = fullfile(folder,'bytes.txt');
            bytes = [unicode2native('中文','UTF-8') uint8([13 10 0 255])];
            writeBytes(file,bytes);
            testCase.verifyEqual(kssolv.util.Hash.file(file),kssolv.util.Hash.bytes(bytes));
            testCase.verifyNotEqual(kssolv.util.Hash.file(file), ...
                kssolv.util.Hash.bytes(bytes(bytes ~= 13)));
        end

        function aesGcmKnownVector(testCase)
            key = zeros(1,32,'uint8'); nonce = zeros(1,12,'uint8');
            plaintext = zeros(1,16,'uint8');
            expected = hexBytes(['cea7403d4d606b6e074ec5d3baf39d18' ...
                'd0d1c8a799996bf0265b98b5d48ab919']);
            testCase.verifyEqual(kssolv.util.Crypto.aesEncrypt(key,nonce,plaintext,[]),expected);
            testCase.verifyEqual(kssolv.util.Crypto.aesDecrypt(key,nonce,expected,[]),plaintext);
            emptyTag = hexBytes('530f8afbc74536b9a963b4f1c4cb738b');
            testCase.verifyEqual(kssolv.util.Crypto.aesEncrypt(key,nonce,[],[]),emptyTag);
            testCase.verifyEmpty(kssolv.util.Crypto.aesDecrypt(key,nonce,emptyTag,[]));
        end

        function aesRejectsTampering(testCase)
            key = kssolv.util.Crypto.random(32); nonce = kssolv.util.Crypto.random(12);
            aad = uint8('credential-type'); plain = uint8('private fixture value');
            encrypted = kssolv.util.Crypto.aesEncrypt(key,nonce,plain,aad);
            tampered = encrypted; tampered(end) = bitxor(tampered(end),uint8(1));
            testCase.verifyError(@()kssolv.util.Crypto.aesDecrypt(key,nonce,tampered,aad), ...
                'KSSOLV:Crypto:AuthenticationFailed');
            testCase.verifyError(@()kssolv.util.Crypto.aesDecrypt(key,nonce,encrypted,uint8('other')), ...
                'KSSOLV:Crypto:AuthenticationFailed');
        end

        function legacyCredentialsDecrypt(testCase)
            payload = legacyFixture();
            private = matlab.net.base64decode(payload.PrivateKey);
            expected = unicode2native(payload.Plaintext,'UTF-8');
            testCase.verifyEqual(kssolv.util.Crypto.rsaDecrypt(private, ...
                matlab.net.base64decode(payload.RsaCiphertext)),expected);
            key = matlab.net.base64decode(payload.AesKey);
            testCase.verifyEqual(kssolv.util.Crypto.rsaDecrypt(private, ...
                matlab.net.base64decode(payload.WrappedKey)),key);
            testCase.verifyEqual(kssolv.util.Crypto.aesDecrypt(key, ...
                matlab.net.base64decode(payload.Nonce), ...
                matlab.net.base64decode(payload.AesCiphertext), ...
                uint8(payload.AssociatedData)),expected);
        end

        function rsaIsRandomizedAndUsesDerKeys(testCase)
            [private,public] = kssolv.util.Crypto.rsaKeyPair(2048);
            plain = unicode2native('credential 中文','UTF-8');
            first = kssolv.util.Crypto.rsaEncrypt(public,plain);
            second = kssolv.util.Crypto.rsaEncrypt(public,plain);
            testCase.verifyNotEqual(first,second);
            testCase.verifyEqual(kssolv.util.Crypto.rsaDecrypt(private,first),plain);
            testCase.verifyError(@()kssolv.util.Crypto.rsaDecrypt(uint8([1 2 3]),first), ...
                'KSSOLV:Crypto:InvalidKey');
        end

        function encryptedStoreRetainsLegacyFormat(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            original = userpath;
            cleanup = onCleanup(@()userpath(original)); %#ok<NASGU>
            userpath(fixture.Folder);
            folder = fullfile(fixture.Folder,'KSSOLV_Toolbox','credentials'); mkdir(folder);
            legacy = legacyFixture();
            writeBytes(fullfile(folder,'keypair.json'),uint8(jsonencode(struct( ...
                'Version',1,'Algorithm','RSA-3072', ...
                'PrivateKey',legacy.PrivateKey,'PublicKey',legacy.PublicKey))));
            writeBytes(fullfile(folder,'openai-api-key.json'),uint8(jsonencode(struct( ...
                'Version',1,'Algorithm','RSA-3072-OAEP-SHA256+AES-256-GCM', ...
                'WrappedKey',legacy.WrappedKey,'Nonce',legacy.Nonce, ...
                'Ciphertext',legacy.AesCiphertext))));
            testCase.verifyEqual(kssolv.settings.EncryptedStore.readOpenAIAPIKey(),string(legacy.Plaintext));
            kssolv.settings.EncryptedStore.writeOpenAIAPIKey('replacement fixture');
            testCase.verifyEqual(kssolv.settings.EncryptedStore.readOpenAIAPIKey(),"replacement fixture");
            kssolv.settings.EncryptedStore.writeMaterialsProjectAPIKey('materials fixture');
            testCase.verifyEqual(kssolv.settings.EncryptedStore.readMaterialsProjectAPIKey(),"materials fixture");
            testCase.verifyFalse(contains(fileread(fullfile(folder,'openai-api-key.json')),'replacement fixture'));
            kssolv.settings.EncryptedStore.removeOpenAIAPIKey();
            testCase.verifyEqual(kssolv.settings.EncryptedStore.readOpenAIAPIKey(),"");
        end

        function environmentAndPaths(testCase)
            name = 'KSSOLV_NATIVE_ENV_TEST'; original = getenv(name);
            cleanup = onCleanup(@()setenv(name,original)); %#ok<NASGU>
            setenv(name,'spaces=and=equals');
            values = kssolv.util.Platform.environment();
            testCase.verifyEqual(values(name),'spaces=and=equals');
            testCase.verifyNotEmpty(kssolv.util.Platform.home());
            testCase.verifyNotEmpty(kssolv.util.Platform.hostname());
            testCase.verifyEqual(kssolv.util.Platform.canonicalPath(fullfile(pwd,'a','..','b')), ...
                string(fullfile(pwd,'b')));
            if ispc
                testCase.verifyEqual(kssolv.util.Platform.canonicalPath('\\server\share\a\..\b'), ...
                    "\\server\share\b");
            end
        end

        function portableFloatFormatting(testCase)
            values = [0 -0.0 1 0.0001 0.00001 1e15 1e16 1/3 realmin realmax];
            for value = values
                actual = kssolv.util.Numbers.pythonFloat(value);
                testCase.verifyEqual(str2double(actual),value);
            end
            testCase.verifyEqual(kssolv.util.Numbers.pythonFloat(-0.0),"-0.0");
            testCase.verifyEqual(kssolv.util.Numbers.pythonFloat(1e16),"1e+16");
            testCase.verifyEqual(kssolv.util.Numbers.pythonFloat(1e-5),"1e-05");
        end
    end
end

function bytes = hexBytes(text)
bytes = uint8(sscanf(text,'%2x').');
end

function value = legacyFixture()
value = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), ...
    'fixtures','legacy-credentials.json')));
end

function writeBytes(file,bytes)
handle = fopen(file,'wb'); cleanup = onCleanup(@()fclose(handle)); %#ok<NASGU>
fwrite(handle,bytes,'uint8');
end
