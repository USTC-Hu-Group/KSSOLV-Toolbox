function structure=get_random_structure_for_protostructure(label,varargin)
%GET_RANDOM_STRUCTURE_FOR_PROTOSTRUCTURE Optional PyXtal-adapter boundary.
% Production Matgenlab never imports Python.  Callers that need stochastic
% PyXtal generation must supply an explicit backend function handle using
% backend=@adapter.  The adapter receives a request struct containing the
% protostructure_label and the remaining keyword arguments.
label=string(label);
if strlength(label)==0||~contains(label,":")||mod(numel(varargin),2)~=0
    error("KSSOLV:Matgenlab:Prototypes:Arguments", ...
        "A protostructure label and name-value options are required.");
end
backend=[];
keywords=struct();
for index=1:2:numel(varargin)
    name=string(varargin{index});
    if name=="backend"
        backend=varargin{index+1};
    else
        keywords.(matlab.lang.makeValidName(name))=varargin{index+1};
    end
end
if isempty(backend)
    error("KSSOLV:Matgenlab:Prototypes:PyXtalUnavailable", ...
        "pyxtal generation requires an explicit backend adapter.");
end
if ~isa(backend,"function_handle")
    error("KSSOLV:Matgenlab:Prototypes:Backend", ...
        "backend must be a function handle.");
end
request=struct("protostructure_label",label,"kwargs",keywords);
structure=backend(request);
if ~isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Prototypes:BackendResult", ...
        "The PyXtal backend must return a Matgenlab structure.");
end
end
