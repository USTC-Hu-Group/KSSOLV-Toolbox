function structure = get_valid_magmom_struct(structure, inplace, spin_mode)
%GET_VALID_MAGMOM_STRUCT Return a structure with valid magnetic moments.
if nargin < 2, inplace = true; end
if nargin < 3
    if ischar(inplace) || isstring(inplace)
        spin_mode = inplace;
        inplace = true;
    else
        spin_mode = "auto";
    end
end
if ~(isscalar(inplace) && (islogical(inplace) || isnumeric(inplace)))
    error("KSSOLV:Matgenlab:VaspInputSet:Inplace", ...
        "inplace must be a logical scalar.");
end
if ~isa(structure, "kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:VaspInputSet:StructureType", ...
        "structure must be a matgenlab Structure or IStructure.");
end
mode = lower(extractBefore(string(spin_mode), 2));
if ~any(mode == ["a","s","v","n"])
    error("KSSOLV:Matgenlab:VaspInputSet:SpinMode", ...
        "spin_mode must be auto, scalar, vector, or none.");
end
properties = structure.site_properties;
hasMoments = isfield(properties, "magmom");
if hasMoments, moments = properties.magmom;
else, moments = cell(1, structure.num_sites);
end
if mode == "a"
    mode = "n";
    for index = 1:numel(moments)
        moment = moments{index};
        if isempty(moment), continue; end
        if isnumeric(moment) && isscalar(moment)
            if mode == "v"
                error("KSSOLV:Matgenlab:VaspInputSet:MagmomConflict", ...
                    "Scalar and vector magnetic moments cannot be mixed.");
            end
            mode = "s";
            moments{index} = double(moment);
        elseif isnumeric(moment) && numel(moment) == 3
            if mode == "s"
                error("KSSOLV:Matgenlab:VaspInputSet:MagmomConflict", ...
                    "Scalar and vector magnetic moments cannot be mixed.");
            end
            mode = "v";
            moments{index} = reshape(double(moment), 1, 3);
        else
            error("KSSOLV:Matgenlab:VaspInputSet:MagmomValue", ...
                "Unrecognized magnetic moment value.");
        end
    end
end
if mode == "n"
    if hasMoments, properties = rmfield(properties, "magmom"); end
else
    if mode == "s", default = 1.0; else, default = [1.0,1.0,1.0]; end
    for index = 1:numel(moments)
        if isempty(moments{index}), moments{index} = default; end
    end
    properties.magmom = moments;
end
structure = kssolv.analysis.matgenlab.core.Structure( ...
    structure.lattice, structure.species_and_occu, ...
    structure.frac_coords, site_properties = properties, ...
    labels = structure.labels, properties = structure.structure_properties);
end
