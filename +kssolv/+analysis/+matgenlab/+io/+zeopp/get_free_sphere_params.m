function parameters = get_free_sphere_params( ...
        structure, radDict, probeRadius, backend)
%GET_FREE_SPHERE_PARAMS Run explicitly injected Zeo++ sphere analysis.
%
% The backend may return the three-field parameter struct directly or the
% first line of a Zeo++ .res file.

if nargin < 2, radDict = []; end
if nargin < 3 || isempty(probeRadius), probeRadius = 0.1; end
if nargin < 4, backend = []; end
if ~isnumeric(probeRadius) || ~isscalar(probeRadius) || ...
        ~isfinite(probeRadius) || probeRadius < 0
    error("KSSOLV:Matgenlab:ZeoPP:ProbeRadius", ...
        "probe_rad must be a finite nonnegative scalar.");
end
if isempty(backend)
    error("KSSOLV:Matgenlab:ZeoPP:BackendRequired", ...
        "get_free_sphere_params requires an explicitly injected " + ...
        "Zeo++-compatible MATLAB backend.");
end
operation = "get_free_sphere_params";
if isstruct(backend)
    available = isfield(backend, operation) && ...
        isa(backend.(operation), "function_handle");
else
    available = isobject(backend) && ismethod(backend, operation);
end
if ~available
    error("KSSOLV:Matgenlab:ZeoPP:BackendContract", ...
        "The injected backend does not implement '%s'.", operation);
end
cssr = kssolv.analysis.matgenlab.io.zeopp.ZeoCssr(structure);
result = backend.(operation)(char(cssr), radDict, double(probeRadius));
names = ["inc_sph_max_dia", "free_sph_max_dia", ...
    "inc_sph_along_free_sph_path_max_dia"];
if isstruct(result) && all(isfield(result, names))
    parameters = struct();
    for index = 1:numel(names)
        value = result.(names(index));
        if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
            error("KSSOLV:Matgenlab:ZeoPP:BackendResult", ...
                "Free-sphere parameter '%s' must be finite.", names(index));
        end
        parameters.(names(index)) = double(value);
    end
    return
end
if ~(ischar(result) || (isstring(result) && isscalar(result)))
    error("KSSOLV:Matgenlab:ZeoPP:BackendResult", ...
        "The free-sphere backend must return a parameter struct or text.");
end
fields = split(strtrim(string(result)));
if numel(fields) < 4
    parameters = [];
    return
end
values = str2double(fields(2:4));
if any(~isfinite(values))
    parameters = [];
    return
end
parameters = struct( ...
    "inc_sph_max_dia", values(1), ...
    "free_sph_max_dia", values(2), ...
    "inc_sph_along_free_sph_path_max_dia", values(3));
end
