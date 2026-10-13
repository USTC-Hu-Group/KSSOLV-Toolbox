classdef Bzip2Test < matlab.unittest.TestCase
    methods (Test)
        function readsStandardStreams(testCase)
            vectors = referenceVectors();
            expected = {zeros(1,0,'uint8'),unicode2native(sprintf('hello world\n中文 Ω'),'UTF-8'), ...
                uint8(0:255),repmat(uint8(0:255),1,800),repmat(uint8('A'),1,200000)};
            for i = 1:numel(vectors)
                actual = kssolv.util.Bzip2.decompress(matlab.net.base64decode(vectors(i).Compressed));
                testCase.verifyEqual(actual,expected{i},vectors(i).Name);
            end
        end

        function roundTripsBinaryBlocks(testCase)
            previous = rng; cleanup = onCleanup(@()rng(previous)); %#ok<NASGU>
            rng(73);
            values = {zeros(1,0,'uint8'),uint8('a'),repmat(uint8('aaaa'),1,200), ...
                uint8(repelem(0:255,4)),uint8(randi([0 255],1,170000))};
            for i = 1:numel(values)
                actual = kssolv.util.Bzip2.compress(values{i});
                testCase.verifyEqual(kssolv.util.Bzip2.decompress(actual),values{i});
            end
        end

        function readsConcatenatedStreams(testCase)
            vectors = referenceVectors();
            streams = [matlab.net.base64decode(vectors(1).Compressed) ...
                matlab.net.base64decode(vectors(3).Compressed) ...
                matlab.net.base64decode(vectors(3).Compressed)];
            testCase.verifyEqual(kssolv.util.Bzip2.decompress(streams),repmat(uint8(0:255),1,2));
        end

        function rejectsCorruptionAndTruncation(testCase)
            original = kssolv.util.Bzip2.compress(uint8('integrity test'));
            corrupt = original; corrupt(12) = bitxor(corrupt(12),uint8(1)); % Block CRC.
            testCase.verifyError(@()kssolv.util.Bzip2.decompress(corrupt),'KSSOLV:Compression:Data');
            corrupt = original; corrupt(end-1) = bitxor(corrupt(end-1),uint8(1)); % Stream CRC.
            testCase.verifyError(@()kssolv.util.Bzip2.decompress(corrupt),'KSSOLV:Compression:Data');
            testCase.verifyError(@()kssolv.util.Bzip2.decompress(original(1:end-4)), ...
                'KSSOLV:Compression:Data');
            testCase.verifyError(@()kssolv.util.Bzip2.decompress(uint8('not bzip2')), ...
                'KSSOLV:Compression:Data');
        end

        function textAndFileExtraction(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            file = fullfile(fixture.Folder,'text.json.bz2');
            text = string(sprintf('{"text":"中文 Ω"}\r\n'));
            kssolv.util.Compression.writeBzip2(file,text);
            testCase.verifyEqual(kssolv.util.Compression.readBzip2(file),text);
            files = kssolv.util.Compression.bunzip2(file,fullfile(fixture.Folder,'extracted'));
            testCase.verifyEqual(string(files{1}),string(fullfile(fixture.Folder,'extracted','text.json')));
            handle = fopen(files{1},'rb'); cleanup = onCleanup(@()fclose(handle)); %#ok<NASGU>
            testCase.verifyEqual(fread(handle,Inf,'*uint8').',unicode2native(char(text),'UTF-8'));
        end

        function binaryFilesPreserveAllBytes(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            source = fullfile(fixture.Folder,'binary.dat');
            expected = uint8(0:255);
            handle = fopen(source,'wb'); fwrite(handle,expected); fclose(handle);
            archives = kssolv.util.Compression.bzip2(source,fixture.Folder);
            files = kssolv.util.Compression.bunzip2(archives{1},fullfile(fixture.Folder,'out'));
            handle = fopen(files{1},'rb'); cleanup = onCleanup(@()fclose(handle)); %#ok<NASGU>
            testCase.verifyEqual(fread(handle,Inf,'*uint8').',expected);
        end
    end
end

function vectors = referenceVectors()
% Generated independently with Python's standard bz2 codec.
vectors = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), ...
    'fixtures','reference-bzip2.json')));
end
