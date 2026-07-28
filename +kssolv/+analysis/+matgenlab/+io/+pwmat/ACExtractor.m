classdef ACExtractor < ...
        kssolv.analysis.matgenlab.io.pwmat.ACExtractorBase
    %ACEXTRACTOR Extract AtomConfig fields from a file.

    properties (SetAccess = private)
        atom_config_path (1,1) string
        n_atoms (1,1) double
        lattice (1,9) double
        types (1,:) double
        coords (1,:) double
        magmoms (1,:) double
    end

    properties (Access = private)
        delegate
    end

    methods
        function obj = ACExtractor(filename)
            obj.atom_config_path = string(filename);
            obj.delegate = ...
                kssolv.analysis.matgenlab.io.pwmat.ACstrExtractor( ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename));
            obj.n_atoms = obj.get_n_atoms();
            obj.lattice = obj.get_lattice();
            obj.types = obj.get_types();
            obj.coords = obj.get_coords();
            obj.magmoms = obj.get_magmoms();
        end

        function value = get_n_atoms(obj)
            value = obj.delegate.get_n_atoms();
        end

        function value = get_lattice(obj)
            value = obj.delegate.get_lattice();
        end

        function value = get_types(obj)
            value = obj.delegate.get_types();
        end

        function value = get_coords(obj)
            value = obj.delegate.get_coords();
        end

        function value = get_magmoms(obj)
            try
                value = obj.delegate.get_magmoms();
            catch
                % Frozen ACExtractor treats any malformed/missing magnetic
                % section as absent, unlike ACstrExtractor.
                value = zeros(1, obj.delegate.get_n_atoms());
            end
        end
    end
end
