classdef JDFTXStructure
    %JDFTXSTRUCTURE Lightweight ordered periodic structure for JDFTx I/O.
    properties
        structure struct = struct("lattice", zeros(3), ...
            "species", strings(0, 1), "coords", zeros(0, 3), ...
            "coords_are_cartesian", false)
        selective_dynamics = []
        sort_structure (1, 1) logical = false
        write_cart_coords (1, 1) logical = false
        velocities = []
        constraint_types = []
        constraint_vectors = []
        hyperplane_group_names = []
    end
    properties (Dependent)
        natoms
    end

    methods
        function obj = JDFTXStructure(structure, varargin)
            if nargin > 0 && ~isempty(structure)
                obj.structure = structure;
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
            if obj.sort_structure && ~isempty(obj.structure.species)
                [obj.structure.species, order] = sort( ...
                    string(obj.structure.species));
                obj.structure.coords = obj.structure.coords(order, :);
            end
        end

        function value = get.natoms(obj)
            value = numel(obj.structure.species);
        end

        function text = string(obj)
            text = obj.get_str();
        end

        function text = char(obj)
            text = char(obj.get_str());
        end

        function text = get_str(obj, options)
            arguments
                obj
                options.in_cart_coords = []
            end
            if isempty(options.in_cart_coords)
                cartesian = obj.write_cart_coords;
            else
                cartesian = logical(options.in_cart_coords);
            end
            bohr_to_ang = 0.529177210544;
            lattice_columns = obj.structure.lattice.' / bohr_to_ang;
            rows = strings(3, 1);
            for idx = 1:3
                rows(idx) = join(compose("%.12f", ...
                    lattice_columns(idx, :)), " ");
            end
            lines = "lattice \" + newline + " " + ...
                join(rows, " \" + newline + " ");
            if cartesian
                coords = obj.structure.coords / bohr_to_ang;
                lines = lines + newline + "coords-type Cartesian";
            else
                if isfield(obj.structure, "coords_are_cartesian") && ...
                        obj.structure.coords_are_cartesian
                    coords = obj.structure.coords / obj.structure.lattice;
                else
                    coords = obj.structure.coords;
                end
                lines = lines + newline + "coords-type Lattice";
            end
            species = string(obj.structure.species);
            for idx = 1:numel(species)
                move = 1;
                if ~isempty(obj.selective_dynamics)
                    move = double(logical(obj.selective_dynamics(idx)));
                end
                line = "ion " + species(idx) + " " + ...
                    join(compose("%.12f", coords(idx, :)), " ");
                if ~isempty(obj.velocities) && numel(obj.velocities) >= idx && ...
                        ~isempty(obj.velocities{idx})
                    line = line + " v " + join(compose("%.12f", ...
                        obj.velocities{idx} / bohr_to_ang), " ");
                end
                line = line + " " + string(move);
                lines = lines + newline + line;
            end
            text = lines;
        end

        function write_file(obj, filename, varargin)
            text = obj.get_str(varargin{:});
            handle = fopen(string(filename), "w");
            if handle < 0
                error("KSSOLV:Matgenlab:JDFTX:WriteFailed", ...
                    "Unable to open '%s'.", string(filename));
            end
            cleanup = onCleanup(@() fclose(handle));
            fprintf(handle, "%s\n", text);
        end

        function result = as_dict(obj)
            result = struct("x_module", "pymatgen.io.jdftx.inputs", ...
                "x_class", "JDFTXStructure", ...
                "structure", obj.structure, ...
                "selective_dynamics", obj.selective_dynamics, ...
                "velocities", {obj.velocities}, ...
                "constraint_types", {obj.constraint_types}, ...
                "constraint_vectors", {obj.constraint_vectors}, ...
                "hyperplane_group_names", {obj.hyperplane_group_names});
        end
    end

    methods (Static)
        function obj = from_str(data)
            infile = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
                from_str(data);
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure. ...
                from_jdftxinfile(infile);
        end

        function obj = from_file(filename)
            infile = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
                from_file(filename);
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure. ...
                from_jdftxinfile(infile);
        end

        function obj = from_jdftxinfile(infile, options)
            arguments
                infile
                options.sort_structure (1, 1) logical = false
            end
            bohr_to_ang = 0.529177210544;
            lattice_columns = double(infile.get("lattice"));
            scale = infile.get("latt-scale", [1, 1, 1]);
            if isnumeric(scale) && numel(scale) == 3
                lattice_columns = lattice_columns .* scale(:);
            end
            lattice = lattice_columns.' * bohr_to_ang;
            ions = infile.get("ion");
            if ~iscell(ions)
                ions = {ions};
            end
            species = strings(numel(ions), 1);
            coords = zeros(numel(ions), 3);
            selective = ones(numel(ions), 1);
            velocities = cell(numel(ions), 1);
            for idx = 1:numel(ions)
                ion = ions{idx};
                species(idx) = string(ion.species_id);
                coords(idx, :) = [ion.x0, ion.x1, ion.x2];
                selective(idx) = ion.moveScale;
                if isfield(ion, "v")
                    velocities{idx} = [ion.v.vx0, ion.v.vx1, ion.v.vx2] ...
                        * bohr_to_ang;
                end
            end
            cartesian = strcmpi(string(infile.get("coords-type", ...
                "Lattice")), "Cartesian");
            if cartesian
                coords = coords * bohr_to_ang;
            end
            structure = struct("lattice", lattice, "species", species, ...
                "coords", coords, "coords_are_cartesian", cartesian);
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure( ...
                structure, selective_dynamics = selective, ...
                velocities = velocities, ...
                sort_structure = options.sort_structure);
        end

        function obj = from_dict(params)
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure( ...
                params.structure);
            names = ["selective_dynamics", "velocities", ...
                "constraint_types", "constraint_vectors", ...
                "hyperplane_group_names"];
            for idx = 1:numel(names)
                if isfield(params, names(idx))
                    obj.(names(idx)) = params.(names(idx));
                end
            end
        end
    end
end
