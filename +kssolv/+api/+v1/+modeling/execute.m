function response=execute(model,request)
%EXECUTE Execute a stable schema-v1 headless modeling request.
arguments
    model
    request (1,1) struct
end
if ~isfield(request,"schemaVersion") || request.schemaVersion~=1
    error("KSSOLV:API:ModelingSchema", ...
        "Unsupported modeling request schema; expected schemaVersion 1.");
end
if ~isfield(request,"commandId") || strlength(string(request.commandId))==0
    error("KSSOLV:API:ModelingCommand", ...
        "A nonempty commandId is required.");
end
parameters=struct();
if isfield(request,"parameters"), parameters=request.parameters; end
parentHash=kssolv.modeling.provenance.CanonicalHash.of(model);
result=kssolv.modeling.CommandExecutor.execute( ...
    model,string(request.commandId),parameters);
response=struct("schemaVersion",1,"commandId",string(request.commandId), ...
    "changed",logical(result.changed),"message",string(result.message), ...
    "parentHash",parentHash,"resultHash", ...
    kssolv.modeling.provenance.CanonicalHash.of(result.model), ...
    "model",result.model);
if isfield(result,"data"), response.data=result.data; end
if isfield(result,"analysis"), response.analysis=result.analysis; end
end
