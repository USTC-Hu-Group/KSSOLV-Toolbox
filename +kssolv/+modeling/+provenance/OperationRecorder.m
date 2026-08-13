classdef OperationRecorder < handle
    %OPERATIONRECORDER Versioned modeling recipe and deterministic replay.
    properties (SetAccess=private)
        Records (1,:) struct = struct( ...
            "schemaVersion",{},"commandId",{},"parameters",{}, ...
            "seed",{},"parentHash",{},"resultHash",{},"timestamp",{})
    end
    methods
        function [result,record]=execute(this,model,commandId,parameters)
            if nargin<4, parameters=struct(); end
            result=kssolv.modeling.CommandExecutor.execute( ...
                model,commandId,parameters);
            record=this.record(model,commandId,parameters,result.model);
        end
        function record=record(this,parentModel,commandId,parameters,resultModel)
            if nargin<4, parameters=struct(); end
            parentHash=kssolv.modeling.provenance.CanonicalHash.of(parentModel);
            seed=[]; if isfield(parameters,"seed"), seed=parameters.seed; end
            record=struct("schemaVersion",1,"commandId",string(commandId), ...
                "parameters",parameters,"seed",seed,"parentHash",parentHash, ...
                "resultHash",kssolv.modeling.provenance.CanonicalHash.of( ...
                resultModel),"timestamp",string(datetime("now", ...
                TimeZone="UTC",Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")));
            this.Records(end+1)=record;
        end
        function recipe=recipe(this)
            recipe=struct("schemaVersion",1,"product","KSSOLV Toolbox", ...
                "operations",this.Records);
        end
        function text=toJSON(this)
            text=string(jsonencode(this.recipe(),PrettyPrint=true));
        end
        function save(this,path)
            path=string(path);
            kssolv.modeling.internal.AtomicJsonFile.write( ...
                path,this.recipe(),"KSSOLV:Modeling:RecipeWrite");
        end
    end
    methods (Static)
        function [model,report]=replay(initialModel,recipe)
            if ischar(recipe) || isstring(recipe)
                source=string(recipe);
                if isfile(source), source=string(fileread(source)); end
                recipe=jsondecode(source);
            end
            if ~isstruct(recipe) || ~isfield(recipe,"schemaVersion") || ...
                    recipe.schemaVersion~=1
                error("KSSOLV:Modeling:RecipeSchema", ...
                    "Unsupported recipe schema; expected schemaVersion 1.");
            end
            model=initialModel.copy(); operations=recipe.operations;
            if isempty(operations)
                report=struct("operationCount",0,"verified",true); return
            end
            for index=1:numel(operations)
                operation=operations(index);
                actualParent=kssolv.modeling.provenance.CanonicalHash.of(model);
                if string(operation.parentHash)~=actualParent
                    error("KSSOLV:Modeling:RecipeParentHash", ...
                        "Recipe parent hash mismatch at operation %d.",index);
                end
                result=kssolv.modeling.CommandExecutor.execute(model, ...
                    string(operation.commandId),operation.parameters);
                model=result.model;
                actualResult=kssolv.modeling.provenance.CanonicalHash.of(model);
                if string(operation.resultHash)~=actualResult
                    error("KSSOLV:Modeling:RecipeResultHash", ...
                        "Recipe result hash mismatch at operation %d.",index);
                end
            end
            report=struct("operationCount",numel(operations), ...
                "verified",true,"resultHash",actualResult);
        end
    end
end
