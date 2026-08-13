classdef AtomicJsonFile
    %ATOMICJSONFILE Crash-safe JSON replacement shared by modeling stores.

    methods (Static)
        function write(path,value,errorId)
            arguments
                path {mustBeTextScalar}
                value
                errorId {mustBeTextScalar} = ...
                    "KSSOLV:Modeling:AtomicJsonWrite"
            end
            path=string(path);
            folder=string(fileparts(path));
            if folder=="", folder="."; end
            if ~isfolder(folder)
                [created,message]=mkdir(folder);
                if ~created && ~isfolder(folder)
                    error(char(errorId), ...
                        "Cannot create JSON folder '%s': %s",folder,message);
                end
            end
            temporary=path+"."+string(matlab.lang.internal.uuid)+".tmp";
            temporaryCleanup=onCleanup(@()deleteTemporary(temporary));
            file=fopen(temporary,"w","n","UTF-8");
            if file<0
                error(char(errorId),"Cannot open temporary JSON '%s'.", ...
                    temporary);
            end
            fileCleanup=onCleanup(@()fclose(file));
            payload=char(jsonencode(value,PrettyPrint=true));
            written=fwrite(file,payload,"char");
            clear fileCleanup
            if written~=numel(payload)
                error(char(errorId),"JSON '%s' was not written completely.", ...
                    path);
            end
            [moved,message]=movefile(temporary,path,"f");
            if ~moved
                error(char(errorId),"Cannot replace JSON '%s': %s", ...
                    path,message);
            end
            clear temporaryCleanup
        end
    end
end

function deleteTemporary(path)
if isfile(path), delete(path); end
end
