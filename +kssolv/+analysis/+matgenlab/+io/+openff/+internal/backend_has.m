function value = backend_has(backend, operation)
%BACKEND_HAS Whether an explicit OpenFF adapter exposes an operation.
if isstruct(backend)
    value = isfield(backend, operation) && ...
        isa(backend.(operation), "function_handle");
else
    value = isobject(backend) && ismethod(backend, operation);
end
end
