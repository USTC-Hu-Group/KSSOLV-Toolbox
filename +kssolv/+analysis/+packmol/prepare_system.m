function system = prepare_system(config)
%PREPARE_SYSTEM Expand molecule templates into Packmol atom instances.

structures = config.structures;
instanceTemplate = struct( ...
    "structure_index", 0, "copy_index", 0, "variable_index", 0, ...
    "atom_indices", zeros(1, 0), "fixed", false);
instances = repmat(instanceTemplate, 0, 1);
atomCount = 0;
variableCount = 0;
for typeIndex = 1:numel(structures)
    structure = structures(typeIndex);
    natom = size(structure.molecule.coordinates, 1);
    for copyIndex = 1:structure.number
        instance = instanceTemplate;
        instance.structure_index = typeIndex;
        instance.copy_index = copyIndex;
        instance.fixed = structure.fixed;
        if ~structure.fixed
            variableCount = variableCount + 1;
            instance.variable_index = variableCount;
        end
        instance.atom_indices = atomCount + (1:natom);
        atomCount = atomCount + natom;
        instances(end + 1, 1) = instance; %#ok<AGROW>
    end
end

coordinates = zeros(atomCount, 3);
symbols = strings(atomCount, 1);
atomInstance = zeros(atomCount, 1);
atomStructure = zeros(atomCount, 1);
atomLocal = zeros(atomCount, 1);
fixed = false(atomCount, 1);
radius = zeros(atomCount, 1);
fscale = zeros(atomCount, 1);
shortRadius = zeros(atomCount, 1);
shortRadiusScale = zeros(atomCount, 1);
useShortRadius = false(atomCount, 1);
for instanceIndex = 1:numel(instances)
    instance = instances(instanceIndex);
    structure = structures(instance.structure_index);
    indices = instance.atom_indices;
    templateCoordinates = structure.molecule.coordinates;
    if structure.fixed
        pose = structure.fixed_pose;
        rotation = kssolv.analysis.packmol.eulerfixed( ...
            pose(4), pose(5), pose(6));
        coordinates(indices, :) = templateCoordinates * rotation.' + ...
            pose(1:3);
        if config.settings.using_pbc && ...
                any(coordinates(indices, :) < config.settings.pbc_min | ...
                    coordinates(indices, :) > config.settings.pbc_max, ...
                    "all")
            error("KSSOLV:Packmol:FixedOutsidePBC", ...
                "A fixed molecule lies outside the periodic box.");
        end
    end
    symbols(indices) = structure.molecule.symbols;
    atomInstance(indices) = instanceIndex;
    atomStructure(indices) = instance.structure_index;
    atomLocal(indices) = (1:numel(indices)).';
    fixed(indices) = structure.fixed;
    radius(indices) = structure.radius;
    fscale(indices) = structure.fscale;
    shortRadius(indices) = structure.short_radius;
    shortRadiusScale(indices) = structure.short_radius_scale;
    useShortRadius(indices) = structure.use_short_radius;
end

lower = repmat(-1.0e20, 6 * variableCount, 1);
upper = repmat(1.0e20, 6 * variableCount, 1);
for instanceIndex = 1:numel(instances)
    instance = instances(instanceIndex);
    if instance.fixed
        continue
    end
    structure = structures(instance.structure_index);
    rotationOffset = 3 * variableCount + ...
        3 * (instance.variable_index - 1);
    for axis = 1:3
        if structure.rotation_constrained(axis)
            center = structure.rotation_bounds(axis, 1);
            width = abs(structure.rotation_bounds(axis, 2));
            lower(rotationOffset + axis) = center - width;
            upper(rotationOffset + axis) = center + width;
        end
    end
end

system = struct( ...
    "config", config, ...
    "structures", structures, ...
    "instances", instances, ...
    "atom_count", atomCount, ...
    "free_molecule_count", variableCount, ...
    "fixed_coordinates", coordinates, ...
    "symbols", symbols, ...
    "atom_instance", atomInstance, ...
    "atom_structure", atomStructure, ...
    "atom_local", atomLocal, ...
    "fixed", fixed, ...
    "radius", radius, ...
    "radius_initial", radius, ...
    "fscale", fscale, ...
    "short_radius", shortRadius, ...
    "short_radius_scale", shortRadiusScale, ...
    "use_short_radius", useShortRadius, ...
    "lower_bounds", lower, ...
    "upper_bounds", upper);
end
