classdef ProjectTemplateLibrary
    %PROJECTTEMPLATELIBRARY Versioned modeling project setup templates.
    methods (Static)
        function path=save(name,template,options)
            arguments
                name {mustBeTextScalar}
                template (1,1) struct
                options.directory string= ...
                    kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                    defaultDirectory()
            end
            name=strip(string(name));
            if name=="", error("KSSOLV:Modeling:ProjectTemplateName", ...
                    "Project template name is empty."); end
            value=template; value.schemaVersion=1; value.name=name;
            if ~isfield(value,"recipeName"), value.recipeName=""; end
            if ~isfield(value,"inputFormat"), value.inputFormat="auto"; end
            if ~isfield(value,"outputFormat"), value.outputFormat="same"; end
            if ~isfield(value,"projectMetadata"), ...
                    value.projectMetadata=struct(); end
            kssolv.modeling.provenance.ProjectTemplateLibrary.validate(value);
            safe=matlab.lang.makeValidName(name);
            path=fullfile(options.directory,safe+".json");
            kssolv.modeling.internal.AtomicJsonFile.write(path,value, ...
                "KSSOLV:Modeling:ProjectTemplateWrite");
        end

        function value=load(name,options)
            arguments
                name {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                    defaultDirectory()
            end
            path=fullfile(options.directory, ...
                matlab.lang.makeValidName(string(name))+".json");
            if ~isfile(path), error("KSSOLV:Modeling:ProjectTemplateMissing", ...
                    "Project template '%s' does not exist.",name); end
            value=jsondecode(fileread(path));
            kssolv.modeling.provenance.ProjectTemplateLibrary.validate(value);
        end

        function names=list(options)
            arguments
                options.directory string= ...
                    kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                    defaultDirectory()
            end
            if ~isfolder(options.directory), names=strings(1,0); return, end
            files=dir(fullfile(options.directory,"*.json"));
            names=erase(string({files.name}),".json");
        end

        function validate(value)
            required=["schemaVersion","name","recipeName", ...
                "inputFormat","outputFormat","projectMetadata"];
            if ~all(isfield(value,required)) || value.schemaVersion~=1 || ...
                    ~isstruct(value.projectMetadata)
                error("KSSOLV:Modeling:ProjectTemplateSchema", ...
                    "Project template requires schemaVersion 1 and complete I/O metadata.");
            end
        end

        function value=defaultDirectory()
            value=fullfile(prefdir,"KSSOLV","modeling-project-templates");
        end
    end
end
