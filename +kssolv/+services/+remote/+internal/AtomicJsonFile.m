classdef AtomicJsonFile
    %ATOMICJSONFILE Small atomic JSON persistence helper.

    methods (Static)
        function value = read(path, fallback)
            arguments
                path (1, 1) string
                fallback = struct()
            end
            value = fallback;
            if ~isfile(path)
                return
            end
            try
                value = jsondecode(fileread(path));
            catch exception
                warning("KSSOLV:Remote:InvalidJsonFile", ...
                    "Ignoring invalid remote state file %s: %s", ...
                    path, exception.message);
                value = fallback;
            end
        end

        function write(path, value)
            arguments
                path (1, 1) string
                value
            end
            folder = string(fileparts(path));
            if ~isfolder(folder)
                [created, detail] = mkdir(folder);
                if ~created
                    error("KSSOLV:Remote:StorageCreateFailed", ...
                        "Unable to create remote state folder %s: %s", ...
                        folder, detail);
                end
            end
            kssolv.services.remote.internal.AtomicJsonFile. ...
                restrictPermissions(folder, "rwx------");
            temporary = string(tempname(folder)) + ".json";
            cleanup = onCleanup(@()deleteIfPresent(temporary));
            fileId = fopen(temporary, "w", "n", "UTF-8");
            if fileId < 0
                error("KSSOLV:Remote:StorageWriteFailed", ...
                    "Unable to open temporary remote state file %s.", ...
                    temporary);
            end
            fileCleanup = onCleanup(@()fclose(fileId));
            bytesWritten = fwrite(fileId, ...
                unicode2native(jsonencode(value, PrettyPrint=true), ...
                "UTF-8"), "uint8");
            if bytesWritten == 0
                error("KSSOLV:Remote:StorageWriteFailed", ...
                    "Unable to write remote state file %s.", temporary);
            end
            clear fileCleanup
            kssolv.services.remote.internal.AtomicJsonFile. ...
                restrictPermissions(temporary, "rw-------");
            [moved, detail] = movefile(temporary, path, "f");
            if ~moved
                error("KSSOLV:Remote:StorageMoveFailed", ...
                    "Unable to replace remote state file %s: %s", ...
                    path, detail);
            end
            clear cleanup
        end

        function restrictPermissions(path, mode)
            if isunix
                file = javaObject("java.io.File", char(path));
                file.setReadable(false, false);
                file.setWritable(false, false);
                file.setExecutable(false, false);
                file.setReadable(contains(mode, "r"), true);
                file.setWritable(contains(mode, "w"), true);
                file.setExecutable(contains(mode, "x"), true);
            end
        end
    end
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end
