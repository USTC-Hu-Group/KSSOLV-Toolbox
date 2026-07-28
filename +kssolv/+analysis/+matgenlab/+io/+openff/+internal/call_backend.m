function varargout = call_backend(backend, operation, varargin)
%CALL_BACKEND Invoke an explicitly supplied MATLAB OpenFF adapter.
if isempty(backend)
    error("KSSOLV:Matgenlab:OpenFF:BackendRequired", ...
        "Operation '%s' requires an explicitly injected OpenFF backend.", ...
        operation);
end
if ~kssolv.analysis.matgenlab.io.openff.internal. ...
        backend_has(backend, operation)
    error("KSSOLV:Matgenlab:OpenFF:BackendContract", ...
        "The injected OpenFF backend does not implement '%s'.", operation);
end
[varargout{1:nargout}] = backend.(operation)(varargin{:});
end
