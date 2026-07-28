function structure=get_structure_from_dict(data)
%GET_STRUCTURE_FROM_DICT Extract structure data from phonopy YAML mappings.
import kssolv.analysis.matgenlab.io.phonopy.phonopy_field
import kssolv.analysis.matgenlab.io.phonopy.phonopy_records
if isfield(data,"points")
    records=phonopy_records(data.points);
    coordinateName="coordinates";
elseif isfield(data,"atoms")
    records=phonopy_records(data.atoms);
    coordinateName="position";
else
    error("KSSOLV:Matgenlab:Phonopy:Structure", ...
        "The dict does not contain structural information");
end
species=cell(1,numel(records));
coords=zeros(numel(records),3);
masses=zeros(1,numel(records));
for index=1:numel(records)
    record=records{index};
    species{index}=char(string(phonopy_field(record,"symbol")));
    coords(index,:)=reshape(double( ...
        phonopy_field(record,coordinateName)),1,3);
    masses(index)=double(phonopy_field(record,"mass"));
end
lattice=double(phonopy_field(data,"lattice"));
structure=kssolv.analysis.matgenlab.core.Structure( ...
    lattice,species,coords, ...
    site_properties=struct("phonopy_masses",masses));
end
