classdef FileBatchModeler
    %FILEBATCHMODELER Import, model, validate, and atomically export files.
    methods (Static)
        function report=run(inputPaths,requests,outputDirectory,options)
            arguments
                inputPaths
                requests
                outputDirectory {mustBeTextScalar}
                options.outputFormat {mustBeTextScalar} = "same"
                options.cancelFcn = @()false
                options.progressFcn = @(~,~)[]
                options.validateFcn = @defaultValidate
                options.startIndex (1,1) double ...
                    {mustBeInteger,mustBePositive} = 1
                options.entryFcn = @(~,~)[]
            end
            paths=reshape(string(inputPaths),1,[]);
            ensureModelingDependencies();
            if isstruct(requests), requests=num2cell(requests); end
            if ~iscell(requests), error("KSSOLV:Modeling:FileBatchRequests", ...
                    "requests must be a struct or cell array of structs."); end
            if numel(requests)==1, requests=repmat(requests,1,numel(paths)); end
            if numel(paths)~=numel(requests)
                error("KSSOLV:Modeling:FileBatchLength", ...
                    "One request or one request per input file is required.");
            end
            if ~isfolder(outputDirectory), [ok,message]=mkdir(outputDirectory); ...
                    if ~ok, error("KSSOLV:Modeling:FileBatchOutput", ...
                    "%s",message); end, end
            empty=struct("inputPath","","outputPath","", ...
                "success",false,"cancelled",false,"parentHash","", ...
                "resultHash","","errorIdentifier","","errorMessage","");
            entries=repmat(empty,1,numel(paths));
            cancelled=false; completed=options.startIndex-1;
            for index=options.startIndex:numel(paths)
                entries(index).inputPath=paths(index);
                if options.cancelFcn()
                    cancelled=true;
                    for remainder=index:numel(paths)
                        entries(remainder).inputPath=paths(remainder);
                        entries(remainder).cancelled=true;
                    end
                    break
                end
                temporary="";
                try
                    parser=kssolv.services.fileparser.StructureIO(paths(index));
                    model=parser.MatgenlabObject;
                    response=kssolv.api.v1.modeling.execute( ...
                        model,requests{index});
                    options.validateFcn(response.model);
                    [~,stem,extension]=fileparts(paths(index));
                    format=lower(string(options.outputFormat));
                    if format=="same", format=erase(string(extension),"."); end
                    if format=="", error("KSSOLV:Modeling:FileBatchFormat", ...
                            "Cannot infer output format for '%s'.",paths(index)); end
                    outputPath=fullfile(outputDirectory,string(stem)+ ...
                        "-modeled."+format);
                    temporary=outputPath+"."+ ...
                        string(matlab.lang.internal.uuid)+".tmp";
                    response.model.to(temporary,format);
                    [ok,message]=movefile(temporary,outputPath,"f");
                    if ~ok, error("KSSOLV:Modeling:FileBatchExport", ...
                            "%s",message); end
                    entries(index).outputPath=outputPath;
                    entries(index).success=true;
                    entries(index).parentHash=response.parentHash;
                    entries(index).resultHash=response.resultHash;
                catch exception
                    if temporary~="" && isfile(temporary), delete(temporary); end
                    entries(index).errorIdentifier=string(exception.identifier);
                    entries(index).errorMessage=string(exception.message);
                end
                completed=index; options.entryFcn(index,entries(index));
                options.progressFcn(index,numel(paths));
            end
            report=struct("schemaVersion",1,"entries",entries, ...
                "requested",numel(paths),"completed",completed, ...
                "succeeded",sum([entries.success]),"failed", ...
                sum(~[entries.success]&~[entries.cancelled]), ...
                "cancelled",cancelled,"outputDirectory", ...
                string(outputDirectory));
        end
    end
end

function ensureModelingDependencies()
dependency=fullfile(KSSOLV_Toolbox.RootDirectory, ...
    "+kssolv","+core","kssolv-3o");
entries=string(split(path,pathsep));
if ~any(entries==string(dependency)), addpath(dependency); end
if exist("Atom","class")~=8
    evalc("KSSOLV.startup()");
end
end

function defaultValidate(model)
if model.num_sites<1 || any(~isfinite(model.cart_coords),"all")
    error("KSSOLV:Modeling:FileBatchValidation", ...
        "Result is empty or contains non-finite coordinates.");
end
if isa(model,"kssolv.analysis.matgenlab.core.IStructure") && ...
        (~isfinite(model.lattice.volume) || model.lattice.volume<=0)
    error("KSSOLV:Modeling:FileBatchValidation", ...
        "Result has an invalid lattice volume.");
end
end
