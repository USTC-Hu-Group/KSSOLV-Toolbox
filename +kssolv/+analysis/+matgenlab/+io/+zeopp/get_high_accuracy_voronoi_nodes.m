function nodes = get_high_accuracy_voronoi_nodes( ...
        structure, radDict, probeRadius, backend)
%GET_HIGH_ACCURACY_VORONOI_NODES Run injected high-accuracy Zeo++ analysis.
%
% The backend operation receives CSSR text, radius dictionary, and probe
% radius, and returns ZeoVoronoiXYZ text (or the equivalent object).

if nargin < 3 || isempty(probeRadius), probeRadius = 0.1; end
if nargin < 4, backend = []; end
if ~isnumeric(probeRadius) || ~isscalar(probeRadius) || ...
        ~isfinite(probeRadius) || probeRadius < 0
    error("KSSOLV:Matgenlab:ZeoPP:ProbeRadius", ...
        "probe_rad must be a finite nonnegative scalar.");
end
if isempty(backend)
    error("KSSOLV:Matgenlab:ZeoPP:BackendRequired", ...
        "get_high_accuracy_voronoi_nodes requires an explicitly " + ...
        "injected Zeo++-compatible MATLAB backend.");
end
operation = "get_high_accuracy_voronoi_nodes";
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
payload = backend.(operation)(char(cssr), radDict, double(probeRadius));
if isstruct(payload) && isfield(payload, "voronoi_xyz")
    payload = payload.voronoi_xyz;
end
if isa(payload, "kssolv.analysis.matgenlab.io.zeopp.ZeoVoronoiXYZ")
    molecule = payload.molecule;
elseif isa(payload, "kssolv.analysis.matgenlab.core.IMolecule")
    molecule = payload;
elseif ischar(payload) || (isstring(payload) && isscalar(payload))
    xyz = kssolv.analysis.matgenlab.io.zeopp. ...
        ZeoVoronoiXYZ.from_str(payload);
    molecule = xyz.molecule;
else
    error("KSSOLV:Matgenlab:ZeoPP:VoronoiPayload", ...
        "The high-accuracy backend must return Voronoi XYZ data.");
end
radii = zeros(molecule.num_sites, 1);
for index = 1:molecule.num_sites
    site = molecule.get_site(index);
    if ~isfield(site.site_properties, "voronoi_radius")
        error("KSSOLV:Matgenlab:ZeoPP:VoronoiRadius", ...
            "Each Voronoi node must define voronoi_radius.");
    end
    radii(index) = site.site_properties.voronoi_radius;
end
nodes = kssolv.analysis.matgenlab.core.Structure( ...
    structure.lattice, repmat("X", molecule.num_sites, 1), ...
    molecule.cart_coords, coords_are_cartesian = true, ...
    to_unit_cell = true, ...
    site_properties = struct("voronoi_radius", radii));
end
