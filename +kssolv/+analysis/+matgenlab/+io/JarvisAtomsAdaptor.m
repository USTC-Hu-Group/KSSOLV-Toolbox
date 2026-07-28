classdef JarvisAtomsAdaptor
    %JARVISATOMSADAPTOR Convert Structure objects to JARVIS-compatible data.
    methods (Static)
        function atoms=get_atoms(structure)
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Jarvis:Disordered", ...
                    "JARVIS Atoms only supports ordered structures.");
            end
            elements=cell(1,structure.num_sites);
            for index=1:structure.num_sites
                elements{index}=char(structure(index).specie.symbol);
            end
            atoms=struct("lattice_mat",structure.lattice.matrix, ...
                "elements",{elements},"coords",structure.frac_coords, ...
                "frac_coords",structure.frac_coords,"cartesian",false);
        end
        function structure=get_structure(atoms)
            required=["lattice_mat","elements"];
            for name=required
                if ~isfield(atoms,name)
                    error("KSSOLV:Matgenlab:Jarvis:Atoms", ...
                        "JARVIS Atoms data is missing '%s'.",name);
                end
            end
            if isfield(atoms,"frac_coords")
                coordinates=atoms.frac_coords;
            elseif isfield(atoms,"coords")&& ...
                    (~isfield(atoms,"cartesian")||~atoms.cartesian)
                coordinates=atoms.coords;
            elseif isfield(atoms,"coords")
                lattice=kssolv.analysis.matgenlab.core. ...
                    Lattice(atoms.lattice_mat);
                coordinates=lattice.get_fractional_coords(atoms.coords);
            else
                error("KSSOLV:Matgenlab:Jarvis:Atoms", ...
                    "JARVIS Atoms data has no coordinates.");
            end
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                atoms.lattice_mat,atoms.elements,coordinates);
        end
    end
end
