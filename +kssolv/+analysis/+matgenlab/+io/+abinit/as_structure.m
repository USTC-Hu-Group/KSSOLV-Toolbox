function structure = as_structure(value)
%AS_STRUCTURE Convert supported ABINIT structure inputs to Structure.
if isa(value, "kssolv.analysis.matgenlab.core.Structure") || ...
        isa(value, "kssolv.analysis.matgenlab.core.IStructure")
    structure = value;
elseif ischar(value) || isstring(value)
    structure = kssolv.analysis.matgenlab.core.Structure.from_file(value);
elseif isstruct(value)
    if isfield(value, "lattice") && isfield(value, "sites")
        structure = kssolv.analysis.matgenlab.core.Structure.from_dict(value);
    else
        structure = kssolv.analysis.matgenlab.io.abinit.structure_from_abivars(value);
    end
else
    error("KSSOLV:Matgenlab:Abinit:StructureConversion", ...
        "Cannot convert type %s to Structure.", class(value));
end
end
