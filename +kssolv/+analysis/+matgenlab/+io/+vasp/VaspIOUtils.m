classdef VaspIOUtils
    %VASPIOUTILS Internal text I/O helpers with transparent compression.

    methods (Static)
        function text = readText(filename)
            filename = char(string(filename));
            lowerName = lower(filename);
            if endsWith(lowerName, ".gz")
                folder = tempname;
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                files = gunzip(filename, folder);
                text = fileread(files{1});
                clear cleanup
            elseif endsWith(lowerName, ".bz2")
                folder = tempname;
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                output = fullfile(folder, "payload");
                command = "/usr/bin/bzip2 -dc -- " + ...
                    kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    shellQuote(filename) + " > " + ...
                    kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    shellQuote(output);
                [status, message] = system(command);
                if status ~= 0
                    error("KSSOLV:Matgenlab:VaspIO:Bzip2Read", ...
                        "Unable to decompress '%s': %s", filename, message);
                end
                text = fileread(output);
                clear cleanup
            else
                text = fileread(filename);
            end
        end

        function writeText(filename, text)
            filename = char(string(filename));
            lowerName = lower(filename);
            if endsWith(lowerName, [".gz", ".bz2"])
                folder = tempname;
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                [~, base, extension] = fileparts(filename);
                if strcmpi(extension, ".gz") || strcmpi(extension, ".bz2")
                    temporary = fullfile(folder, base);
                else
                    temporary = fullfile(folder, "data");
                end
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    writePlain(temporary, text);
                if endsWith(lowerName, ".gz")
                    generated = gzip(temporary, folder);
                    movefile(generated{1}, filename, "f");
                else
                    command = "/usr/bin/bzip2 -c -- " + ...
                        kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                        shellQuote(temporary) + " > " + ...
                        kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                        shellQuote(filename);
                    [status, message] = system(command);
                    if status ~= 0
                        error("KSSOLV:Matgenlab:VaspIO:Bzip2Write", ...
                            "Unable to compress '%s': %s", filename, message);
                    end
                end
                clear cleanup
            else
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    writePlain(filename, text);
            end
        end
    end

    methods (Static, Access = private)
        function writePlain(filename, text)
            [identifier, message] = fopen(filename, "w", "n", "UTF-8");
            if identifier < 0
                error("KSSOLV:Matgenlab:VaspIO:Write", "%s", message);
            end
            cleanup = onCleanup(@() fclose(identifier));
            fwrite(identifier, char(string(text)), "char");
            clear cleanup
        end

        function output = shellQuote(input)
            output = "'" + replace(string(input), "'", "'\''") + "'";
        end
    end
end
