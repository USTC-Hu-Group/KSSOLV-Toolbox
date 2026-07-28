function register_structure_format(format)
%REGISTER_STRUCTURE_FORMAT Register or replace a structure format handler.
if ~isa(format,"kssolv.analysis.matgenlab.io.StructureFormat")
    error("KSSOLV:Matgenlab:Registry:StructureFormat", ...
        "Expected a StructureFormat descriptor.");
end
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.structures();
registry(char(lower(format.name)))=format; %#ok<NASGU>
end
