classdef Compression
    %COMPRESSION Raw bzip2 streams without external runtimes or binaries.
    methods (Static)
        function files = bzip2(filename, folder)
            arguments
                filename (1,1) string
                folder (1,1) string
            end
            file = fopen(filename,'rb');
            if file < 0, error('KSSOLV:Compression:Read','Unable to open input.'); end
            cleanup = onCleanup(@()fclose(file));
            bytes = fread(file,Inf,'*uint8'); clear cleanup
            compressed = kssolv.util.Bzip2.compress(bytes);
            if ~isfolder(folder), mkdir(folder); end
            [~,name,extension] = fileparts(filename);
            output = fullfile(folder,name+extension+".bz2");
            file = fopen(output,'wb');
            if file < 0, error('KSSOLV:Compression:Write','Unable to open compressed output.'); end
            cleanup = onCleanup(@()fclose(file));
            if fwrite(file,compressed,'uint8') ~= numel(compressed)
                error('KSSOLV:Compression:Write','Incomplete compressed file write.');
            end
            files = {char(output)};
        end

        function writeBzip2(filename, text)
            bytes = unicode2native(char(text),'UTF-8');
            compressed = kssolv.util.Bzip2.compress(bytes);
            file = fopen(filename,'wb');
            if file < 0, error('KSSOLV:Compression:Write','Unable to open compressed output.'); end
            fileCleanup = onCleanup(@()fclose(file));
            if fwrite(file,compressed,'uint8') ~= numel(compressed)
                error('KSSOLV:Compression:Write','Incomplete compressed file write.');
            end
        end

        function text = readBzip2(filename)
            file = fopen(filename,'rb');
            if file < 0, error('KSSOLV:Compression:Read','Unable to open compressed input.'); end
            cleanup = onCleanup(@()fclose(file));
            bytes = fread(file,Inf,'*uint8');
            plain = kssolv.util.Bzip2.decompress(bytes);
            text = string(native2unicode(plain,'UTF-8'));
        end

        function files = bunzip2(filename, folder)
            arguments
                filename (1,1) string
                folder (1,1) string
            end
            file = fopen(filename,'rb');
            if file < 0, error('KSSOLV:Compression:Read','Unable to open compressed input.'); end
            cleanup = onCleanup(@()fclose(file));
            bytes = fread(file,Inf,'*uint8'); clear cleanup
            plain = kssolv.util.Bzip2.decompress(bytes);
            if ~isfolder(folder), mkdir(folder); end
            [~,name,extension] = fileparts(filename);
            if strcmpi(extension,'.bz2'), output = fullfile(folder,name);
            else, output = fullfile(folder,name+extension+".out"); end
            file = fopen(output,'wb');
            if file < 0, error('KSSOLV:Compression:Write','Unable to open decompressed output.'); end
            cleanup = onCleanup(@()fclose(file));
            if fwrite(file,plain,'uint8') ~= numel(plain)
                error('KSSOLV:Compression:Write','Incomplete decompressed file write.');
            end
            files = {char(output)};
        end
    end
end
