classdef RecipeLibrary
    %RECIPELIBRARY Versioned, filesystem-backed modeling recipe presets.
    methods (Static)
        function path=save(name,recipe,options)
            arguments
                name {mustBeTextScalar}
                recipe (1,1) struct
                options.directory string=kssolv.modeling.provenance.RecipeLibrary.defaultDirectory()
            end
            kssolv.modeling.provenance.RecipeLibrary.validate(recipe);
            name=strip(string(name));
            if name=="", error("KSSOLV:Modeling:RecipeName", ...
                    "Recipe name is empty."); end
            directory=kssolv.modeling.provenance.RecipeLibrary. ...
                ensureDirectory(options.directory);
            safe=matlab.lang.makeValidName(name);
            path=fullfile(directory,safe+".json");
            kssolv.modeling.internal.AtomicJsonFile.write(path,recipe, ...
                "KSSOLV:Modeling:RecipeWrite");
        end
        function recipe=load(name,options)
            arguments
                name {mustBeTextScalar}
                options.directory string=kssolv.modeling.provenance.RecipeLibrary.defaultDirectory()
            end
            path=fullfile(options.directory, ...
                matlab.lang.makeValidName(string(name))+".json");
            if ~isfile(path), error("KSSOLV:Modeling:RecipeMissing", ...
                    "Recipe '%s' does not exist.",name); end
            recipe=jsondecode(fileread(path));
            kssolv.modeling.provenance.RecipeLibrary.validate(recipe);
        end
        function names=list(options)
            arguments
                options.directory string= ...
                    kssolv.modeling.provenance.RecipeLibrary.defaultDirectory()
            end
            if ~isfolder(options.directory), names=strings(1,0); return, end
            files=dir(fullfile(options.directory,"*.json"));
            names=erase(string({files.name}),".json");
        end
        function validate(recipe)
            if ~isfield(recipe,"schemaVersion") || recipe.schemaVersion~=1 || ...
                    ~isfield(recipe,"operations")
                error("KSSOLV:Modeling:RecipeSchema", ...
                    "Recipe requires schemaVersion 1 and operations; migrate older recipes first.");
            end
        end
        function value=defaultDirectory()
            value=fullfile(prefdir,"KSSOLV","modeling-recipes");
        end
    end
    methods (Static,Access=private)
        function value=ensureDirectory(value)
            if ~isfolder(value)
                [ok,message]=mkdir(value);
                if ~ok
                    error("KSSOLV:Modeling:RecipeDirectory","%s",message);
                end
            end
        end
    end
end
