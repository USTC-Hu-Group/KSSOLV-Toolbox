classdef EtsfReader < kssolv.analysis.matgenlab.io.abinit.NetcdfReader
    properties(Dependent)
        chemical_symbols
    end
    methods
        function obj=EtsfReader(path),obj@kssolv.analysis.matgenlab.io.abinit.NetcdfReader(path);end
        function value=get.chemical_symbols(obj)
            raw=obj.read_value("chemical_symbols");
            if ischar(raw),value=strtrim(string(raw.'));
            else,value=strtrim(join(string(char(raw)).',""));end
            value=reshape(value,1,[]);
        end
        function value=type_idx_from_symbol(obj,symbol)
            idx=find(obj.chemical_symbols==string(symbol),1);
            if isempty(idx),error("KSSOLV:Matgenlab:Abinit:Symbol","Unknown symbol %s.",symbol);end
            value=idx-1;
        end
        function value=read_structure(obj,varargin)
            value=kssolv.analysis.matgenlab.io.abinit.structure_from_ncdata(obj,varargin{:});
        end
        function value=read_abinit_xcfunc(obj)
            value=kssolv.analysis.matgenlab.core.XcFunc.from_abinit_ixc(obj.read_value("ixc"));
        end
        function value=read_abinit_hdr(obj)
            mapping=struct("mband","max_number_of_states","natom","number_of_atoms","nkpt","number_of_kpoints","nspden","number_of_components","nspinor","number_of_spinor_components","nsppol","number_of_spins","nsym","number_of_symmetry_operations","ntypat","number_of_atom_species","ecut","kinetic_energy_cutoff","fermie","fermi_energy","nband","number_of_states","typat","atom_species","kptns","reduced_coordinates_of_kpoints","occ","occupations","tnons","reduced_symmetry_translations","wtk","kpoint_weights","znucltypat","atomic_numbers");
            d=struct();names=fieldnames(mapping);
            for i=1:numel(names)
                target=mapping.(names{i});
                try,d.(names{i})=obj.read_value(target);catch %#ok<NOCOMMA>
                    try,d.(names{i})=obj.read_dimvalue(target);catch,end %#ok<NOCOMMA>
                end
            end
            value=kssolv.analysis.matgenlab.io.abinit.AbinitHeader(d);
        end
    end
end
