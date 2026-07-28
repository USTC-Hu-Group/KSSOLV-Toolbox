function structure=structure_from_ncdata(ncdata,varargin)
[reader,closeIt]=kssolv.analysis.matgenlab.io.abinit.as_ncreader(ncdata);
lattice=double(reader.read_value("primitive_vectors")).'*0.529177210903;
coords=double(reader.read_value("reduced_atom_positions")).';
z=double(reader.read_value("atomic_numbers"));types=double(reader.read_value("atom_species"));
species=arrayfun(@(i)z(types(i)),1:numel(types),"UniformOutput",false);
props=struct();
try
    intg=double(reader.read_value("intgden"));
    if size(intg,1)==2,props.magmom=reshape(intg(2,:)-intg(1,:),[],1);
    elseif size(intg,1)==4,props.magmom=intg(2:4,:).';end
catch
end
structure=kssolv.analysis.matgenlab.core.Structure(lattice,species,coords,site_properties=props);
if closeIt,reader.close();end
end
