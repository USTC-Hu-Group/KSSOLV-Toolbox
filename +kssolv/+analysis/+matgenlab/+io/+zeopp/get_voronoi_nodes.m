function [nodes, edgeCenters, faceCenters] = get_voronoi_nodes( ...
        structure, radDict, probeRadius, backend)
%GET_VORONOI_NODES Run an explicitly injected Zeo++ Voronoi backend.
%
% The backend operation get_voronoi_nodes receives CSSR text, the radius
% dictionary, and probe radius. It returns a struct containing
% voronoi_xyz, edge_centers, and face_centers in Zeo++ coordinates.

if nargin < 2, radDict = []; end
if nargin < 3 || isempty(probeRadius), probeRadius = 0.1; end
if nargin < 4, backend = []; end
validateProbeRadius(probeRadius);
cssr = kssolv.analysis.matgenlab.io.zeopp.ZeoCssr(structure);
result = callBackend(backend, "get_voronoi_nodes", ...
    char(cssr), radDict, double(probeRadius));
required = ["voronoi_xyz", "edge_centers", "face_centers"];
if ~isstruct(result) || ~all(isfield(result, required))
    error("KSSOLV:Matgenlab:ZeoPP:BackendResult", ...
        "get_voronoi_nodes must return voronoi_xyz, " + ...
        "edge_centers, and face_centers.");
end
nodes = nodeStructure(structure.lattice, result.voronoi_xyz);
edgeCenters = centerStructure(structure.lattice, result.edge_centers);
faceCenters = centerStructure(structure.lattice, result.face_centers);
end

function structure = nodeStructure(lattice, payload)
if isa(payload, "kssolv.analysis.matgenlab.io.zeopp.ZeoVoronoiXYZ")
    molecule = payload.molecule;
elseif isa(payload, "kssolv.analysis.matgenlab.core.Molecule") || ...
        isa(payload, "kssolv.analysis.matgenlab.core.IMolecule")
    molecule = payload;
elseif ischar(payload) || (isstring(payload) && isscalar(payload))
    xyz = kssolv.analysis.matgenlab.io.zeopp. ...
        ZeoVoronoiXYZ.from_str(payload);
    molecule = xyz.molecule;
else
    error("KSSOLV:Matgenlab:ZeoPP:VoronoiPayload", ...
        "voronoi_xyz must be text, ZeoVoronoiXYZ, or Molecule.");
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
structure = kssolv.analysis.matgenlab.core.Structure( ...
    lattice, repmat("X", molecule.num_sites, 1), ...
    molecule.cart_coords, coords_are_cartesian = true, ...
    to_unit_cell = true, ...
    site_properties = struct("voronoi_radius", radii));
end

function structure = centerStructure(lattice, rawCenters)
rawCenters = double(rawCenters);
if isempty(rawCenters)
    rawCenters = zeros(0, 3);
end
if size(rawCenters, 2) ~= 3
    error("KSSOLV:Matgenlab:ZeoPP:CenterShape", ...
        "Voronoi centers must be an N-by-3 numeric array.");
end
rotated = rawCenters(:, [2, 3, 1]);
structure = kssolv.analysis.matgenlab.core.Structure( ...
    lattice, repmat("X", size(rotated, 1), 1), rotated, ...
    coords_are_cartesian = true, to_unit_cell = true, ...
    site_properties = struct( ...
        "voronoi_radius", zeros(size(rotated, 1), 1)));
end

function result = callBackend(backend, operation, varargin)
if isempty(backend)
    error("KSSOLV:Matgenlab:ZeoPP:BackendRequired", ...
        "%s requires an explicitly injected Zeo++-compatible " + ...
        "MATLAB backend.", operation);
end
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
result = backend.(operation)(varargin{:});
end

function validateProbeRadius(value)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value < 0
    error("KSSOLV:Matgenlab:ZeoPP:ProbeRadius", ...
        "probe_rad must be a finite nonnegative scalar.");
end
end
