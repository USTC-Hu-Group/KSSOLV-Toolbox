classdef ResIOUtils
    %RESIOUTILS UTF-8 text I/O with transparent gzip support.

    methods (Static)
        function value = read_text(filename)
            filename = string(filename);
            if endsWith(lower(filename), ".gz")
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                files = gunzip(filename, folder);
                value = string(fileread(files{1}));
                clear cleanup
            else
                value = string(fileread(filename));
            end
        end

        function write_text(filename, text)
            filename = string(filename);
            if endsWith(lower(filename), ".gz")
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                [~, base] = fileparts(filename);
                temporary = fullfile(folder, base);
                kssolv.analysis.matgenlab.io.res.ResIOUtils. ...
                    write_plain(temporary, text);
                generated = gzip(temporary, folder);
                movefile(generated{1}, filename, "f");
                clear cleanup
            else
                kssolv.analysis.matgenlab.io.res.ResIOUtils. ...
                    write_plain(filename, text);
            end
        end
    end

    methods (Static, Access = private)
        function write_plain(filename, text)
            [identifier, message] = fopen(filename, "w", "n", "UTF-8");
            if identifier < 0
                error("KSSOLV:Matgenlab:ResIO:Write", "%s", message);
            end
            cleanup = onCleanup(@() fclose(identifier));
            fwrite(identifier, char(string(text)), "char");
            clear cleanup
        end
    end
end
