classdef ParameterPresetLibrary
    %PARAMETERPRESETLIBRARY Versioned command-parameter presets.
    methods (Static)
        function path=save(commandId,name,parameters,options)
            arguments
                commandId {mustBeTextScalar}
                name {mustBeTextScalar}
                parameters (1,1) struct
                options.directory string= ...
                    kssolv.modeling.provenance.ParameterPresetLibrary. ...
                    defaultDirectory()
            end
            kssolv.modeling.CommandCatalog.find(string(commandId));
            name=strip(string(name));
            if name=="", error("KSSOLV:Modeling:PresetName", ...
                    "Preset name is empty."); end
            safe=matlab.lang.makeValidName(name);
            directory=ensureDirectory(options.directory);
            value=struct("schemaVersion",1,"name",name, ...
                "commandId",string(commandId),"parameters",parameters, ...
                "savedAt",string(datetime("now","TimeZone","UTC", ...
                "Format","yyyy-MM-dd'T'HH:mm:ss'Z'")));
            path=fullfile(directory, ...
                matlab.lang.makeValidName(string(commandId))+"--"+safe+".json");
            kssolv.modeling.internal.AtomicJsonFile.write(path,value, ...
                "KSSOLV:Modeling:PresetWrite");
        end

        function value=load(commandId,name,options)
            arguments
                commandId {mustBeTextScalar}
                name {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.provenance.ParameterPresetLibrary. ...
                    defaultDirectory()
            end
            path=fullfile(options.directory, ...
                matlab.lang.makeValidName(string(commandId))+"--"+ ...
                matlab.lang.makeValidName(string(name))+".json");
            if ~isfile(path), error("KSSOLV:Modeling:PresetMissing", ...
                    "Preset '%s' for '%s' does not exist.",name,commandId); end
            value=jsondecode(fileread(path)); validate(value,string(commandId));
        end

        function entries=list(commandId,options)
            arguments
                commandId {mustBeTextScalar} = ""
                options.directory string= ...
                    kssolv.modeling.provenance.ParameterPresetLibrary. ...
                    defaultDirectory()
            end
            entries=repmat(struct("name","","commandId","", ...
                "path","","savedAt","","error",""),0,1);
            if ~isfolder(options.directory), return, end
            files=dir(fullfile(options.directory,"*.json"));
            for index=1:numel(files)
                try
                    value=jsondecode(fileread(fullfile( ...
                        files(index).folder,files(index).name)));
                    validate(value,"");
                    if string(commandId)~="" && ...
                            string(value.commandId)~=string(commandId), continue, end
                    entries(end+1)=struct("name",string(value.name), ...
                        "commandId",string(value.commandId), ...
                        "path",string(fullfile(files(index).folder, ...
                        files(index).name)),"savedAt",string(value.savedAt), ...
                        "error",""); %#ok<AGROW>
                catch exception
                    if string(commandId)==""
                        entries(end+1)=struct("name",string(erase( ...
                            files(index).name,".json")),"commandId","", ...
                            "path",string(fullfile(files(index).folder, ...
                            files(index).name)),"savedAt","", ...
                            "error",string(exception.message)); %#ok<AGROW>
                    end
                end
            end
        end

        function value=defaultDirectory()
            value=fullfile(prefdir,"KSSOLV","modeling-presets");
        end
    end
end

function validate(value,commandId)
if ~isfield(value,"schemaVersion") || value.schemaVersion~=1 || ...
        ~isfield(value,"commandId") || ~isfield(value,"parameters") || ...
        ~isstruct(value.parameters)
    error("KSSOLV:Modeling:PresetSchema", ...
        "Parameter preset requires schemaVersion 1, commandId, and parameters.");
end
if commandId~="" && string(value.commandId)~=commandId
    error("KSSOLV:Modeling:PresetCommand", ...
        "Preset belongs to command '%s', not '%s'.",value.commandId,commandId);
end
kssolv.modeling.CommandCatalog.find(string(value.commandId));
end

function value=ensureDirectory(value)
if ~isfolder(value), [ok,message]=mkdir(value); if ~ok
        error("KSSOLV:Modeling:PresetDirectory","%s",message); end, end
end
