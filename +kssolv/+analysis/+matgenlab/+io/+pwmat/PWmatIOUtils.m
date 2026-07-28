classdef PWmatIOUtils
    %PWMATIOUTILS UTF-8 text transport for PWmat input files.

    methods (Static)
        function value = read_text(filename)
            filename = string(filename);
            extension = lower(string(fileExtension(filename)));
            if extension == ".gz"
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                files = gunzip(filename, folder);
                value = string(fileread(files{1}));
                clear cleanup
            elseif extension == ".z"
                value = readCommand("gzip --decompress --stdout ", ...
                    filename);
            elseif extension == ".bz2"
                value = readCommand("bzip2 --decompress --stdout ", ...
                    filename);
            elseif any(extension == [".lzma", ".xz"])
                value = readCommand("xz --decompress --stdout ", ...
                    filename);
            else
                value = string(fileread(filename));
            end

            function value = fileExtension(path)
                [~, ~, value] = fileparts(path);
            end
        end

        function write_text(filename, text)
            filename = string(filename);
            [~, ~, extension] = fileparts(filename);
            extension = lower(string(extension));
            if extension == ".gz"
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                [~, base] = fileparts(filename);
                temporary = fullfile(folder, base);
                writePlain(temporary, text);
                generated = gzip(temporary, folder);
                movefile(generated{1}, filename, "f");
                clear cleanup
            elseif any(extension == [".z", ".bz2"])
                temporary = string(tempname);
                cleanup = onCleanup(@() deleteIfPresent(temporary));
                writePlain(temporary, text);
                program = "gzip";
                if extension == ".bz2", program = "bzip2"; end
                command = program + " --stdout " + ...
                    shellQuote(temporary) + " > " + ...
                    shellQuote(filename);
                runCompression(command, filename);
                clear cleanup
            elseif any(extension == [".lzma", ".xz"])
                temporary = string(tempname);
                cleanup = onCleanup(@() deleteIfPresent(temporary));
                writePlain(temporary, text);
                format = "xz";
                if extension == ".lzma", format = "lzma"; end
                command = "xz --format=" + format + ...
                    " --compress --stdout " + shellQuote(temporary) + ...
                    " > " + shellQuote(filename);
                runCompression(command, filename);
                clear cleanup
            else
                writePlain(filename, text);
            end

            function writePlain(path, content)
                [identifier, message] = fopen(path, "w", "n", "UTF-8");
                if identifier < 0
                    error("KSSOLV:Matgenlab:PWmat:Write", "%s", message);
                end
                fileCleanup = onCleanup(@() fclose(identifier));
                fwrite(identifier, char(string(content)), "char");
                clear fileCleanup
            end

            function deleteIfPresent(path)
                if isfile(path), delete(path); end
            end
        end
    end
end

function value = readCommand(command, filename)
[status, output] = system(command + shellQuote(filename));
if status ~= 0
    error("KSSOLV:Matgenlab:PWmat:Compression", ...
        "Unable to decompress '%s': %s", filename, output);
end
value = string(output);
end

function runCompression(command, filename)
[status, output] = system(command);
if status ~= 0
    error("KSSOLV:Matgenlab:PWmat:Compression", ...
        "Unable to compress '%s': %s", filename, output);
end
end

function value = shellQuote(input)
input = replace(string(input), "'", "'""'""'");
value = "'" + input + "'";
end
