function value = get_reconstructed_band_structure(structures, efermi)
%GET_RECONSTRUCTED_BAND_STRUCTURE Concatenate split band-structure runs.
if nargin < 2 || isempty(efermi)
    efermi = mean(cellfun(@(item) item.efermi, structures));
end
first = structures{1};
bandCounts = cellfun(@(item) item.nb_bands, structures);
commonBands = min(bandCounts);
points = zeros(0, 3);
bands = struct();
projections = struct();
labels = containers.Map("KeyType", "char", "ValueType", "any");
for structureIndex = 1:numel(structures)
    current = structures{structureIndex};
    points = [points; cell2mat(cellfun(@(point) ...
        point.frac_coords, current.kpoints, UniformOutput=false).')]; %#ok<AGROW>
    names = fieldnames(current.bands);
    for spinIndex = 1:numel(names)
        name = names{spinIndex};
        if ~isfield(bands, name), bands.(name) = zeros(commonBands, 0); end
        bands.(name) = [bands.(name), ...
            current.bands.(name)(1:commonBands, :)];
    end
    projectionNames = fieldnames(current.projections);
    for spinIndex = 1:numel(projectionNames)
        name = projectionNames{spinIndex};
        currentProjection = current.projections.(name);
        currentProjection = currentProjection(1:commonBands, :, :, :);
        if ~isfield(projections, name)
            projections.(name) = currentProjection;
        else
            projections.(name) = cat(2, projections.(name), ...
                currentProjection);
        end
    end
    keys = current.labels_dict.keys;
    for keyIndex = 1:numel(keys)
        labels(keys{keyIndex}) = ...
            current.labels_dict(keys{keyIndex}).frac_coords;
    end
end
if isa(first, ...
        "kssolv.analysis.matgenlab.electronic_structure.BandStructureSymmLine")
    value = kssolv.analysis.matgenlab.electronic_structure. ...
        BandStructureSymmLine(points, bands, first.lattice_rec, ...
        efermi, labels, false, first.structure, projections);
else
    value = kssolv.analysis.matgenlab.electronic_structure. ...
        BandStructure(points, bands, first.lattice_rec, ...
        efermi, labels, false, first.structure, projections);
end
end
