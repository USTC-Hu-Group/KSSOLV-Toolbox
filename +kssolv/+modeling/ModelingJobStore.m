classdef ModelingJobStore
    %MODELINGJOBSTORE Persistent, resumable file-batch job journal.
    methods (Static)
        function id=createFileBatch(inputPaths,requests,outputDirectory,options)
            arguments
                inputPaths
                requests
                outputDirectory {mustBeTextScalar}
                options.outputFormat {mustBeTextScalar} = "same"
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
            end
            paths=reshape(string(inputPaths),1,[]);
            if isempty(paths)
                error("KSSOLV:Modeling:EmptyJob", ...
                    "A file-batch job requires at least one input file.");
            end
            if isstruct(requests), requests=num2cell(requests); end
            if isscalar(requests), requests=repmat(requests,1,numel(paths)); end
            if numel(paths)~=numel(requests)
                error("KSSOLV:Modeling:JobLength", ...
                    "One request or one request per input file is required.");
            end
            id=string(matlab.lang.internal.uuid);
            entries=repmat(struct("inputPath","","outputPath","", ...
                "success",false,"cancelled",false,"parentHash","", ...
                "resultHash","","errorIdentifier","","errorMessage",""), ...
                1,numel(paths));
            value=struct("schemaVersion",1,"id",id,"kind","file_batch", ...
                "status","queued","inputPaths",paths, ...
                "requests",{requests},"outputDirectory", ...
                string(outputDirectory),"outputFormat", ...
                string(options.outputFormat),"completed",0, ...
                "requested",numel(paths),"entries",entries, ...
                "createdAt",nowText(),"updatedAt",nowText(), ...
                "errorIdentifier","","errorMessage","");
            writeJob(value,options.directory);
        end

        function report=run(id,options)
            arguments
                id {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
                options.progressFcn = @(~,~)[]
            end
            value=readJob(id,options.directory);
            if any(string(value.status)==["complete","cancelled"])
                error("KSSOLV:Modeling:JobTerminal", ...
                    "Job '%s' is already %s.",id,value.status);
            end
            if string(value.status)=="cancel_requested"
                value.status="cancelled"; value.updatedAt=nowText();
                writeJob(value,options.directory);
                report=kssolv.modeling.ModelingJobStore.get(id, ...
                    directory=options.directory);
                return
            end
            value.status="running"; value.updatedAt=nowText();
            writeJob(value,options.directory);
            try
                partial=kssolv.modeling.FileBatchModeler.run( ...
                    string(value.inputPaths),value.requests, ...
                    value.outputDirectory,outputFormat=value.outputFormat, ...
                    startIndex=value.completed+1, ...
                    cancelFcn=@cancelRequested, ...
                    progressFcn=options.progressFcn,entryFcn=@checkpoint);
                latest=readJob(id,options.directory);
                for index=max(1,value.completed+1):numel(partial.entries)
                    if partial.entries(index).inputPath~=""
                        latest.entries(index)=partial.entries(index);
                    end
                end
                latest.completed=max(latest.completed,partial.completed);
                if partial.cancelled, latest.status="cancelled";
                else, latest.status="complete"; end
                latest.updatedAt=nowText(); writeJob(latest,options.directory);
            catch exception
                latest=readJob(id,options.directory);
                latest.status="interrupted";
                latest.errorIdentifier=string(exception.identifier);
                latest.errorMessage=string(exception.message);
                latest.updatedAt=nowText(); writeJob(latest,options.directory);
                rethrow(exception)
            end
            report=kssolv.modeling.ModelingJobStore.get(id, ...
                directory=options.directory);

            function checkpoint(index,entry)
                current=readJob(id,options.directory);
                current.entries(index)=entry; current.completed=index;
                current.updatedAt=nowText(); writeJob(current,options.directory);
            end
            function value=cancelRequested()
                current=readJob(id,options.directory);
                value=string(current.status)=="cancel_requested";
            end
        end

        function requestCancel(id,options)
            arguments
                id {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
            end
            value=readJob(id,options.directory);
            if any(string(value.status)==["complete","cancelled"]), return, end
            value.status="cancel_requested"; value.updatedAt=nowText();
            writeJob(value,options.directory);
        end

        function value=get(id,options)
            arguments
                id {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
            end
            value=readJob(id,options.directory);
            value.succeeded=sum([value.entries.success]);
            value.failed=sum(~[value.entries.success] & ...
                ~[value.entries.cancelled] & ...
                string({value.entries.inputPath})~="");
            value.recoverable=any(string(value.status)== ...
                ["queued","running","interrupted"]);
        end

        function values=list(options)
            arguments
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
            end
            values=repmat(struct("id","","status","", ...
                "completed",0,"requested",0,"succeeded",0,"failed",0, ...
                "recoverable",false,"updatedAt","","error",""),0,1);
            if ~isfolder(options.directory), return, end
            files=dir(fullfile(options.directory,"*.json"));
            for index=1:numel(files)
                try
                    item=kssolv.modeling.ModelingJobStore.get( ...
                        erase(files(index).name,".json"), ...
                        directory=options.directory);
                    values(end+1)=struct("id",string(item.id), ...
                        "status",string(item.status), ...
                        "completed",item.completed, ...
                        "requested",item.requested, ...
                        "succeeded",item.succeeded,"failed",item.failed, ...
                        "recoverable",item.recoverable, ...
                        "updatedAt",string(item.updatedAt), ...
                        "error",""); %#ok<AGROW>
                catch exception
                    values(end+1)=struct("id",string(erase( ...
                        files(index).name,".json")),"status","invalid", ...
                        "completed",0,"requested",0,"succeeded",0, ...
                        "failed",0,"recoverable",false,"updatedAt","", ...
                        "error",string(exception.message)); %#ok<AGROW>
                end
            end
        end

        function value=defaultDirectory()
            value=fullfile(prefdir,"KSSOLV","modeling-jobs");
        end
    end
end

function value=readJob(id,directory)
path=fullfile(directory,string(id)+".json");
if ~isfile(path)
    error("KSSOLV:Modeling:JobMissing", ...
        "Modeling job '%s' does not exist.",id);
end
value=jsondecode(fileread(path));
if value.schemaVersion~=1 || string(value.kind)~="file_batch"
    error("KSSOLV:Modeling:JobSchema", ...
        "Modeling job '%s' uses an unsupported schema.",id);
end
if iscell(value.entries), value.entries=[value.entries{:}]; end
if isstruct(value.requests), value.requests=num2cell(value.requests); end
end

function writeJob(value,directory)
path=fullfile(directory,string(value.id)+".json");
kssolv.modeling.internal.AtomicJsonFile.write(path,value, ...
    "KSSOLV:Modeling:JobWrite");
end

function value=nowText()
value=string(datetime("now","TimeZone","UTC", ...
    "Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end
