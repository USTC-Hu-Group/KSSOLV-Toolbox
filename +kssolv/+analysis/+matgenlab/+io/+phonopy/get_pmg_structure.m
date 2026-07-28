function structure=get_pmg_structure(phonopyStructure)
%GET_PMG_STRUCTURE Convert PhonopyAtoms-compatible data to Structure.
if isa(phonopyStructure, ...
        "kssolv.analysis.matgenlab.io.phonopy.PhonopyAtoms")
    lattice=phonopyStructure.cell;
    coords=phonopyStructure.scaled_positions;
    symbols=cellstr(phonopyStructure.symbols);
    masses=phonopyStructure.masses;
    magmoms=phonopyStructure.magnetic_moments;
elseif isstruct(phonopyStructure)
    lattice=phonopyStructure.cell;
    coords=phonopyStructure.scaled_positions;
    symbols=cellstr(string(phonopyStructure.symbols));
    masses=phonopyStructure.masses;
    if isfield(phonopyStructure,"magnetic_moments")
        magmoms=phonopyStructure.magnetic_moments;
    else
        magmoms=[];
    end
else
    error("KSSOLV:Matgenlab:Phonopy:Atoms", ...
        "Expected a PhonopyAtoms-compatible object.");
end
if isempty(magmoms),magmoms=zeros(1,numel(symbols));end
properties=struct("phonopy_masses",masses,"magmom",magmoms);
structure=kssolv.analysis.matgenlab.core.Structure( ...
    lattice,symbols,coords,site_properties=properties);
end
