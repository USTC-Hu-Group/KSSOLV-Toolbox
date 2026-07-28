classdef LobsterSet < kssolv.analysis.matgenlab.util.MSONable
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERSET VASP input-update model suitable for LOBSTER.
    properties
        structure = []
        isym (1,1) double = 0
        ismear (1,1) double = -5
        reciprocal_density double = []
        address_basis_file = []
        user_supplied_basis (1,1) struct = struct()
        user_potcar_functional (1,1) string = "PBE_54"
        potcar_symbols cell = {}
    end
    properties (Dependent, SetAccess = private)
        kpoints_updates
        incar_updates
    end
    methods
        function obj = LobsterSet(structure, options)
            arguments
                structure = []
                options.isym (1,1) double = 0
                options.ismear (1,1) double = -5
                options.reciprocal_density double = []
                options.address_basis_file = []
                options.user_supplied_basis (1,1) struct = struct()
                options.user_potcar_functional (1,1) string = "PBE_54"
                options.potcar_symbols cell = {}
            end
            if ~any(options.isym == [-1, 0])
                error("KSSOLV:Matgenlab:Lobster:ISYM", "ISYM must be -1 or 0.");
            end
            if ~any(options.ismear == [-5, 0])
                error("KSSOLV:Matgenlab:Lobster:ISMEAR", ...
                    "ISMEAR must be -5 or 0.");
            end
            obj.structure = structure;
            obj.isym = options.isym;
            obj.ismear = options.ismear;
            obj.reciprocal_density = options.reciprocal_density;
            obj.address_basis_file = options.address_basis_file;
            obj.user_supplied_basis = options.user_supplied_basis;
            obj.user_potcar_functional = options.user_potcar_functional;
            obj.potcar_symbols = options.potcar_symbols;
        end
        function value = get.kpoints_updates(obj)
            density = obj.reciprocal_density;
            if isempty(density), density = 310; end
            value = struct("reciprocal_density", density);
        end
        function value = get.incar_updates(obj)
            if ~isempty(fieldnames(obj.user_supplied_basis))
                names = fieldnames(obj.user_supplied_basis);
                basis = cellfun(@(name) char(string(name) + " " + ...
                    string(obj.user_supplied_basis.(name))), names, ...
                    "UniformOutput", false);
            elseif ~isempty(obj.potcar_symbols)
                basis = kssolv.analysis.matgenlab.io.lobster.Lobsterin. ...
                    get_basis(obj.structure, obj.potcar_symbols, ...
                    obj.address_basis_file);
            else
                basis = {};
            end
            bands = 0;
            for entry = basis(:).'
                orbitalsValue = split(string(entry{1}));
                for orbital = orbitalsValue(2:end).'
                    if endsWith(orbital, "s"), bands = bands + 1;
                    elseif contains(orbital, "p"), bands = bands + 3;
                    elseif contains(orbital, "d"), bands = bands + 5;
                    elseif contains(orbital, "f"), bands = bands + 7; end
                end
            end
            value = struct("EDIFF", 1e-6, "NSW", 0, "LWAVE", true, ...
                "ISYM", obj.isym, "NBANDS", bands, "IBRION", -1, ...
                "ISMEAR", obj.ismear, "LORBIT", 11, "ICHARG", 0, ...
                "ALGO", "Normal");
        end
        function value = as_dict(obj)
            value = kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.lobster.sets", "LobsterSet", ...
                struct("structure", obj.structure, "isym", obj.isym, ...
                "ismear", obj.ismear, ...
                "reciprocal_density", obj.reciprocal_density, ...
                "address_basis_file", obj.address_basis_file, ...
                "user_supplied_basis", obj.user_supplied_basis, ...
                "user_potcar_functional", obj.user_potcar_functional));
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
end
