classdef RecoveryJournal < handle
    %RECOVERYJOURNAL Atomic autosave snapshots for unsaved modeling drafts.
    properties (SetAccess=private)
        DocumentId string
        Directory string
        Path string
    end
    methods
        function this=RecoveryJournal(documentId,options)
            arguments
                documentId {mustBeTextScalar}
                options.directory string= ...
                    kssolv.modeling.provenance.RecoveryJournal.defaultDirectory()
            end
            this.DocumentId=string(documentId); this.Directory=options.directory;
            digest=kssolv.modeling.provenance.CanonicalHash.of( ...
                struct("documentId",this.DocumentId));
            this.Path=fullfile(this.Directory,extractBefore(digest,17)+".mat");
        end
        function checkpoint(this,model,revision,metadata)
            arguments
                this
                model
                revision (1,1) double {mustBeInteger,mustBeNonnegative}
                metadata (1,1) struct=struct()
            end
            if ~isfolder(this.Directory)
                [ok,message]=mkdir(this.Directory);
                if ~ok, error("KSSOLV:Modeling:RecoveryDirectory","%s",message); end
            end
            snapshot=struct("schemaVersion",1,"documentId",this.DocumentId, ...
                "toolboxVersion",KSSOLV_Toolbox.Version,"matlabRelease", ...
                string(version("-release")),"savedAt",string(datetime("now", ...
                TimeZone="UTC",Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")), ...
                "revision",revision,"modelHash", ...
                kssolv.modeling.provenance.CanonicalHash.of(model), ...
                "metadata",metadata,"model",model.copy());
            temporary=this.Path+"."+string(matlab.lang.internal.uuid)+".tmp";
            try
                save(temporary,"snapshot","-mat");
                [ok,message]=movefile(temporary,this.Path,"f");
                if ~ok, error("KSSOLV:Modeling:RecoveryWrite","%s",message); end
            catch exception
                if isfile(temporary), delete(temporary); end
                rethrow(exception)
            end
        end
        function clear(this)
            if isfile(this.Path), delete(this.Path); end
        end
        function value=exists(this), value=isfile(this.Path); end
        function snapshot=recover(this)
            snapshot=kssolv.modeling.provenance.RecoveryJournal.load(this.Path);
            if string(snapshot.documentId)~=this.DocumentId
                error("KSSOLV:Modeling:RecoveryDocument", ...
                    "Recovery snapshot belongs to a different document.");
            end
        end
    end
    methods (Static)
        function entries=scan(options)
            arguments
                options.directory string= ...
                    kssolv.modeling.provenance.RecoveryJournal.defaultDirectory()
            end
            entries=repmat(struct("path","","valid",false,"documentId","", ...
                "revision",0,"savedAt","","modelHash","","error",""),1,0);
            if ~isfolder(options.directory), return, end
            files=dir(fullfile(options.directory,"*.mat"));
            for index=1:numel(files)
                path=fullfile(files(index).folder,files(index).name);
                entry=struct("path",string(path),"valid",false, ...
                    "documentId","","revision",0,"savedAt","", ...
                    "modelHash","","error","");
                try
                    value=kssolv.modeling.provenance.RecoveryJournal.load(path);
                    entry.valid=true; entry.documentId=string(value.documentId);
                    entry.revision=value.revision; entry.savedAt=string(value.savedAt);
                    entry.modelHash=string(value.modelHash);
                catch exception
                    entry.error=string(exception.message);
                end
                entries(end+1)=entry; %#ok<AGROW>
            end
        end
        function snapshot=load(path)
            try
                data=load(path,"snapshot","-mat");
            catch exception
                error("KSSOLV:Modeling:RecoveryCorrupt", ...
                    "Recovery snapshot cannot be read: %s",exception.message);
            end
            if ~isfield(data,"snapshot") || ...
                    ~isstruct(data.snapshot) || ...
                    ~isfield(data.snapshot,"schemaVersion") || ...
                    data.snapshot.schemaVersion~=1 || ...
                    ~isfield(data.snapshot,"model") || ...
                    ~isfield(data.snapshot,"modelHash")
                error("KSSOLV:Modeling:RecoverySchema", ...
                    "Recovery snapshot schema is invalid; keep the file for diagnosis.");
            end
            snapshot=data.snapshot;
            actual=kssolv.modeling.provenance.CanonicalHash.of(snapshot.model);
            if actual~=string(snapshot.modelHash)
                error("KSSOLV:Modeling:RecoveryHash", ...
                    "Recovery snapshot integrity check failed; the model was not restored.");
            end
        end
        function value=defaultDirectory()
            value=fullfile(prefdir,"KSSOLV","modeling-recovery");
        end
    end
end
